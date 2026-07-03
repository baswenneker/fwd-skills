#!/usr/bin/env bash
# Materialise a NEW steps-plan: ensure a feature branch (never main/master), scaffold
# .claude/steps/<slug>/ in the CURRENT checkout (no worktree — steps work is attended).
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
[[ "$CURRENT" == "HEAD" ]] && { echo "detached HEAD — check out a branch first" >&2; exit 1; }

# Never plan steps directly on the default branch: create steps/<slug> off it.
# Any other branch is reused as-is (the user chose it).
BASE="$CURRENT"
BRANCH="$CURRENT"
if [[ "$CURRENT" == "main" || "$CURRENT" == "master" ]]; then
  BRANCH="steps/$SLUG"
  if rtk git show-ref --verify --quiet "refs/heads/$BRANCH"; then
    echo "branch $BRANCH already exists — pick a more specific slug" >&2
    exit 1
  fi
  rtk git switch -c "$BRANCH" >&2
fi

if [[ -n "$(rtk git status --porcelain | grep -vx 'ok' || true)" ]]; then
  echo "note: working tree has uncommitted changes — they will travel with the branch" >&2
fi

mkdir -p "$STEPS_DIR"

printf 'branch=%s\nbase=%s\ndir=%s\n' "$BRANCH" "$BASE" "$STEPS_DIR"
