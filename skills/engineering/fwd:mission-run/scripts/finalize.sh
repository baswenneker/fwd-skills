#!/usr/bin/env bash
# Finalize a mission: derive done|blocked from feature/milestone states, commit the
# final state, scrub the copied .env* + boot artifacts from the worktree, and KEEP
# the worktree for review.
# Args: <slug>. Stdout: "done" | "blocked". Exit 1 if the mission isn't complete yet.
set -euo pipefail

SLUG="${1:?usage: finalize.sh <slug>}"
command -v jq >/dev/null 2>&1 || { echo "missing-jq" >&2; exit 1; }
REPO_ROOT="$(dirname "$(rtk git rev-parse --path-format=absolute --git-common-dir)")"
WT_DIR="${FWD_MISSION_WORKTREE_DIR:-$REPO_ROOT/.trees}"
WT_PATH="$WT_DIR/mission/$SLUG"
STATE="$WT_PATH/.claude/missions/$SLUG/state.json"
[[ -f "$STATE" ]] || { echo "state.json missing: $STATE" >&2; exit 1; }

BLOCKED_F="$(jq    '[.features[]   | select(.status == "blocked")] | length' "$STATE")"
PENDING_FEAT="$(jq '[.features[]   | select(.status != "done" and .status != "blocked")] | length' "$STATE")"
FAILED_M="$(jq     '[.milestones[] | select(.validation_status == "failed")]  | length' "$STATE")"
PENDING_M="$(jq    '[.milestones[] | select(.validation_status == "pending")] | length' "$STATE")"

if (( BLOCKED_F > 0 || FAILED_M > 0 )); then
  OUT=blocked
elif (( PENDING_FEAT > 0 )); then
  echo "mission not complete: $PENDING_FEAT feature(s) still to do — keep running" >&2
  exit 1
elif (( PENDING_M > 0 )); then
  echo "all features done but $PENDING_M milestone(s) never validated — marking blocked for review" >&2
  OUT=blocked
else
  OUT=done
fi

TMP="$STATE.tmp.$$"
jq --arg s "$OUT" --arg t "$(date -u +%FT%TZ)" '.status = $s | .completed_at = $t' "$STATE" > "$TMP" && mv "$TMP" "$STATE"

cd "$WT_PATH"
rtk git add -- ".claude/missions/$SLUG" >&2
rtk git commit -q -m "chore(mission): finalize $SLUG ($OUT)" >&2

# Scrub the copied secrets + boot artifacts; keep the worktree itself for review.
shopt -s nullglob
rm -f "$WT_PATH"/.env "$WT_PATH"/.env.* "$WT_PATH"/.mission-boot.pid "$WT_PATH"/.mission-boot.log
shopt -u nullglob

echo "$OUT"
