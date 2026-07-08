#!/usr/bin/env bash
# Materialise a NEW steps-plan: cut a dedicated steps/<slug> branch off the CURRENT
# branch (recorded as base), scaffold .claude/steps/<slug>/ in the current checkout,
# and commit the plan there. NO worktree here — planning stays in place; the worktree
# is created later by fwd:steps-run (which frees this branch by switching the checkout
# back to base, then hands steps/<slug> to a worktree). That's why base must differ
# from the branch: run needs a branch to return the main checkout to.
# Called by fwd:steps-plan at approval time. Claude writes plan.md + state.json into
# the printed dir afterwards and commits them.
# Args: <slug>
# Stdout (key=value lines): branch, base, dir
set -euo pipefail

SLUG="${1:?usage: init-steps.sh <slug>}"

[[ "$SLUG" =~ ^[a-z0-9]+(-[a-z0-9]+)*$ ]] || { echo "slug must be kebab-case [a-z0-9]+(-[a-z0-9]+)* (got: $SLUG)" >&2; exit 1; }
[[ ${#SLUG} -le 50 ]] || { echo "slug too long (${#SLUG} chars, max 50)" >&2; exit 1; }

REPO_ROOT="$(rtk git rev-parse --show-toplevel)"
STEPS_DIR="$REPO_ROOT/.claude/steps/$SLUG"
[[ -e "$STEPS_DIR" ]] && { echo "steps-plan already exists: $STEPS_DIR — pick another slug, or resume with /fwd:steps-run $SLUG" >&2; exit 1; }

CURRENT="$(rtk git rev-parse --abbrev-ref HEAD)"
[[ "$CURRENT" == "HEAD" ]] && { echo "detached HEAD — check out a branch first (run needs a base branch to return to)" >&2; exit 1; }

# Always cut a dedicated steps/<slug> branch off the current branch. The current branch
# is the base: fwd:steps-run switches the checkout back to it (freeing steps/<slug>) and
# hands the branch to a worktree, so you can work in parallel from the main checkout.
BASE="$CURRENT"
BRANCH="steps/$SLUG"
[[ "$CURRENT" == "$BRANCH" ]] && { echo "already on $BRANCH — resume with /fwd:steps-run $SLUG (don't re-plan)" >&2; exit 1; }
if rtk git show-ref --verify --quiet "refs/heads/$BRANCH"; then
  echo "branch $BRANCH already exists — pick a more specific slug" >&2
  exit 1
fi
rtk git switch -c "$BRANCH" >&2

if [[ -n "$(rtk git status --porcelain | grep -vx 'ok' || true)" ]]; then
  echo "note: working tree has uncommitted changes — they will travel with the branch" >&2
fi

mkdir -p "$STEPS_DIR"

printf 'branch=%s\nbase=%s\ndir=%s\n' "$BRANCH" "$BASE" "$STEPS_DIR"
