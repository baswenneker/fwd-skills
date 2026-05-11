#!/usr/bin/env bash
# Set up a worktree + branch for an issue, lock state, symlink .claude/.
# Args: <issue-number> <type> <name-slug>
#   type      — one of: fix|feat|chore|docs|refactor|perf|test|build|ci|style
#   name-slug — kebab-case, [a-z0-9]+(-[a-z0-9]+)*, ≤60 chars
# Stdout: absolute path of the worktree.
set -euo pipefail

ISSUE="${1:?issue number required}"
TYPE="${2:?type required (fix|feat|chore|docs|refactor|perf|test|build|ci|style)}"
NAME="${3:?name slug required (kebab-case)}"

[[ "$ISSUE" =~ ^[0-9]+$ ]] || { echo "issue number must be numeric (got: $ISSUE)" >&2; exit 1; }
case "$TYPE" in
  fix|feat|chore|docs|refactor|perf|test|build|ci|style) ;;
  *) echo "type must be one of fix|feat|chore|docs|refactor|perf|test|build|ci|style (got: $TYPE)" >&2; exit 1 ;;
esac
[[ "$NAME" =~ ^[a-z0-9]+(-[a-z0-9]+)*$ ]] || { echo "name slug must be kebab-case [a-z0-9]+(-[a-z0-9]+)* (got: $NAME)" >&2; exit 1; }
[[ ${#NAME} -le 60 ]] || { echo "name slug too long (${#NAME} chars, max 60)" >&2; exit 1; }

REPO_ROOT="$(rtk git rev-parse --show-toplevel)"
STATE_FILE="$REPO_ROOT/.claude/issue-loop/state.json"

WT_DIR="${FWD_ISSUE_FIX_WORKTREE_DIR:-$REPO_ROOT/.trees}"
BASE_BRANCH="${FWD_ISSUE_FIX_BASE_BRANCH:-main}"
WT_PATH="$WT_DIR/$TYPE/$NAME"
BRANCH="$TYPE/$NAME"

mkdir -p "$WT_DIR/$TYPE"

# Clean up any leftover worktree/branch from an earlier crashed tick.
if [[ -d "$WT_PATH" ]]; then
  rtk git worktree remove --force "$WT_PATH" 2>/dev/null || rm -rf "$WT_PATH"
fi
if rtk git show-ref --verify --quiet "refs/heads/$BRANCH"; then
  rtk git branch -D "$BRANCH" >/dev/null 2>&1 || true
fi

# Worktree off base branch.
rtk git worktree add "$WT_PATH" -b "$BRANCH" "$BASE_BRANCH" >&2

# Symlink children of .claude/ that aren't already in the worktree. Tracked
# subdirs (hooks/, lessons/) get materialised by `git worktree add`; only the
# gitignored ones (issue-loop/, skills/, settings.local.json) need linking, so
# whole-dir symlinking would skip when any tracked child exists.
# Workaround for https://github.com/anthropics/claude-code/issues/28041.
if [[ -d "$REPO_ROOT/.claude" ]]; then
  mkdir -p "$WT_PATH/.claude"
  shopt -s nullglob
  for child in "$REPO_ROOT/.claude"/*; do
    target="$WT_PATH/.claude/$(basename "$child")"
    [[ -e "$target" ]] || ln -s "$child" "$target"
  done
  shopt -u nullglob
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
