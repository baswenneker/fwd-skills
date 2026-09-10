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

# --- --state-only: clean tree is fine, only the bookkeeping is committed -----
fix="$(make_fixture demo)"; cd "$fix"
before="$(rtk git rev-list --count HEAD)"
bash "$RS" --state-only demo S1 "chore(steps): S1 vastgelegd — validatiestap zonder codewijziging" </dev/null >/dev/null
after="$(rtk git rev-list --count HEAD)"
assert_eq "$((before + 1))" "$after"                       "--state-only adds exactly one commit on a clean tree"
assert_eq "done" "$(jq -r '.steps[0].status' "$STATE")"    "--state-only marks the step done"
assert_contains "$(cat "$PLAN")" "- [x] S1"                "--state-only ticks the plan.md checkbox"
assert_eq ".claude/steps/demo/plan.md
.claude/steps/demo/state.json" "$(rtk git show --name-only --format= HEAD | grep -vx 'ok' | sort)" \
                                                           "--state-only commits only the run's own bookkeeping"

# --- --state-only refuses when there IS changed code -------------------------
fix="$(make_fixture demo)"; cd "$fix"
echo "work" >> README.md
set +e
bash "$RS" --state-only demo S1 "chore(steps): S1" </dev/null >/dev/null 2>&1
code=$?
set -e
assert_exit 1 "$code"                                      "--state-only refuses a tree with changed code"
assert_eq "todo" "$(jq -r '.steps[0].status' "$STATE")"    "the refused step stays todo"

# --- the two flags are mutually exclusive ------------------------------------
fix="$(make_fixture demo)"; cd "$fix"
set +e
bash "$RS" --no-commit --state-only demo S1 "chore(steps): S1" </dev/null >/dev/null 2>&1
code=$?
set -e
assert_exit 1 "$code"                                      "--no-commit and --state-only together are refused"

echo "  record-step --no-commit + --state-only verified"
