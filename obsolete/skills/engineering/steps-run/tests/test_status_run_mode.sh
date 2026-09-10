#!/usr/bin/env bash
# status.sh reports the planned run mode (run_mode, attended when the field is absent so
# plans made before the field existed keep working) and tolerates the mode token the skill
# may append to the slug argument ("<slug> auto") — without it, resuming an autonomous run
# would look like a missing plan.
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

run_status() { # repo wtroot slug-arg -> stdout
  ( cd "$1" && FWD_STEPS_WORKTREE_DIR="$2" bash "$SCRIPTS_DIR/status.sh" "$3" )
}
set_run_mode() { # statefile mode
  local out; out="$(jq --arg m "$2" '.run_mode = $m' "$1")"
  printf '%s\n' "$out" > "$1"
}

# 1. no run_mode in state.json -> attended (backwards compatible default)
wt="$(make_wt_fixture demo)"
assert_contains "$(run_status "$wt/steps/demo" "$wt" demo)" "run_mode=attended" \
  "missing run_mode defaults to attended"

# 2. run_mode=autonomous is reported as planned
wt="$(make_wt_fixture demo)"
set_run_mode "$wt/steps/demo/.claude/steps/demo/state.json" autonomous
assert_contains "$(run_status "$wt/steps/demo" "$wt" demo)" "run_mode=autonomous" \
  "planned autonomous mode is reported"

# 3. a trailing mode token is stripped: still the same plan, not "no-plan"
out="$(run_status "$wt/steps/demo" "$wt" "demo auto")"
assert_contains "$out" "slug=demo" "\"<slug> auto\" resolves to the plan"
assert_contains "$out" "run_mode=autonomous" "\"<slug> auto\" still reads the plan's state"

# 4. an unknown slug still fails, so the stripping cannot mask a typo
set +e
out="$(run_status "$wt/steps/demo" "$wt" "typo auto" 2>&1)"; code=$?
set -e
assert_exit 2 "$code" "unknown slug still exits 2"
assert_contains "$out" "no-plan" "unknown slug still reports no-plan"

echo "  status run_mode + slug-token parsing verified"
