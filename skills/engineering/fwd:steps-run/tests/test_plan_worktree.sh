#!/usr/bin/env bash
# Guards the plan-time-worktree lifecycle shared by steps-plan and steps-run:
#   init-steps.sh (steps-plan)  -> cuts branch + worktree in one step, NEVER switching the
#                                  main checkout (the whole reason this flow exists).
#   setup-worktree.sh (steps-run) -> reuses that worktree, idempotently, main still put.
# Uses a real repo under the shared fixture root so lib.sh's EXIT trap cleans it (worktree
# admin data lives under the same tree, so rm -rf removes both).
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

INIT="$(cd "$SCRIPTS_DIR/../../fwd:steps-plan/scripts" && pwd)/init-steps.sh"
SETUP="$SCRIPTS_DIR/setup-worktree.sh"

# Fresh repo on main, one base commit, plus an uncommitted file that must NOT ride along.
REPO="$(mktemp -d "$_FIXTURE_ROOT/plan.XXXXXX")"
(
  cd "$REPO"
  rtk git init -q -b main .
  _fixture_git_config
  printf '# base\n' > README.md
  rtk git add -A && rtk git commit -q -m base
  printf 'scratch\n' > work-in-progress.txt
) >/dev/null

# --- init-steps.sh: branch + worktree, main untouched ------------------------
set +e
OUT="$(cd "$REPO" && bash "$INIT" demo-plan 2>/dev/null)"; code=$?
set -e
assert_exit 0 "$code" "init-steps.sh exits ok"
BRANCH=$(sed -n 's/^branch=//p' <<<"$OUT")
BASE=$(sed -n 's/^base=//p'   <<<"$OUT")
WT=$(sed -n 's/^worktree=//p' <<<"$OUT")
DIR=$(sed -n 's/^dir=//p'     <<<"$OUT")

assert_eq "steps/demo-plan" "$BRANCH" "branch printed"
assert_eq "main"            "$BASE"   "base printed"
assert_eq "$WT/.claude/steps/demo-plan" "$DIR" "dir is inside the worktree"
assert_eq "main" "$(cd "$REPO" && rtk git rev-parse --abbrev-ref HEAD)" "main checkout NOT switched"
assert_eq "yes"  "$(cd "$REPO" && rtk git show-ref --verify --quiet refs/heads/steps/demo-plan && echo yes)" "branch exists"
assert_eq "yes"  "$([[ -d "$WT" ]] && echo yes)"      "worktree materialised"
assert_eq "yes"  "$([[ -d "$DIR" ]] && echo yes)"     "plan dir scaffolded in worktree"
assert_eq "yes"  "$(cd "$REPO" && grep -qxF '.trees/' .gitignore && echo yes)" ".trees/ gitignored"
assert_eq "yes"  "$([[ -f "$REPO/work-in-progress.txt" ]] && echo yes)"  "uncommitted file stays in main"
assert_eq "absent" "$([[ ! -f "$WT/work-in-progress.txt" ]] && echo absent)" "uncommitted file does NOT travel into worktree"

# --- a second plan of the same slug is refused -------------------------------
set +e
DUP="$(cd "$REPO" && bash "$INIT" demo-plan 2>&1)"; dupcode=$?
set -e
assert_eq "yes" "$([[ $dupcode -ne 0 ]] && echo yes)" "duplicate plan exits non-zero"
assert_contains "$DUP" "already exists" "duplicate plan explains why"

# --- write + commit the plan inside the worktree, as the skill does ----------
printf '{"slug":"demo-plan","status":"planned","branch":"steps/demo-plan","base_branch":"main","gate_command":"true","steps":[{"id":"S1","status":"todo"}]}\n' > "$DIR/state.json"
printf '# Stappenplan: demo\n' > "$DIR/plan.md"
( cd "$WT" && rtk git add .claude/steps/demo-plan && rtk git commit -q -m "chore(steps): plan demo-plan (1 stap)" ) >/dev/null
assert_eq "absent" "$([[ ! -d "$REPO/.claude/steps/demo-plan" ]] && echo absent)" "plan not visible in main checkout (lives on the branch)"

# --- setup-worktree.sh: reuse, idempotent, main still put --------------------
set +e
OUT2="$(cd "$REPO" && bash "$SETUP" demo-plan 2>/dev/null)"; setupcode=$?
set -e
assert_exit 0 "$setupcode" "setup-worktree.sh exits ok"
assert_eq "$WT" "$OUT2" "setup-worktree reuses the same worktree"
assert_eq "main" "$(cd "$REPO" && rtk git rev-parse --abbrev-ref HEAD)" "main checkout still on main after setup"
assert_eq "$WT" "$(cd "$REPO" && bash "$SETUP" demo-plan 2>/dev/null)" "setup-worktree is idempotent"

echo "  plan-time worktree lifecycle verified"
