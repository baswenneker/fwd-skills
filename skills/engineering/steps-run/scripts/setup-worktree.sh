#!/usr/bin/env bash
# Ensure the steps worktree exists and is bootable, then echo its path.
# Normally fwd:steps-plan already created the worktree (.trees/steps/<slug>) alongside the
# branch, so this just reuses it — the main checkout was never moved. Fallbacks: recreate
# the worktree from the branch on a fresh clone (or if it was removed); and, as a safety net
# for an OLD in-place plan (or a manual switch) that left the main checkout sitting on
# steps/<slug>, free it by switching the main checkout back to base so the branch can be
# handed to a worktree. Copies untracked .env* in so the gate can boot (only when they are
# gitignored — steps commits every step with `git add -A`, so an un-ignored secret would
# land in a commit).
# Resolves the MAIN repo root itself, so it works from the main checkout OR from inside
# a worktree. Read-only on the branch content; never commits.
# Args: <slug>
# Stdout: absolute worktree path.
set -euo pipefail

SLUG="${1:?usage: setup-worktree.sh <slug>}"
command -v jq >/dev/null 2>&1 || { echo "missing-jq — install jq (brew install jq)" >&2; exit 1; }

REPO_ROOT="$(dirname "$(rtk git rev-parse --path-format=absolute --git-common-dir)")"
WT_DIR="${FWD_STEPS_WORKTREE_DIR:-$REPO_ROOT/.trees}"
WT_PATH="$WT_DIR/steps/$SLUG"
BRANCH="steps/$SLUG"

( cd "$REPO_ROOT" && rtk git show-ref --verify --quiet "refs/heads/$BRANCH" ) \
  || { echo "no-plan: no $BRANCH branch — plan first with /fwd:steps-plan" >&2; exit 1; }

# Safety net: if the MAIN checkout is itself on the branch — an OLD in-place plan mid-flight,
# or a manual switch (the new plan flow never moves the main checkout) — free it by switching
# back to base. Requires a clean tree — anything dirty is the user's, so we stop rather than
# move it.
MAIN_BRANCH="$( cd "$REPO_ROOT" && rtk git rev-parse --abbrev-ref HEAD )"
if [[ "$MAIN_BRANCH" == "$BRANCH" ]]; then
  # Only tracked modifications block the switch-back; untracked scratch/.env files ride
  # along a branch switch untouched, so ignore them here.
  DIRTY="$( cd "$REPO_ROOT" && rtk git status --porcelain --untracked-files=no | grep -vx 'ok' || true )"
  [[ -z "$DIRTY" ]] || { echo "dirty-main: main checkout is on $BRANCH with uncommitted tracked changes — commit or stash them, then re-run" >&2; exit 1; }
  BASE="$(jq -r '.base_branch // empty' "$REPO_ROOT/.claude/steps/$SLUG/state.json" 2>/dev/null || true)"
  [[ -n "$BASE" ]] || { echo "no base_branch in state.json — cannot free $BRANCH safely" >&2; exit 1; }
  ( cd "$REPO_ROOT" && rtk git switch "$BASE" >&2 )
fi

# Ensure .trees/ is gitignored so the worktree never dirties the main checkout.
GI="$REPO_ROOT/.gitignore"
if ! { [[ -f "$GI" ]] && grep -qxF '.trees/' "$GI"; }; then
  printf '%s\n' '.trees/' >> "$GI"
  echo "added .trees/ to .gitignore" >&2
fi

# Create the worktree from the branch if missing (fresh plan / fresh clone / removed tree).
if [[ ! -d "$WT_PATH" ]]; then
  mkdir -p "$WT_DIR/steps"
  ( cd "$REPO_ROOT" && rtk git worktree add "$WT_PATH" "$BRANCH" >&2 )
fi

# Copy untracked .env* into the worktree so the gate can boot. Skip tracked templates
# (already present via the branch checkout) and — critically — skip any that are NOT
# gitignored: record-step.sh runs `git add -A` every step, so an un-ignored secret would
# be committed. Warn loudly in that case instead of copying.
shopt -s nullglob
for f in "$REPO_ROOT"/.env "$REPO_ROOT"/.env.*; do
  [[ -f "$f" ]] || continue
  bn="$(basename "$f")"
  if ( cd "$REPO_ROOT" && rtk git ls-files --error-unmatch -- "$bn" >/dev/null 2>&1 ); then
    continue  # tracked template — already in the worktree
  fi
  if ! ( cd "$WT_PATH" && rtk git check-ignore -q "$bn" ); then
    echo "warn: $bn is not gitignored — NOT copied into the worktree (steps commits every step, so it would be committed). Add it to .gitignore if the gate needs it." >&2
    continue
  fi
  cp -f "$f" "$WT_PATH/"
done
shopt -u nullglob

STATE="$WT_PATH/.claude/steps/$SLUG/state.json"
[[ -f "$STATE" ]] || { echo "state.json missing in worktree: $STATE" >&2; exit 1; }

echo "$WT_PATH"
