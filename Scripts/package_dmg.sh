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
rm -f "$ROOT/Build/"*.zip
mkdir -p "$TEMP_DIR"

# Copy the .app bundle and strip any extended attributes before packaging
cp -R "$APP_DIR" "$TEMP_DIR/"
xattr -cr "$TEMP_DIR/${APP_NAME}.app" 2>/dev/null || true

# Create a symlink to /Applications inside the DMG folder for easy installation
ln -s /Applications "$TEMP_DIR/Applications"

# One-click helper for friends whose macOS Gatekeeper flags ad-hoc signed builds
HELPER_SCRIPT="$TEMP_DIR/首次打开若提示已损坏请双击.command"
cat > "$HELPER_SCRIPT" <<'EOF'
#!/usr/bin/env bash
set -e
APP_PATH="/Applications/iFocus.app"
if [[ ! -d "$APP_PATH" ]]; then
  echo "请先把 iFocus 拖入「Applications（应用程序）」文件夹后再运行此脚本。"
  exit 1
fi
xattr -cr "$APP_PATH"
echo "已解除 macOS 首次打开限制，正在启动 iFocus…"
open -a "$APP_PATH"
EOF
chmod +x "$HELPER_SCRIPT"

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

if [[ -d "/Users/kun/Desktop" && -w "/Users/kun/Desktop" ]]; then
    cp -f "$DMG_PATH" "/Users/kun/Desktop/${APP_NAME}.dmg"
fi

echo "Success! DMG packaged at: $DMG_PATH"
