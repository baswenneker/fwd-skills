#!/usr/bin/env bash
# Ensure the mission worktree exists, copy .env*, transition planned -> in_progress.
# Reuses an existing worktree; recreates it from the branch on a fresh clone.
# Stdout: absolute worktree path.
set -euo pipefail

SLUG="${1:?usage: setup-worktree.sh <slug>}"
command -v jq >/dev/null 2>&1 || { echo "missing-jq" >&2; exit 1; }

REPO_ROOT="$(dirname "$(rtk git rev-parse --path-format=absolute --git-common-dir)")"
WT_DIR="${FWD_MISSION_WORKTREE_DIR:-$REPO_ROOT/.trees}"
WT_PATH="$WT_DIR/mission/$SLUG"
BRANCH="mission/$SLUG"

rtk git show-ref --verify --quiet "refs/heads/$BRANCH" || { echo "no-mission: $BRANCH" >&2; exit 1; }

# Recreate the worktree from the branch if missing (fresh clone / removed tree).
if [[ ! -d "$WT_PATH" ]]; then
  mkdir -p "$WT_DIR/mission"
  rtk git worktree add "$WT_PATH" "$BRANCH" >&2
fi

# Copy .env* into the worktree root so the User-Testing validator can boot the app.
# These stay gitignored / are guarded by risky-scan — never committed.
shopt -s nullglob
for f in "$REPO_ROOT"/.env "$REPO_ROOT"/.env.*; do
  [[ -f "$f" ]] && cp -f "$f" "$WT_PATH/"
done
shopt -u nullglob

STATE="$WT_PATH/.claude/missions/$SLUG/state.json"
[[ -f "$STATE" ]] || { echo "state.json missing in worktree: $STATE" >&2; exit 1; }

# planned -> in_progress, committed as a checkpoint. No-op if already in_progress.
if [[ "$(jq -r '.status' "$STATE")" == "planned" ]]; then
  TMP="$STATE.tmp.$$"
  jq --arg t "$(date -u +%FT%TZ)" --argjson e "$(date +%s)" '
    .status = "in_progress" | .started_at = $t | .started_at_epoch = $e
  ' "$STATE" > "$TMP" && mv "$TMP" "$STATE"
  ( cd "$WT_PATH" \
    && rtk git add -- ".claude/missions/$SLUG/state.json" >&2 \
    && rtk git commit -q -m "chore(mission): start $SLUG" >&2 )
fi

echo "$WT_PATH"
