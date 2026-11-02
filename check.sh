#!/usr/bin/env bash
# Unit tests + headless UI smoke. Exits non-zero on failure.
set -uo pipefail
cd "$(dirname "$0")"
GODOT="${GODOT:-godot}"
fail=0

# First run on a fresh clone: build the class cache/imports before --script works.
"$GODOT" --headless --path . --import >/dev/null 2>&1 || true

echo "== unit tests =="
"$GODOT" --headless --path . --script res://tests/run_tests.gd 2>&1 | tee /tmp/station-fence-tests.log | tail -20
grep -q "RESULT: PASS" /tmp/station-fence-tests.log || fail=1

echo "== ui smoke =="
"$GODOT" --headless --path . -- --smoke 2>&1 | tee /tmp/station-fence-smoke.log | tail -5
grep -q "SMOKE: PASS" /tmp/station-fence-smoke.log || fail=1

if [ "$fail" -eq 0 ]; then echo "ALL GREEN"; else echo "FAILED"; fi
exit "$fail"
