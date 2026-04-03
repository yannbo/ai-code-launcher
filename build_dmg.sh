#!/bin/zsh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
APP_NAME="AI Code Launcher"
APP_PATH="$SCRIPT_DIR/$APP_NAME.app"
DMG_PATH="$SCRIPT_DIR/$APP_NAME.dmg"
STAGING_DIR="/tmp/ai-code-launcher-dmg"

if [[ ! -d "$APP_PATH" || "$SCRIPT_DIR/LauncherApp.m" -nt "$APP_PATH" || "$SCRIPT_DIR/build_app.sh" -nt "$APP_PATH" ]]; then
  /bin/zsh "$SCRIPT_DIR/build_app.sh"
fi

/bin/rm -rf "$STAGING_DIR"
/bin/mkdir -p "$STAGING_DIR"
/bin/cp -R "$APP_PATH" "$STAGING_DIR/"
/bin/ln -s /Applications "$STAGING_DIR/Applications"
/bin/rm -f "$DMG_PATH"

/usr/bin/hdiutil create \
  -volname "$APP_NAME" \
  -srcfolder "$STAGING_DIR" \
  -format UDZO \
  -ov \
  "$DMG_PATH" >/dev/null

/bin/rm -rf "$STAGING_DIR"

echo "Built: $DMG_PATH"
