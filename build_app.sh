#!/bin/zsh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
APP_NAME="AI Code Launcher"
APP_DIR="$SCRIPT_DIR/$APP_NAME.app"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"
EXECUTABLE_NAME="AI Code Launcher"
EXECUTABLE_PATH="$MACOS_DIR/$EXECUTABLE_NAME"
PLIST_PATH="$CONTENTS_DIR/Info.plist"
SOURCE_PATH="$SCRIPT_DIR/LauncherApp.m"
MODULE_CACHE_DIR="/tmp/ai-code-launcher-clang-cache"
ICON_SOURCE_PATH="$SCRIPT_DIR/assets/app-icon.png"
ICON_TIFF_PATH="$SCRIPT_DIR/assets/app-icon.tiff"
ICON_NAME="AppIcon"
ICON_OUTPUT_PATH="$RESOURCES_DIR/$ICON_NAME.icns"

/bin/rm -rf "$APP_DIR"
/bin/rm -rf "$MODULE_CACHE_DIR"
/bin/mkdir -p "$MACOS_DIR" "$RESOURCES_DIR"

/usr/bin/python3 "$SCRIPT_DIR/generate_icon.py"
/usr/bin/tiff2icns "$ICON_TIFF_PATH" "$ICON_OUTPUT_PATH"

CLANG_MODULE_CACHE_PATH="$MODULE_CACHE_DIR" /usr/bin/clang \
  -fobjc-arc \
  -framework AppKit \
  "$SOURCE_PATH" \
  -o "$EXECUTABLE_PATH"

cat > "$PLIST_PATH" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleDevelopmentRegion</key>
  <string>en</string>
  <key>CFBundleExecutable</key>
  <string>$EXECUTABLE_NAME</string>
  <key>CFBundleIdentifier</key>
  <string>local.byp.ai-code-launcher</string>
  <key>CFBundleInfoDictionaryVersion</key>
  <string>6.0</string>
  <key>CFBundleName</key>
  <string>$APP_NAME</string>
  <key>CFBundleIconFile</key>
  <string>$ICON_NAME</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleShortVersionString</key>
  <string>2.0</string>
  <key>CFBundleVersion</key>
  <string>2</string>
  <key>NSHighResolutionCapable</key>
  <true/>
</dict>
</plist>
EOF

echo "Built: $APP_DIR"
