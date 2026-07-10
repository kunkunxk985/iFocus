#!/usr/bin/env bash
# Smoke-test iFocus: package, launch, confirm process stays alive, no new crash logs.
set -euo pipefail

ROOT=$(cd "$(dirname "$0")/.." && pwd)
cd "$ROOT"

APP="$ROOT/Build/iFocus.app"
BIN="$APP/Contents/MacOS/iFocus"
CRASH_DIR="$HOME/Library/Logs/DiagnosticReports"
STAMP=$(date +%s)

echo "==> Packaging..."
bash "$ROOT/Scripts/package_app.sh"

echo "==> Version:"
/usr/libexec/PlistBuddy -c 'Print CFBundleShortVersionString' "$APP/Contents/Info.plist"
/usr/libexec/PlistBuddy -c 'Print CFBundleVersion' "$APP/Contents/Info.plist"

echo "==> Killing any old instance..."
pkill -x iFocus 2>/dev/null || true
sleep 0.5

echo "==> Launch via LaunchServices..."
open "$APP"
sleep 3

if ! pgrep -x iFocus >/dev/null; then
  echo "FAIL: process not running after open"
  ls -lt "$CRASH_DIR"/iFocus* 2>/dev/null | head -5 || true
  exit 1
fi
PID=$(pgrep -x iFocus | head -1)
echo "OK: running pid=$PID"

echo "==> Stability wait (5s)..."
sleep 5
if ! kill -0 "$PID" 2>/dev/null; then
  echo "FAIL: process died during stability wait"
  ls -lt "$CRASH_DIR"/iFocus* 2>/dev/null | head -5 || true
  exit 1
fi
echo "OK: still alive"

echo "==> Recent crash reports (should be empty for this run)..."
# Any iFocus crash newer than STAMP is a failure
NEW_CRASH=0
while IFS= read -r f; do
  [[ -z "$f" ]] && continue
  mt=$(stat -f %m "$f" 2>/dev/null || echo 0)
  if (( mt >= STAMP )); then
    echo "FAIL: new crash report $f"
    NEW_CRASH=1
  fi
done < <(ls "$CRASH_DIR"/iFocus*.ips 2>/dev/null || true)

if (( NEW_CRASH == 1 )); then
  exit 1
fi
echo "OK: no new crash reports"

echo "==> Binary sanity..."
file "$BIN"
codesign -dv "$APP" 2>&1 | head -5 || true

echo ""
echo "SMOKE TEST PASSED"
echo "App: $APP"
echo "pid: $PID (left running)"
