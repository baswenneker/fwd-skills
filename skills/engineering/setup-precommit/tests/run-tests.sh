#!/usr/bin/env bash
# Test gate for the fwd:setup-precommit scripts. Runs every test_*.sh sibling in its own bash
# process (isolation), tallies pass/fail, and exits non-zero if any failed — including
# the degenerate case of finding no test files at all (a green-but-empty gate is a lie).
#
# Tests that need the network (pre-commit hook environments) skip themselves when
# `pre-commit` is not on PATH; set FWD_TEST_OFFLINE=1 to skip them on purpose.
set -uo pipefail

TESTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
shopt -s nullglob
FILES=("$TESTS_DIR"/test_*.sh)
shopt -u nullglob

if [[ ${#FILES[@]} -eq 0 ]]; then
  echo "FAIL: no test_*.sh files found in $TESTS_DIR" >&2
  exit 1
fi

pass=0; fail=0
for f in "${FILES[@]}"; do
  name="$(basename "$f")"
  if out="$(bash "$f" 2>&1)"; then
    printf '  ✓ %s\n' "$name"
    [[ "$out" == *SKIP:* ]] && printf '%s\n' "$out" | grep 'SKIP:' | sed 's/^/      /'
    ((pass++)) || true
  else
    printf '  ✗ %s\n' "$name"
    [[ -n "$out" ]] && printf '%s\n' "$out" | sed 's/^/      /'
    ((fail++)) || true
  fi
done

echo "────────────────────────"
echo "tests: $((pass + fail)) · pass: $pass · fail: $fail"
[[ $fail -eq 0 ]]
