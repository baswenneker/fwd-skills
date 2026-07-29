#!/usr/bin/env bash
# finalize-autonomous.sh turns the accumulated (uncommitted) work of an autonomous run into
# exactly one commit, and sets the plan status from what remains: done when every step is
# recorded, in_progress on a partial finalize after an early break-out.
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

STATE=".claude/steps/demo/state.json"
RS="$SCRIPTS_DIR/record-step.sh"
FIN="$SCRIPTS_DIR/finalize-autonomous.sh"

# --- all steps recorded --no-commit: one commit, status done -----------------
fix="$(make_fixture demo)"; cd "$fix"
echo "work S1" >> README.md
bash "$RS" --no-commit demo S1 "feat: eerste" </dev/null >/dev/null
echo "work S2" >> README.md
bash "$RS" --no-commit demo S2 "feat: tweede" </dev/null >/dev/null
before="$(rtk git rev-list --count HEAD)"
out="$(bash "$FIN" demo "feat: autonome afronding")"
after="$(rtk git rev-list --count HEAD)"
assert_eq "$((before + 1))" "$after"          "finalize makes exactly one commit"
assert_eq "" "$(rtk git status --porcelain | grep -vx 'ok' || true)" "finalize leaves the tree clean (all work committed)"
assert_eq "done" "$(jq -r '.status' "$STATE")" "status is done when no step remains todo"
assert_contains "$out" "status=done"          "stdout reports status=done"

# --- partial finalize (early break-out): status in_progress ------------------
fix="$(make_fixture demo)"; cd "$fix"
echo "work S1" >> README.md
bash "$RS" --no-commit demo S1 "feat: eerste" </dev/null >/dev/null
out="$(bash "$FIN" demo "feat: deel-afronding")"
assert_eq "in_progress" "$(jq -r '.status' "$STATE")" "status is in_progress when a step is still todo"
assert_contains "$out" "status=in_progress"   "stdout reports status=in_progress"

echo "  finalize-autonomous verified"
