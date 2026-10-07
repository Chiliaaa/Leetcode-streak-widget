#!/bin/zsh
set -euo pipefail

PROJECT_DIR="${0:A:h}"
BUILD_DIR="$PROJECT_DIR/build"
APP_DIR="$BUILD_DIR/StreakByte.app"

mkdir -p "$APP_DIR/Contents/MacOS" "$APP_DIR/Contents/Resources"
mkdir -p "$BUILD_DIR/ModuleCache"
swiftc \
  -parse-as-library \
  -O \
  -module-cache-path "$BUILD_DIR/ModuleCache" \
  -framework SwiftUI \
  -framework AppKit \
  -framework UserNotifications \
  "$PROJECT_DIR/Sources/StreakByte/StreakByteApp.swift" \
  -o "$APP_DIR/Contents/MacOS/StreakByte"
cp "$PROJECT_DIR/Info.plist" "$APP_DIR/Contents/Info.plist"
codesign --force --deep --sign - "$APP_DIR"

echo "Built $APP_DIR"
echo "Run it with: open '$APP_DIR'"
