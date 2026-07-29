#!/usr/bin/env bash
# Materialise a NEW steps-plan: cut a dedicated steps/<slug> branch off the CURRENT branch
# (recorded as base) AND create its worktree at .trees/steps/<slug> in ONE step — exactly
# like fwd:mission-plan's init-mission.sh. The main checkout is NEVER switched, so other
# terminals sharing this checkout are left undisturbed (this is the whole point: planning
# used to `git switch -c` the shared checkout, which hijacked parallel terminals until run).
# The plan (.claude/steps/<slug>/) is scaffolded INSIDE the worktree and committed there, so
# it travels with the branch to any clone. fwd:steps-run later just reuses this worktree.
# Called by fwd:steps-plan at approval time. Claude writes plan.md + state.json into the
# printed dir (inside the worktree) afterwards and commits them there.
# Args: <slug>
# Stdout (key=value lines): branch, base, worktree, dir
set -euo pipefail

SLUG="${1:?usage: init-steps.sh <slug>}"

[[ "$SLUG" =~ ^[a-z0-9]+(-[a-z0-9]+)*$ ]] || { echo "slug must be kebab-case [a-z0-9]+(-[a-z0-9]+)* (got: $SLUG)" >&2; exit 1; }
[[ ${#SLUG} -le 50 ]] || { echo "slug too long (${#SLUG} chars, max 50)" >&2; exit 1; }

REPO_ROOT="$(rtk git rev-parse --show-toplevel)"
WT_DIR="${FWD_STEPS_WORKTREE_DIR:-$REPO_ROOT/.trees}"
WT_PATH="$WT_DIR/steps/$SLUG"
BRANCH="steps/$SLUG"

# Base branch: the current branch (detached HEAD -> its SHA), recorded for the eventual
# merge suggestion. The main checkout is NOT moved off it.
BASE="$(rtk git rev-parse --abbrev-ref HEAD)"
[[ "$BASE" == "HEAD" ]] && BASE="$(rtk git rev-parse HEAD)"

# Refuse to clobber an existing plan.
if rtk git show-ref --verify --quiet "refs/heads/$BRANCH"; then
  echo "branch $BRANCH already exists — pick a more specific slug, or resume with /fwd:steps-run $SLUG" >&2
  exit 1
fi
[[ -e "$WT_PATH" ]] && { echo "worktree path already exists: $WT_PATH — pick another slug, or resume with /fwd:steps-run $SLUG" >&2; exit 1; }

# Ensure the worktree root is gitignored so it never dirties the main checkout.
GI="$REPO_ROOT/.gitignore"
if ! { [[ -f "$GI" ]] && grep -qxF '.trees/' "$GI"; }; then
  printf '%s\n' '.trees/' >> "$GI"
  echo "added .trees/ to .gitignore" >&2
fi

mkdir -p "$WT_DIR/steps"

# Cut the branch AND its worktree in one step, off base. The main checkout stays put — its
# working tree (clean or dirty) is untouched, and uncommitted changes there do NOT travel
# into the worktree (unlike the old `git switch -c`, which carried them along).
rtk git worktree add "$WT_PATH" -b "$BRANCH" "$BASE" >&2

# Scaffold the plan dir inside the worktree (the fresh branch inherited base, which has no
# such dir yet). Claude writes plan.md + state.json here next, then commits them.
mkdir -p "$WT_PATH/.claude/steps/$SLUG"

printf 'branch=%s\nbase=%s\nworktree=%s\ndir=%s\n' "$BRANCH" "$BASE" "$WT_PATH" "$WT_PATH/.claude/steps/$SLUG"
