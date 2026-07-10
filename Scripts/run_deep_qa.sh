#!/usr/bin/env bash
# Deep QA: unit + product regression + performance micro-benchmarks + smoke.
set -euo pipefail
ROOT=$(cd "$(dirname "$0")/.." && pwd)
cd "$ROOT"
export CLANG_MODULE_CACHE_PATH="${ROOT}/.build/clang-module-cache"

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo " 1/3  Full unit + regression tests"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
swift test --disable-sandbox --scratch-path .build

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo " 2/3  Performance micro-benchmarks"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
swift test --disable-sandbox --scratch-path .build --filter PerformanceBenchmarks 2>&1 | tee /tmp/ifocus-perf.log
echo ""
echo "—— [perf] summary ——"
grep '\[perf\]' /tmp/ifocus-perf.log || true

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo " 3/3  Package smoke"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
bash "$ROOT/Scripts/smoke_test.sh"

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo " Deep QA finished."
echo " Manual 5-min checklist: Scripts/manual_acceptance_checklist.md"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
