#!/usr/bin/env bash
# status.sh derives pending_autonomous_commit: yes only when the worktree is dirty AND the
# most-recently-approved step was recorded in autonomous mode (approved_mode=autonomous) —
# the signal that an autonomous run was interrupted with work still waiting for one commit.
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

# Run status.sh in the worktree model: cwd = the checkout, override points at its parent root.
run_status() { # repo wtroot -> stdout
  ( cd "$1" && FWD_STEPS_WORKTREE_DIR="$2" bash "$SCRIPTS_DIR/status.sh" demo )
}
# Mark the first step approved in a given mode (independent, fixed timestamp).
set_last_mode() { # statefile mode
  local out; out="$(jq --arg m "$2" '.steps[0] |= (.status="done" | .approved_at="2026-01-01T00:00:00Z" | .approved_mode=$m)' "$1")"
  printf '%s\n' "$out" > "$1"
}

# 1. dirty + last-approved autonomous -> yes  (the jq edit itself leaves state.json dirty)
wt="$(make_wt_fixture demo)"
set_last_mode "$wt/steps/demo/.claude/steps/demo/state.json" autonomous
assert_contains "$(run_status "$wt/steps/demo" "$wt")" "pending_autonomous_commit=yes" \
  "dirty tree + autonomous last step => yes"

# 2. dirty + last-approved attended -> no
wt="$(make_wt_fixture demo)"
set_last_mode "$wt/steps/demo/.claude/steps/demo/state.json" attended
assert_contains "$(run_status "$wt/steps/demo" "$wt")" "pending_autonomous_commit=no" \
  "dirty tree + attended last step => no"

# 3. clean tree + autonomous -> no  (proves the AND actually requires dirtiness)
wt="$(make_wt_fixture demo)"; repo="$wt/steps/demo"
set_last_mode "$repo/.claude/steps/demo/state.json" autonomous
( cd "$repo" && rtk git add -A && rtk git commit -q -m "accumulated" ) >/dev/null
assert_contains "$(run_status "$repo" "$wt")" "pending_autonomous_commit=no" \
  "clean tree => no even when the last step was autonomous"

echo "  status pending_autonomous_commit verified"
