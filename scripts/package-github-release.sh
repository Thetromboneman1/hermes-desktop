#!/bin/bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_PATH="$ROOT_DIR/dist/HermesDesktop.app"
ZIP_PATH="$ROOT_DIR/dist/HermesDesktop.app.zip"

"$ROOT_DIR/scripts/build-macos-app.sh"

rm -f "$ZIP_PATH"
xattr -cr "$APP_PATH" 2>/dev/null || true
ditto -c -k --norsrc --keepParent "$APP_PATH" "$ZIP_PATH"

echo
echo "Release archive created:"
echo "  $ZIP_PATH"
