#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

APP_NAME="${APP_NAME:-LeonBooks}"
OUT_DIR="$ROOT_DIR/build/ios/unsigned"
PAYLOAD_DIR="$OUT_DIR/Payload"
DERIVED_DATA_DIR="$ROOT_DIR/build/ios/unsigned-derived-data"
IPA_PATH="$OUT_DIR/${APP_NAME}-unsigned.ipa"

log() {
  printf "\n==> %s\n" "$*"
}

die() {
  printf "\nERROR: %s\n" "$*" >&2
  exit 1
}

if [[ "$(uname -s)" != "Darwin" ]]; then
  die "Unsigned iOS packaging still requires macOS because Flutter must compile with Xcode."
fi

command -v flutter >/dev/null 2>&1 || die "flutter is required."
command -v xcodebuild >/dev/null 2>&1 || die "xcodebuild is required."

if [[ ! -d ios ]]; then
  log "Generating Flutter iOS runner"
  flutter create . --platforms=ios --project-name reader_rebuild_mobile
fi

log "Resolving packages"
flutter pub get

if [[ -d ios ]]; then
  log "Installing CocoaPods dependencies"
  (cd ios && pod install)
fi

log "Building release app bundle without code signing"
rm -rf "$DERIVED_DATA_DIR"
xcodebuild \
  -workspace ios/Runner.xcworkspace \
  -scheme Runner \
  -configuration Release \
  -sdk iphoneos \
  -derivedDataPath "$DERIVED_DATA_DIR" \
  CODE_SIGNING_ALLOWED=NO \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGN_IDENTITY="" \
  DEVELOPMENT_TEAM="" \
  PROVISIONING_PROFILE_SPECIFIER="" \
  build

APP_BUNDLE="$(find "$DERIVED_DATA_DIR/Build/Products/Release-iphoneos" -maxdepth 1 -name "*.app" -type d | head -n 1)"

if [[ -z "$APP_BUNDLE" || ! -d "$APP_BUNDLE" ]]; then
  die "Runner.app was not produced under $DERIVED_DATA_DIR/Build/Products/Release-iphoneos"
fi

log "Packaging unsigned IPA"
rm -rf "$OUT_DIR"
mkdir -p "$PAYLOAD_DIR"
cp -R "$APP_BUNDLE" "$PAYLOAD_DIR/"
(cd "$OUT_DIR" && zip -qry "$IPA_PATH" Payload)

log "Unsigned IPA created"
printf "%s\n" "$IPA_PATH"
