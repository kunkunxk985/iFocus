#!/usr/bin/env bash
# Smoke-test iFocus: package, launch, confirm process stays alive, no new crash logs.
set -euo pipefail

REPLACE_RUNNING=0
case "${1:-}" in
    "") ;;
    --replace-running) REPLACE_RUNNING=1 ;;
    *)
        echo "Usage: bash Scripts/smoke_test.sh [--replace-running]" >&2
        exit 64
        ;;
esac

ROOT=$(cd "$(dirname "$0")/.." && pwd)
cd "$ROOT"

APP="$ROOT/Build/iFocus.app"
BIN="$APP/Contents/MacOS/iFocus"
CRASH_DIR="$HOME/Library/Logs/DiagnosticReports"
STAMP=$(date +%s)

set +e
EXISTING_PIDS=$(pgrep -x iFocus 2>/dev/null)
PGREP_STATUS=$?
set -e

if (( PGREP_STATUS > 1 )); then
    echo "REFUSING: unable to inspect running iFocus processes." >&2
    echo "Run this smoke test from a normal macOS Terminal session." >&2
    exit 3
fi

if [[ -n "$EXISTING_PIDS" ]]; then
    if (( REPLACE_RUNNING == 0 )); then
        echo "REFUSING: iFocus is already running (pid: ${EXISTING_PIDS//$'\n'/, })." >&2
        echo "The smoke test will not interrupt an active focus session." >&2
        echo "Quit iFocus first, or explicitly run:" >&2
        echo "  bash Scripts/smoke_test.sh --replace-running" >&2
        exit 3
    fi

    echo "==> Explicitly replacing running iFocus instance(s)..."
    pkill -x iFocus
    sleep 0.5
fi

echo "==> Packaging..."
bash "$ROOT/Scripts/package_app.sh"

echo "==> Version:"
/usr/libexec/PlistBuddy -c 'Print CFBundleShortVersionString' "$APP/Contents/Info.plist"
/usr/libexec/PlistBuddy -c 'Print CFBundleVersion' "$APP/Contents/Info.plist"

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
