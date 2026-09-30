#!/bin/sh
# Runs each tests/*.sh scenario and diffs its real output against
# tests/<name>.expected. Same discipline as sibling flagship projects
# (LarzBounty, LarzCrowd, LarzBank) - real captured output, no
# fabrication. Normalizes uuid.v4() pool/policy ids (full + 8-char short
# form) before comparing, since this CLI's output isn't fully
# deterministic.
#
# Env override: LARZINSURE="larzscript /path/to/bin/larzinsure.lz" to
# test another copy (used by CI).
set -e
cd "$(dirname "$0")/.."
LARZINSURE="${LARZINSURE:-larzscript bin/larzinsure.lz}"
export LARZINSURE
mkdir -p tests/data

normalize() {
  sed -E 's/[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}/UUID/g; s/\b[0-9a-f]{8}\b/xxxxxxxx/g'
}

pass=0; fail=0
for t in tests/*.sh; do
  case "$t" in *run_tests.sh) continue ;; esac
  exp="${t%.sh}.expected"
  got="$(sh "$t" 2>&1 | normalize || true)"
  if [ "$got" = "$(cat "$exp")" ]; then
    pass=$((pass+1))
  else
    fail=$((fail+1))
    echo "FAIL: $t"
    echo "$got" > /tmp/larzinsure_test_got.$$
    diff /tmp/larzinsure_test_got.$$ "$exp" || true
    rm -f /tmp/larzinsure_test_got.$$
  fi
done

echo "passed=$pass failed=$fail"
[ "$fail" -eq 0 ]
