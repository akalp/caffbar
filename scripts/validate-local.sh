#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROJECT_PATH="$REPO_ROOT/CaffBar.xcodeproj"
SCHEME="CaffBar"
DERIVED_DATA="$REPO_ROOT/build/DerivedData-Hooks"
MODE="${1:---full}"

cd "$REPO_ROOT"

case "$MODE" in
  --fast|--full) ;;
  *)
    echo "Usage: $0 [--fast|--full]" >&2
    exit 2
    ;;
esac

echo "[validate] Repo: $REPO_ROOT (mode: ${MODE#--})"

# Fast structural checks first.
plutil -lint CaffBar/Info.plist >/dev/null
plutil -lint CaffBar.xcodeproj/project.pbxproj >/dev/null

if command -v xmllint >/dev/null 2>&1; then
  xmllint --noout \
    CaffBar.xcodeproj/project.xcworkspace/contents.xcworkspacedata \
    CaffBar.xcodeproj/xcshareddata/xcschemes/CaffBar.xcscheme
fi

bash -n scripts/package.sh scripts/validate-local.sh scripts/setup-git-hooks.sh .githooks/pre-commit

if command -v ruby >/dev/null 2>&1; then
  ruby -e 'require "yaml"; YAML.load_file(".github/workflows/release.yml")'
fi

if [[ "$MODE" == "--fast" ]]; then
  echo "[validate] Fast checks OK"
  exit 0
fi

if ! command -v xcodebuild >/dev/null 2>&1; then
  echo "[validate] xcodebuild not found. Install Xcode and set xcode-select to Xcode.app." >&2
  exit 1
fi

# Environment-first checks (lightweight) before invoking xcodebuild.
ACTIVE_DEV_DIR="$(xcode-select -p 2>/dev/null || true)"
if [[ "$ACTIVE_DEV_DIR" == "/Library/Developer/CommandLineTools"* ]]; then
  echo "[validate] Full Xcode is not selected (currently: $ACTIVE_DEV_DIR)." >&2
  echo "[validate] Run: sudo xcode-select -s /Applications/Xcode.app/Contents/Developer" >&2
  exit 1
fi

echo "[validate] xcodebuild version"
xcodebuild -version

echo "[validate] listing schemes"
xcodebuild -list -project "$PROJECT_PATH" >/dev/null

echo "[validate] building Debug (macOS destination)"
xcodebuild \
  -project "$PROJECT_PATH" \
  -scheme "$SCHEME" \
  -configuration Debug \
  -destination 'platform=macOS' \
  -derivedDataPath "$DERIVED_DATA" \
  build >/dev/null

echo "[validate] OK"
