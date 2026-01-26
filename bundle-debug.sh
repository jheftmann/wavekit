#!/bin/bash
# Bundle debug build as a proper .app for location permissions

set -e

APP_NAME="WaveKit-Dev"
BUILD_DIR=".build/debug"
APP_DIR="$BUILD_DIR/$APP_NAME.app"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"

# Build first
swift build

# Create app bundle structure
rm -rf "$APP_DIR"
mkdir -p "$MACOS_DIR"
mkdir -p "$RESOURCES_DIR"

# Copy binary
cp "$BUILD_DIR/WaveKit" "$MACOS_DIR/WaveKit"

# Create Info.plist
cat > "$CONTENTS_DIR/Info.plist" << 'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>WaveKit</string>
    <key>CFBundleIdentifier</key>
    <string>com.wavekit.dev</string>
    <key>CFBundleName</key>
    <string>WaveKit-Dev</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSLocationUsageDescription</key>
    <string>WaveKit uses your location to sort surf spots by distance.</string>
</dict>
</plist>
PLIST

# Sign with entitlements
codesign --force --sign - --entitlements "WaveKit/WaveKit.debug.entitlements" "$APP_DIR"

echo "Created $APP_DIR"
echo "Run with: open $APP_DIR"
