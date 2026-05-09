#!/bin/bash
# Bundle debug build as a proper .app for location permissions

set -e

VERSION=$(cat VERSION)
APP_NAME="WaveKit-Dev"
BUILD_DIR=".build/debug"
APP_DIR="$BUILD_DIR/$APP_NAME.app"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"

# Kill any running debug instances before rebuilding
pkill -f 'WaveKit-Dev' 2>/dev/null || true

# Build first
swift build

# Create app bundle structure
rm -rf "$APP_DIR"
mkdir -p "$MACOS_DIR"
mkdir -p "$RESOURCES_DIR"

# Copy binary
cp "$BUILD_DIR/WaveKit" "$MACOS_DIR/WaveKit"

# Copy resources bundle (icons, images)
cp -r "$BUILD_DIR/WaveKit_WaveKit.bundle" "$RESOURCES_DIR/"
cp "WaveKit/Resources/Images/AppIcon.icns" "$RESOURCES_DIR/AppIcon.icns"

# Create Info.plist
cat > "$CONTENTS_DIR/Info.plist" << PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>WaveKit</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>CFBundleIdentifier</key>
    <string>com.wavekit.dev</string>
    <key>CFBundleName</key>
    <string>WaveKit-Dev</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>$VERSION</string>
    <key>CFBundleVersion</key>
    <string>$VERSION</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSCalendarsUsageDescription</key>
    <string>WaveKit adds surf forecast events to your calendar so you can see wave conditions at a glance.</string>
    <key>NSLocationUsageDescription</key>
    <string>WaveKit uses your location to sort surf spots by distance.</string>
</dict>
</plist>
PLIST

# PkgInfo — required for Finder to recognize the app type and render the icon
printf 'APPL????' > "$CONTENTS_DIR/PkgInfo"

# Sign with entitlements
codesign --force --sign - --entitlements "WaveKit/WaveKit.debug.entitlements" "$APP_DIR"

echo "Created $APP_DIR"
echo "Run with: open $APP_DIR"
