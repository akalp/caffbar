#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
HOOKS_DIR="$REPO_ROOT/.githooks"

cd "$REPO_ROOT"

git config core.hooksPath .githooks
chmod +x "$HOOKS_DIR"/* 2>/dev/null || true

echo "Configured git hooks path: $(git config --get core.hooksPath)"
echo "Hooks will run from: $HOOKS_DIR"
