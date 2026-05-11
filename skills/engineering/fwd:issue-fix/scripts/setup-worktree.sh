#!/usr/bin/env bash
# Set up a worktree + branch for an issue, lock state, symlink .claude/.
# Args: <issue-number>
# Stdout: absolute path of the worktree.
set -euo pipefail

ISSUE="${1:?issue number required}"
[[ "$ISSUE" =~ ^[0-9]+$ ]] || { echo "issue number must be numeric (got: $ISSUE)" >&2; exit 1; }

REPO_ROOT="$(rtk git rev-parse --show-toplevel)"
STATE_FILE="$REPO_ROOT/.claude/issue-loop/state.json"

WT_DIR="${FWD_ISSUE_FIX_WORKTREE_DIR:-$REPO_ROOT/.worktrees}"
BASE_BRANCH="${FWD_ISSUE_FIX_BASE_BRANCH:-main}"
WT_PATH="$WT_DIR/issue-$ISSUE"
BRANCH="claude/issue-$ISSUE"

mkdir -p "$WT_DIR"

# Clean up any leftover worktree/branch from an earlier crashed tick.
if [[ -d "$WT_PATH" ]]; then
  rtk git worktree remove --force "$WT_PATH" 2>/dev/null || rm -rf "$WT_PATH"
fi
if rtk git show-ref --verify --quiet "refs/heads/$BRANCH"; then
  rtk git branch -D "$BRANCH" >/dev/null 2>&1 || true
fi

# Worktree off base branch.
rtk git worktree add "$WT_PATH" -b "$BRANCH" "$BASE_BRANCH" >&2

# Symlink .claude/ into the worktree so skills/hooks/settings are present.
# Workaround for https://github.com/anthropics/claude-code/issues/28041
if [[ -d "$REPO_ROOT/.claude" ]] && [[ ! -e "$WT_PATH/.claude" ]]; then
  ln -s "$REPO_ROOT/.claude" "$WT_PATH/.claude"
fi

# Lock state.
TMP="$STATE_FILE.tmp.$$"
jq --arg n "$ISSUE" \
   --arg b "$BRANCH" \
   --arg w "$WT_PATH" \
   --arg t "$(date -u +%FT%TZ)" \
   --argjson e "$(date +%s)" '
  .issues[$n] = {
    status: "in_progress",
    branch: $b,
    worktree: $w,
    started_at: $t,
    started_at_epoch: $e
  }
' "$STATE_FILE" > "$TMP" && mv "$TMP" "$STATE_FILE"

echo "$WT_PATH"
