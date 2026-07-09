#!/usr/bin/env bash
# record-step.sh commits an approved step in attended mode, but with --no-commit it only
# updates state.json + plan.md and leaves HEAD untouched — the autonomous accumulation path,
# where the single commit is deferred to the end of the run.
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

STATE=".claude/steps/demo/state.json"
PLAN=".claude/steps/demo/plan.md"
RS="$SCRIPTS_DIR/record-step.sh"

# --- attended (no flag): still commits ---------------------------------------
fix="$(make_fixture demo)"; cd "$fix"
echo "work" >> README.md
before="$(rtk git rev-list --count HEAD)"
bash "$RS" demo S1 "feat: eerste" </dev/null >/dev/null
after="$(rtk git rev-list --count HEAD)"
assert_eq "$((before + 1))" "$after"                       "attended mode adds exactly one commit"
assert_eq "done" "$(jq -r '.steps[0].status' "$STATE")"    "attended marks the step done"
assert_contains "$(cat "$PLAN")" "- [x] S1"                "attended ticks the plan.md checkbox"

# --- --no-commit: mutates state, leaves HEAD alone ---------------------------
fix="$(make_fixture demo)"; cd "$fix"
echo "work" >> README.md
head_before="$(rtk git rev-parse HEAD)"
bash "$RS" --no-commit demo S1 "feat: eerste" </dev/null >/dev/null
head_after="$(rtk git rev-parse HEAD)"
assert_eq "$head_before" "$head_after"                     "--no-commit leaves HEAD unchanged"
assert_eq "done" "$(jq -r '.steps[0].status' "$STATE")"    "--no-commit still marks the step done"
assert_eq "autonomous" "$(jq -r '.steps[0].approved_mode' "$STATE")" "--no-commit records approved_mode=autonomous"
assert_contains "$(cat "$PLAN")" "- [x] S1"                "--no-commit still ticks the plan.md checkbox"

echo "  record-step --no-commit verified"
