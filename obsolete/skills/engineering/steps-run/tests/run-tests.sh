#!/usr/bin/env bash
# Test gate for the fwd:steps-run scripts. Runs every test_*.sh sibling in its own bash
# process (isolation), tallies pass/fail, and exits non-zero if any failed — including
# the degenerate case of finding no test files at all (a green-but-empty gate is a lie).
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
