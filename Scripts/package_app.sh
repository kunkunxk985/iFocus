#!/usr/bin/env bash
# Package iFocus macOS SwiftUI app bundle and synchronize installed copies.
set -euo pipefail

CONF="release"
ROOT=$(cd "$(dirname "$0")/.." && pwd)
cd "$ROOT"

APP_NAME="iFocus"
BUNDLE_ID="com.kun.ifocus"
MACOS_MIN_VERSION="13.0"
BUILD_DIR="$ROOT/Build"
APP_DIR="$BUILD_DIR/${APP_NAME}.app"
BUILD_STAGE="$BUILD_DIR/.${APP_NAME}.build-source.$$"

# Never replace installed bundles while an older process is still in memory.
if pgrep -x "$APP_NAME" >/dev/null 2>&1; then
  echo "ERROR: Quit iFocus before packaging so an old process cannot remain open." >&2
  exit 1
fi

# Preflight all destinations before building or replacing any bundle.
mkdir -p "$BUILD_DIR"
DESTINATIONS=("$APP_DIR")
for destination in "/Users/kun/Desktop/${APP_NAME}.app" "/Applications/${APP_NAME}.app"; do
  parent=$(dirname "$destination")
  if [[ -d "$parent" ]]; then
    if [[ ! -w "$parent" ]]; then
      echo "ERROR: No write permission for install directory: $parent" >&2
      exit 1
    fi
    DESTINATIONS+=("$destination")
  fi
done
if [[ ! -w "$BUILD_DIR" ]]; then
  echo "ERROR: No write permission for build directory: $BUILD_DIR" >&2
  exit 1
fi

# Single source of truth: repo-root VERSION (line1=marketing, line2=build).
VERSION_FILE="$ROOT/VERSION"
if [[ -f "$VERSION_FILE" ]]; then
  APP_VERSION=$(sed -n '1p' "$VERSION_FILE" | tr -d '[:space:]')
  BUILD_VERSION=$(sed -n '2p' "$VERSION_FILE" | tr -d '[:space:]')
else
  APP_VERSION="0.0.0-dev"
  BUILD_VERSION="0"
fi

STAGES=()
BACKUPS=()
cleanup_staging() {
  if [[ -e "$BUILD_STAGE" ]]; then rm -rf "$BUILD_STAGE"; fi
  for stage in "${STAGES[@]}"; do
    if [[ -e "$stage" ]]; then rm -rf "$stage"; fi
  done
}
trap cleanup_staging EXIT

if [[ -e "$BUILD_STAGE" ]]; then
  echo "ERROR: Build staging path already exists: $BUILD_STAGE" >&2
  exit 1
fi
mkdir -p "$BUILD_STAGE/Contents/MacOS" "$BUILD_STAGE/Contents/Resources"

echo "Building SwiftPM executable..."
CLANG_MODULE_CACHE_PATH="${ROOT}/.build/clang-module-cache" \
  swift build -c "$CONF" --disable-sandbox --scratch-path .build

# Generate Info.plist
cat > "$BUILD_STAGE/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key><string>${APP_NAME}</string>
    <key>CFBundleDisplayName</key><string>${APP_NAME}</string>
    <key>CFBundleIdentifier</key><string>${BUNDLE_ID}</string>
    <key>CFBundleExecutable</key><string>${APP_NAME}</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleShortVersionString</key><string>${APP_VERSION}</string>
    <key>CFBundleVersion</key><string>${BUILD_VERSION}</string>
    <key>LSMinimumSystemVersion</key><string>${MACOS_MIN_VERSION}</string>
    <key>CFBundleDevelopmentRegion</key><string>zh_CN</string>
    <key>CFBundleLocalizations</key>
    <array>
        <string>zh_CN</string>
        <string>zh-Hans</string>
        <string>en</string>
    </array>
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
BINARY_PATH=".build/release/iFocus"
if [[ ! -f "$BINARY_PATH" ]]; then
  BINARY_PATH=$(find .build/ -name "iFocus" -type f -perm +111 | head -n 1)
fi
if [[ -z "$BINARY_PATH" || ! -f "$BINARY_PATH" ]]; then
  echo "ERROR: Failed to find iFocus binary" >&2
  exit 1
fi
cp "$BINARY_PATH" "$BUILD_STAGE/Contents/MacOS/$APP_NAME"
chmod +x "$BUILD_STAGE/Contents/MacOS/$APP_NAME"
if [[ -f "Sources/iFocus/AppIcon.icns" ]]; then
  cp "Sources/iFocus/AppIcon.icns" "$BUILD_STAGE/Contents/Resources/"
fi

# Sign once, then prepare and verify every target before swapping any target.
echo "Ad-hoc signing the app bundle..."
codesign --force --sign - "$BUILD_STAGE"
codesign --verify --deep --strict "$BUILD_STAGE"
for destination in "${DESTINATIONS[@]}"; do
  parent=$(dirname "$destination")
  stage="$parent/.${APP_NAME}.stage.$$"
  backup="$parent/.${APP_NAME}.previous.$$"
  if [[ -e "$stage" || -e "$backup" ]]; then
    echo "ERROR: Staging or backup path already exists: $parent" >&2
    exit 1
  fi
  STAGES+=("$stage")
  BACKUPS+=("$backup")
  ditto "$BUILD_STAGE" "$stage"
  if ! codesign --verify --deep --strict "$stage"; then
    rm -rf "$stage"
    echo "ERROR: Staged bundle failed signature validation: $stage" >&2
    exit 1
  fi
done

rollback_installs() {
  local count="$1"
  local index destination backup
  for ((index = count - 1; index >= 0; index--)); do
    destination="${DESTINATIONS[$index]}"
    backup="${BACKUPS[$index]}"
    if [[ -e "$destination" ]]; then rm -rf "$destination"; fi
    if [[ -e "$backup" ]]; then mv "$backup" "$destination"; fi
  done
}

# Move all incumbent bundles aside first, then install the same verified build.
moved_count=0
for index in "${!DESTINATIONS[@]}"; do
  destination="${DESTINATIONS[$index]}"
  backup="${BACKUPS[$index]}"
  if [[ -e "$destination" ]] && ! mv "$destination" "$backup"; then
    rollback_installs "$moved_count"
    echo "ERROR: Could not stage existing bundle at $destination" >&2
    exit 1
  fi
  moved_count=$((moved_count + 1))
done

for index in "${!DESTINATIONS[@]}"; do
  destination="${DESTINATIONS[$index]}"
  stage="${STAGES[$index]}"
  if ! mv "$stage" "$destination"; then
    rollback_installs "$moved_count"
    echo "ERROR: Could not install the new bundle at $destination; restored previous bundles." >&2
    exit 1
  fi
  if ! codesign --verify --deep --strict "$destination"; then
    rollback_installs "$moved_count"
    echo "ERROR: Signature validation failed at $destination; restored previous bundles." >&2
    exit 1
  fi
done

for backup in "${BACKUPS[@]}"; do
  if [[ -e "$backup" ]]; then rm -rf "$backup"; fi
done

printf 'Synchronized the same iFocus build to: %s\n' "${DESTINATIONS[*]}"
echo "Run Scripts/package_dmg.sh to produce ${APP_NAME}.dmg for release."
