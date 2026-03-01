#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
PROJECT_PATH="$REPO_ROOT/CaffBar.xcodeproj"
PBXPROJ_PATH="$PROJECT_PATH/project.pbxproj"
SCHEME="CaffBar"
DERIVED_DATA="$REPO_ROOT/build/DerivedData"
DIST_DIR="$REPO_ROOT/dist"
DMG_STAGING_DIR=""
VOLUME_NAME="Install CaffBar"

command -v xcodebuild >/dev/null 2>&1 || { echo "xcodebuild not found" >&2; exit 1; }
command -v ditto >/dev/null 2>&1 || { echo "ditto not found" >&2; exit 1; }
command -v hdiutil >/dev/null 2>&1 || { echo "hdiutil not found" >&2; exit 1; }
command -v shasum >/dev/null 2>&1 || { echo "shasum not found" >&2; exit 1; }

cleanup() {
  if [[ -n "$DMG_STAGING_DIR" && -d "$DMG_STAGING_DIR" ]]; then
    rm -rf "$DMG_STAGING_DIR"
  fi
}

trap cleanup EXIT

if [[ ! -f "$PBXPROJ_PATH" ]]; then
  echo "Missing project file: $PBXPROJ_PATH" >&2
  exit 1
fi

VERSION="$(grep -m1 'MARKETING_VERSION = ' "$PBXPROJ_PATH" | sed -E 's/.*MARKETING_VERSION = ([^;]+);/\1/' | tr -d '[:space:]')"
if [[ -z "$VERSION" ]]; then
  echo "Unable to read MARKETING_VERSION from $PBXPROJ_PATH" >&2
  exit 1
fi

rm -rf "$DERIVED_DATA"
mkdir -p "$DIST_DIR"

xcodebuild \
  -project "$PROJECT_PATH" \
  -scheme "$SCHEME" \
  -configuration Release \
  -derivedDataPath "$DERIVED_DATA" \
  build

APP_PATH="$DERIVED_DATA/Build/Products/Release/CaffBar.app"
if [[ ! -d "$APP_PATH" ]]; then
  echo "Built app not found at $APP_PATH" >&2
  exit 1
fi

ZIP_PATH="$DIST_DIR/CaffBar-$VERSION.zip"
DMG_PATH="$DIST_DIR/CaffBar-$VERSION.dmg"
rm -f "$ZIP_PATH" "$DMG_PATH"

ditto -c -k --sequesterRsrc --keepParent "$APP_PATH" "$ZIP_PATH"

DMG_STAGING_DIR="$(mktemp -d "$DIST_DIR/dmg-staging.XXXXXX")"
ditto "$APP_PATH" "$DMG_STAGING_DIR/CaffBar.app"
ln -s /Applications "$DMG_STAGING_DIR/Applications"

hdiutil create \
  -volname "$VOLUME_NAME" \
  -srcfolder "$DMG_STAGING_DIR" \
  -fs HFS+ \
  -format UDZO \
  -imagekey zlib-level=9 \
  -ov \
  "$DMG_PATH" >/dev/null

ZIP_SHA_LINE="$(shasum -a 256 "$ZIP_PATH")"
ZIP_SHA256="${ZIP_SHA_LINE%% *}"
DMG_SHA_LINE="$(shasum -a 256 "$DMG_PATH")"
DMG_SHA256="${DMG_SHA_LINE%% *}"

printf 'Created: %s\n' "$ZIP_PATH"
printf 'sha256(zip): %s\n' "$ZIP_SHA256"
printf 'Created: %s\n' "$DMG_PATH"
printf 'sha256(dmg): %s\n' "$DMG_SHA256"
