#!/bin/zsh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
APP_PATH="$SCRIPT_DIR/AI Code Launcher.app"

if [[ ! -d "$APP_PATH" || "$SCRIPT_DIR/LauncherApp.m" -nt "$APP_PATH" || "$SCRIPT_DIR/build_app.sh" -nt "$APP_PATH" ]]; then
  /bin/zsh "$SCRIPT_DIR/build_app.sh"
fi

/usr/bin/open "$APP_PATH"
