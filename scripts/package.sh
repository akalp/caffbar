#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
PROJECT_PATH="$REPO_ROOT/CaffBar.xcodeproj"
PBXPROJ_PATH="$PROJECT_PATH/project.pbxproj"
SCHEME="CaffBar"
DERIVED_DATA="$REPO_ROOT/build/DerivedData"
DIST_DIR="$REPO_ROOT/dist"

command -v xcodebuild >/dev/null 2>&1 || { echo "xcodebuild not found" >&2; exit 1; }
command -v ditto >/dev/null 2>&1 || { echo "ditto not found" >&2; exit 1; }
command -v shasum >/dev/null 2>&1 || { echo "shasum not found" >&2; exit 1; }

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
rm -f "$ZIP_PATH"

ditto -c -k --sequesterRsrc --keepParent "$APP_PATH" "$ZIP_PATH"

SHA_LINE="$(shasum -a 256 "$ZIP_PATH")"
SHA256="${SHA_LINE%% *}"

printf 'Created: %s\n' "$ZIP_PATH"
printf 'sha256: %s\n' "$SHA256"
