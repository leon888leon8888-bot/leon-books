#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

APP_DISPLAY_NAME="${APP_DISPLAY_NAME:-Leon的书}"
ICON_SOURCE="${ICON_SOURCE:-$ROOT_DIR/assets/app_icon/app_icon_1024.png}"
APPICON_DIR="$ROOT_DIR/ios/Runner/Assets.xcassets/AppIcon.appiconset"
INFO_PLIST="$ROOT_DIR/ios/Runner/Info.plist"

log() {
  printf "\n==> %s\n" "$*"
}

die() {
  printf "\nERROR: %s\n" "$*" >&2
  exit 1
}

patch_plist_value() {
  local plist="$1"
  local key="$2"
  local value="$3"

  /usr/libexec/PlistBuddy -c "Set :$key $value" "$plist" >/dev/null 2>&1 ||
    /usr/libexec/PlistBuddy -c "Add :$key string $value" "$plist" >/dev/null
}

if [[ "$(uname -s)" != "Darwin" ]]; then
  die "iOS branding requires macOS because it uses Xcode's generated ios/ runner and sips."
fi

command -v sips >/dev/null 2>&1 || die "sips is required."

if [[ ! -f "$ICON_SOURCE" ]]; then
  die "Icon source not found: $ICON_SOURCE"
fi

if [[ ! -d "$APPICON_DIR" ]]; then
  die "AppIcon directory not found. Run flutter create . --platforms=ios first."
fi

if [[ -f "$INFO_PLIST" ]]; then
  log "Setting app display name to $APP_DISPLAY_NAME"
  patch_plist_value "$INFO_PLIST" "CFBundleDisplayName" "$APP_DISPLAY_NAME"
fi

log "Generating iOS AppIcon.appiconset"
find "$APPICON_DIR" -type f -name "*.png" -delete

make_icon() {
  local filename="$1"
  local pixels="$2"
  sips -s format png -z "$pixels" "$pixels" "$ICON_SOURCE" --out "$APPICON_DIR/$filename" >/dev/null
}

make_icon "Icon-App-20x20@1x.png" 20
make_icon "Icon-App-20x20@2x.png" 40
make_icon "Icon-App-20x20@3x.png" 60
make_icon "Icon-App-29x29@1x.png" 29
make_icon "Icon-App-29x29@2x.png" 58
make_icon "Icon-App-29x29@3x.png" 87
make_icon "Icon-App-40x40@1x.png" 40
make_icon "Icon-App-40x40@2x.png" 80
make_icon "Icon-App-40x40@3x.png" 120
make_icon "Icon-App-60x60@2x.png" 120
make_icon "Icon-App-60x60@3x.png" 180
make_icon "Icon-App-76x76@1x.png" 76
make_icon "Icon-App-76x76@2x.png" 152
make_icon "Icon-App-83.5x83.5@2x.png" 167
make_icon "Icon-App-1024x1024@1x.png" 1024

cat > "$APPICON_DIR/Contents.json" <<'JSON'
{
  "images": [
    {
      "size": "20x20",
      "idiom": "iphone",
      "filename": "Icon-App-20x20@2x.png",
      "scale": "2x"
    },
    {
      "size": "20x20",
      "idiom": "iphone",
      "filename": "Icon-App-20x20@3x.png",
      "scale": "3x"
    },
    {
      "size": "29x29",
      "idiom": "iphone",
      "filename": "Icon-App-29x29@2x.png",
      "scale": "2x"
    },
    {
      "size": "29x29",
      "idiom": "iphone",
      "filename": "Icon-App-29x29@3x.png",
      "scale": "3x"
    },
    {
      "size": "40x40",
      "idiom": "iphone",
      "filename": "Icon-App-40x40@2x.png",
      "scale": "2x"
    },
    {
      "size": "40x40",
      "idiom": "iphone",
      "filename": "Icon-App-40x40@3x.png",
      "scale": "3x"
    },
    {
      "size": "60x60",
      "idiom": "iphone",
      "filename": "Icon-App-60x60@2x.png",
      "scale": "2x"
    },
    {
      "size": "60x60",
      "idiom": "iphone",
      "filename": "Icon-App-60x60@3x.png",
      "scale": "3x"
    },
    {
      "size": "20x20",
      "idiom": "ipad",
      "filename": "Icon-App-20x20@1x.png",
      "scale": "1x"
    },
    {
      "size": "20x20",
      "idiom": "ipad",
      "filename": "Icon-App-20x20@2x.png",
      "scale": "2x"
    },
    {
      "size": "29x29",
      "idiom": "ipad",
      "filename": "Icon-App-29x29@1x.png",
      "scale": "1x"
    },
    {
      "size": "29x29",
      "idiom": "ipad",
      "filename": "Icon-App-29x29@2x.png",
      "scale": "2x"
    },
    {
      "size": "40x40",
      "idiom": "ipad",
      "filename": "Icon-App-40x40@1x.png",
      "scale": "1x"
    },
    {
      "size": "40x40",
      "idiom": "ipad",
      "filename": "Icon-App-40x40@2x.png",
      "scale": "2x"
    },
    {
      "size": "76x76",
      "idiom": "ipad",
      "filename": "Icon-App-76x76@1x.png",
      "scale": "1x"
    },
    {
      "size": "76x76",
      "idiom": "ipad",
      "filename": "Icon-App-76x76@2x.png",
      "scale": "2x"
    },
    {
      "size": "83.5x83.5",
      "idiom": "ipad",
      "filename": "Icon-App-83.5x83.5@2x.png",
      "scale": "2x"
    },
    {
      "size": "1024x1024",
      "idiom": "ios-marketing",
      "filename": "Icon-App-1024x1024@1x.png",
      "scale": "1x"
    }
  ],
  "info": {
    "version": 1,
    "author": "xcode"
  }
}
JSON

log "iOS branding applied"
