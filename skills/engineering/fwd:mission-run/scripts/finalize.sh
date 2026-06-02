#!/usr/bin/env bash
# Finalize a mission: derive done|blocked from feature/milestone states, commit the
# final state, scrub the copied .env* + boot artifacts from the worktree, and KEEP
# the worktree for review.
# Args: <slug>. Stdout: "done" | "blocked". Exit 1 if the mission isn't complete yet.
set -euo pipefail

SLUG="${1:?usage: finalize.sh <slug>}"
command -v jq >/dev/null 2>&1 || { echo "missing-jq" >&2; exit 1; }
REPO_ROOT="$(rtk git rev-parse --show-toplevel)"
WT_DIR="${FWD_MISSION_WORKTREE_DIR:-$REPO_ROOT/.trees}"
WT_PATH="$WT_DIR/mission/$SLUG"
STATE="$WT_PATH/.claude/missions/$SLUG/state.json"
[[ -f "$STATE" ]] || { echo "state.json missing: $STATE" >&2; exit 1; }

BLOCKED_F="$(jq '[.features[]   | select(.status == "blocked")]            | length' "$STATE")"
NOTDONE_F="$(jq '[.features[]   | select(.status != "done")]              | length' "$STATE")"
FAILED_M="$(jq  '[.milestones[] | select(.validation_status == "failed")] | length' "$STATE")"

if (( BLOCKED_F > 0 || FAILED_M > 0 )); then
  OUT=blocked
elif (( NOTDONE_F == 0 )); then
  OUT=done
else
  echo "mission not complete: $NOTDONE_F feature(s) not done and none blocked — keep running" >&2
  exit 1
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
