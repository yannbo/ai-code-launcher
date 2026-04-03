#!/bin/zsh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
APP_NAME="AI Code Launcher"
APP_PATH="$SCRIPT_DIR/$APP_NAME.app"
PKG_PATH="$SCRIPT_DIR/$APP_NAME Installer.pkg"
IDENTIFIER="local.byp.ai-code-launcher"
VERSION="2.0"

if [[ ! -d "$APP_PATH" || "$SCRIPT_DIR/LauncherApp.m" -nt "$APP_PATH" || "$SCRIPT_DIR/build_app.sh" -nt "$APP_PATH" ]]; then
  /bin/zsh "$SCRIPT_DIR/build_app.sh"
fi

/bin/rm -f "$PKG_PATH"

/usr/bin/pkgbuild \
  --component "$APP_PATH" \
  --install-location /Applications \
  --identifier "$IDENTIFIER" \
  --version "$VERSION" \
  "$PKG_PATH"

echo "Built: $PKG_PATH"
