#!/usr/bin/env bash
# Proves the harness machinery is real (assertions actually fail when they should) and that
# the throwaway fixture is a working mini steps-plan a real script reads green.
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

# 1. The assert helpers must reject a mismatch — guards against a no-op "fake" harness.
assert_eq "x" "x" "equal values pass"
if ( assert_eq "x" "y" ) 2>/dev/null; then
  echo "  ✗ assert_eq accepted a mismatch (harness is a no-op)" >&2
  exit 1
fi

# 2. The fixture is a real repo carrying a valid 2-step plan on its steps branch.
fix="$(make_fixture demo)"
nsteps="$(jq '.steps | length' "$fix/.claude/steps/demo/state.json")"
assert_eq "2" "$nsteps" "fixture plan has two steps"

# 3. A real script (status.sh) reads the fixture's committed branch state and runs green.
set +e
out="$(cd "$fix" && bash "$SCRIPTS_DIR/status.sh" demo)"; code=$?
set -e
assert_exit 0 "$code" "status.sh exits ok on the fixture"
assert_contains "$out" "slug=demo"    "status.sh reports the slug"
assert_contains "$out" "progress=0/2" "status.sh reports progress"
assert_contains "$out" "next_id=S1"   "status.sh reports the next step"

echo "  harness + fixture verified"
