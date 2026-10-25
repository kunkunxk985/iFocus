#!/usr/bin/env bash
# Package iFocus macOS app bundle into a user-friendly DMG
set -euo pipefail

ROOT=$(cd "$(dirname "$0")/.." && pwd)
cd "$ROOT"

APP_NAME="iFocus"
APP_DIR="$ROOT/Build/${APP_NAME}.app"
DMG_PATH="$ROOT/Build/${APP_NAME}.dmg"
TEMP_DIR="$ROOT/Build/dmg_temp"
SKIP_BUILD=0

cleanup() {
    rm -rf "$TEMP_DIR"
}
trap cleanup EXIT

if [[ "${1:-}" == "--skip-build" ]]; then
    SKIP_BUILD=1
fi

if (( SKIP_BUILD == 0 )); then
    echo "Building fresh app bundle for DMG..."
    ./Scripts/package_app.sh
elif [[ ! -d "$APP_DIR" ]]; then
    echo "ERROR: --skip-build requested but app bundle not found at $APP_DIR" >&2
    exit 1
else
    echo "Using existing app bundle because --skip-build was requested."
fi

echo "Preparing temporary directory for DMG..."
rm -rf "$TEMP_DIR"
mkdir -p "$TEMP_DIR"

# Copy the .app bundle and strip any extended attributes before packaging
cp -R "$APP_DIR" "$TEMP_DIR/"
xattr -cr "$TEMP_DIR/${APP_NAME}.app" 2>/dev/null || true

# Create a symlink to /Applications inside the DMG folder for easy installation
ln -s /Applications "$TEMP_DIR/Applications"

echo "Creating disk image (DMG)..."
rm -f "$DMG_PATH"
if diskutil image create from \
        --volumeName "${APP_NAME}" \
        --format UDZO \
        "$TEMP_DIR" \
        "$DMG_PATH"; then
    :
else
    # Compatibility fallback for macOS versions before `diskutil image`.
    rm -f "$DMG_PATH"
    hdiutil create -volname "${APP_NAME}" -srcfolder "$TEMP_DIR" -format UDZO "$DMG_PATH"
fi

echo "Success! DMG packaged at: $DMG_PATH"
