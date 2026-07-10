#!/usr/bin/env bash
# Package iFocus macOS SwiftUI + Web app bundle
set -euo pipefail

CONF="release"
ROOT=$(cd "$(dirname "$0")/.." && pwd)
cd "$ROOT"

APP_NAME="iFocus"
BUNDLE_ID="com.kun.ifocus"
MACOS_MIN_VERSION="13.0"

echo "Building SwiftPM executable..."
CLANG_MODULE_CACHE_PATH="${ROOT}/.build/clang-module-cache" \
swift build -c "$CONF" --disable-sandbox --scratch-path .build

APP_DIR="$ROOT/Build/${APP_NAME}.app"
rm -rf "$APP_DIR"
mkdir -p "$APP_DIR/Contents/MacOS" "$APP_DIR/Contents/Resources"

# Generate Info.plist
cat > "$APP_DIR/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key><string>${APP_NAME}</string>
    <key>CFBundleDisplayName</key><string>${APP_NAME}</string>
    <key>CFBundleIdentifier</key><string>${BUNDLE_ID}</string>
    <key>CFBundleExecutable</key><string>${APP_NAME}</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleShortVersionString</key><string>1.6.12</string>
    <key>CFBundleVersion</key><string>72</string>
    <key>LSMinimumSystemVersion</key><string>${MACOS_MIN_VERSION}</string>
    <key>CFBundleIconFile</key><string>AppIcon</string>
    <key>NSHighResolutionCapable</key><true/>
    <key>NSSupportsAutomaticGraphicsSwitching</key><true/>
    <key>LSApplicationCategoryType</key><string>public.app-category.productivity</string>
    <key>NSUserNotificationAlertStyle</key><string>alert</string>
    <key>CFBundleURLTypes</key>
    <array>
        <dict>
            <key>CFBundleURLName</key>
            <string>com.kun.ifocus.deeplink</string>
            <key>CFBundleURLSchemes</key>
            <array>
                <string>ifocus</string>
            </array>
        </dict>
    </array>
</dict>
</plist>
PLIST

echo "Installing binary..."
# Find the compiled binary
BINARY_PATH=".build/release/iFocus"
if [[ ! -f "$BINARY_PATH" ]]; then
    # Fallback to arch-specific path if default target structure is nested
    BINARY_PATH=$(find .build/ -name "iFocus" -type f -perm +111 | head -n 1)
fi

if [[ -z "$BINARY_PATH" || ! -f "$BINARY_PATH" ]]; then
    echo "ERROR: Failed to find iFocus binary" >&2
    exit 1
fi

cp "$BINARY_PATH" "$APP_DIR/Contents/MacOS/$APP_NAME"
chmod +x "$APP_DIR/Contents/MacOS/$APP_NAME"

# Ensure AppIcon.icns is at the root of Contents/Resources in the app bundle
if [[ -f "Sources/iFocus/AppIcon.icns" ]]; then
    cp "Sources/iFocus/AppIcon.icns" "$APP_DIR/Contents/Resources/"
fi

# Ad-hoc code signing for local execution
echo "Ad-hoc signing the app bundle..."
codesign --force --sign "-" "$APP_DIR"

echo "iFocus.app successfully packaged at: $APP_DIR"
