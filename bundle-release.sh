#!/bin/bash
# Build and package WaveKit release app bundle
# Usage: ./bundle-release.sh
# Output: .build/release/WaveKit.app (signed), docs/WaveKit-<version>.zip, docs/WaveKit.zip

set -e

VERSION=$(cat VERSION)
APP_NAME="WaveKit"
BUILD_DIR=".build/release"
APP_DIR="$BUILD_DIR/$APP_NAME.app"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"

echo "Building WaveKit v$VERSION (release)..."

# Build
swift build -c release

# Assemble app bundle
rm -rf "$APP_DIR"
mkdir -p "$MACOS_DIR"
mkdir -p "$RESOURCES_DIR"

# Copy binary and resources
cp "$BUILD_DIR/WaveKit" "$MACOS_DIR/WaveKit"
cp -r "$BUILD_DIR/WaveKit_WaveKit.bundle" "$RESOURCES_DIR/"
cp "WaveKit/Resources/Images/AppIcon.icns" "$RESOURCES_DIR/AppIcon.icns"

# Write Info.plist with version from VERSION file
cat > "$CONTENTS_DIR/Info.plist" << PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>WaveKit</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon.icns</string>
    <key>CFBundleIdentifier</key>
    <string>com.wavekit.app</string>
    <key>CFBundleName</key>
    <string>WaveKit</string>
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

# Ad-hoc sign (enables Gatekeeper "Open Anyway" flow on Sonoma/Sequoia)
echo "Signing..."
codesign --force --deep --sign - "$APP_DIR"

# Package ZIP
echo "Packaging..."
REPO_ROOT="$(pwd)"
cd "$BUILD_DIR"
zip -r "${REPO_ROOT}/docs/WaveKit-${VERSION}.zip" WaveKit.app
cd "$REPO_ROOT"
cp "docs/WaveKit-${VERSION}.zip" docs/WaveKit.zip

echo ""
echo "Done: $APP_DIR (signed)"
echo "      docs/WaveKit-${VERSION}.zip"
echo "      docs/WaveKit.zip"
