#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

IOS_ORG="${IOS_ORG:-com.readerrebuild}"
IOS_BUNDLE_ID="${IOS_BUNDLE_ID:-com.readerrebuild.app}"
IOS_ALLOW_HTTP="${IOS_ALLOW_HTTP:-1}"
IOS_DEVICE_ID="${IOS_DEVICE_ID:-}"
APP_DISPLAY_NAME="${APP_DISPLAY_NAME:-Leon的书}"
IOS_SKIP_PREFLIGHT_BUILD="${IOS_SKIP_PREFLIGHT_BUILD:-0}"

log() {
  printf "\n==> %s\n" "$*"
}

die() {
  printf "\nERROR: %s\n" "$*" >&2
  exit 1
}

need_command() {
  command -v "$1" >/dev/null 2>&1 || die "$1 is required but was not found."
}

patch_plist_value() {
  local plist="$1"
  local key="$2"
  local value="$3"

  /usr/libexec/PlistBuddy -c "Set :$key $value" "$plist" >/dev/null 2>&1 ||
    /usr/libexec/PlistBuddy -c "Add :$key string $value" "$plist" >/dev/null
}

if [[ "$(uname -s)" != "Darwin" ]]; then
  die "iOS build and device deployment require macOS. Run this script on a Mac with Xcode installed."
fi

need_command flutter
need_command xcodebuild
need_command pod

if [[ ! -x /usr/libexec/PlistBuddy ]]; then
  die "/usr/libexec/PlistBuddy is required but was not found."
fi

log "Checking Xcode command line tools"
xcode-select -p >/dev/null
xcodebuild -version

log "Checking Flutter toolchain"
flutter doctor -v

if [[ ! -d ios ]]; then
  log "Generating Flutter iOS runner"
  flutter create . --platforms=ios --project-name reader_rebuild_mobile --org "$IOS_ORG"
else
  log "Using existing ios runner"
fi

log "Resolving Flutter packages"
flutter pub get

PBXPROJ="ios/Runner.xcodeproj/project.pbxproj"
if [[ -f "$PBXPROJ" ]]; then
  log "Setting bundle identifier to $IOS_BUNDLE_ID"
  sed -i '' "s/PRODUCT_BUNDLE_IDENTIFIER = [^;]*;/PRODUCT_BUNDLE_IDENTIFIER = $IOS_BUNDLE_ID;/g" "$PBXPROJ"
fi

INFO_PLIST="ios/Runner/Info.plist"
if [[ -f "$INFO_PLIST" ]]; then
  log "Patching app display name"
  patch_plist_value "$INFO_PLIST" "CFBundleDisplayName" "$APP_DISPLAY_NAME"

  if [[ "$IOS_ALLOW_HTTP" == "1" ]]; then
    log "Allowing HTTP traffic for self-hosted backend testing"
    /usr/libexec/PlistBuddy -c "Delete :NSAppTransportSecurity" "$INFO_PLIST" >/dev/null 2>&1 || true
    /usr/libexec/PlistBuddy -c "Add :NSAppTransportSecurity dict" "$INFO_PLIST" >/dev/null
    /usr/libexec/PlistBuddy -c "Add :NSAppTransportSecurity:NSAllowsArbitraryLoads bool true" "$INFO_PLIST" >/dev/null
  fi
fi

if [[ -x "$ROOT_DIR/scripts/apply_ios_branding.sh" ]]; then
  APP_DISPLAY_NAME="$APP_DISPLAY_NAME" "$ROOT_DIR/scripts/apply_ios_branding.sh"
fi

log "Installing CocoaPods dependencies"
(cd ios && pod install)

log "Listing available devices"
flutter devices

if [[ "$IOS_SKIP_PREFLIGHT_BUILD" == "1" ]]; then
  log "Skipping debug preflight build"
else
  log "Building iOS debug app without code signing"
  flutter build ios --debug --no-codesign
fi

if [[ "${1:-}" == "--run" ]]; then
  if [[ -z "$IOS_DEVICE_ID" ]]; then
    die "Set IOS_DEVICE_ID before using --run. Example: IOS_DEVICE_ID=00008110-... scripts/bootstrap_ios.sh --run"
  fi

  log "Running on physical iOS device $IOS_DEVICE_ID"
  flutter run -d "$IOS_DEVICE_ID"
else
  cat <<'EOF'

iOS bootstrap finished.

Next steps for physical device validation:
1. Open ios/Runner.xcworkspace in Xcode.
2. Select Runner > Signing & Capabilities.
3. Enable Automatically manage signing and choose your Team.
4. Connect and trust the iPhone, then enable Developer Mode on the device.
5. Run:
   IOS_DEVICE_ID=<device-id> scripts/bootstrap_ios.sh --run

Use HTTPS in production. The script enables broad HTTP ATS access only so the current self-hosted HTTP backend can be tested on a real iPhone.
EOF
fi
