#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
script=scripts/linux-inspector.sh
bash -n "$script"
[[ "$(bash "$script" --version)" == 0.1.0 ]]
bash "$script" --help | grep -q 'Usage:'
report=$(mktemp)
trap 'rm -f "$report"' EXIT
bash "$script" --output "$report" >/dev/null
for term in '===== 1. OS =====' '===== 2. CPU =====' '===== 3. Kernel =====' '===== 4. GCC =====' '===== 5. libc =====' '===== 6. Package managers =====' '===== 7. Init / service manager =====' '===== 8. Python =====' '===== 9. Java / JDK =====' '===== 10. Summary ====='; do
  grep -Fq "$term" "$report"
done
if bash "$script" --not-a-real-flag >/dev/null 2>&1; then echo 'unknown flag should fail' >&2; exit 1; fi
printf 'Smoke tests passed.\n'
