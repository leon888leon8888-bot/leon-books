#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

APP_NAME="${APP_NAME:-LeonBooks}"
APP_API_BASE_URL="${APP_API_BASE_URL:-}"
APP_API_FALLBACK_BASE_URLS="${APP_API_FALLBACK_BASE_URLS:-}"
APP_API_TOKEN="${APP_API_TOKEN:-}"
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

if [[ -n "$APP_API_BASE_URL" || -n "$APP_API_TOKEN" ]]; then
  if [[ -z "$APP_API_BASE_URL" ]]; then
    die "APP_API_BASE_URL is required when bundling app configuration."
  fi
  if [[ -z "$APP_API_TOKEN" ]]; then
    die "APP_API_TOKEN is required. Set the READER_REBUILD_API_TOKEN GitHub secret before building a user IPA."
  fi
  CONFIG_URLS="$APP_API_BASE_URL"
  if [[ -n "$APP_API_FALLBACK_BASE_URLS" ]]; then
    CONFIG_URLS="$APP_API_FALLBACK_BASE_URLS"
  fi
  IFS=',' read -r -a CONFIG_URL_ARRAY <<< "$CONFIG_URLS"
  log "Writing bundled app configuration"
  {
    cat <<EOF
class AppConfig {
  const AppConfig._();

  static const apiBaseUrl = '$APP_API_BASE_URL';
  static const apiBaseUrls = <String>[
EOF
    for url in "${CONFIG_URL_ARRAY[@]}"; do
      trimmed="$(printf '%s' "$url" | xargs)"
      if [[ -n "$trimmed" ]]; then
        printf "    '%s',\n" "$trimmed"
      fi
    done
    cat <<EOF
  ];
  static const apiToken = '$APP_API_TOKEN';
}
EOF
  } > "$ROOT_DIR/lib/app_config.dart"
fi

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
