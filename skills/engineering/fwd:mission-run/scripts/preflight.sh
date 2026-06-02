#!/usr/bin/env bash
# Preflight for fwd:mission-run. Read-only checks; single status word on stdout.
# Any line other than "ok" means: stop the tick cleanly and report it.
# Reads state from the worktree if present, else from the branch (fresh clone).
# Resume safety is handled by reconcile.sh at loop start (commit-based), not a timer.
set -uo pipefail

SLUG="${1:?usage: preflight.sh <slug>}"

command -v jq >/dev/null 2>&1 || { echo "missing-jq"; exit 1; }
REPO_ROOT="$(rtk git rev-parse --show-toplevel 2>/dev/null || true)"
[[ -z "$REPO_ROOT" ]] && { echo "not-a-repo"; exit 1; }

BRANCH="mission/$SLUG"
rtk git show-ref --verify --quiet "refs/heads/$BRANCH" || { echo "no-mission"; exit 1; }

WT_DIR="${FWD_MISSION_WORKTREE_DIR:-$REPO_ROOT/.trees}"
STATE_REL=".claude/missions/$SLUG/state.json"
WT_STATE="$WT_DIR/mission/$SLUG/$STATE_REL"

if [[ -f "$WT_STATE" ]]; then
  STATE_JSON="$(cat "$WT_STATE")"
else
  STATE_JSON="$(rtk git show "$BRANCH:$STATE_REL" 2>/dev/null || true)"
fi
[[ -z "$STATE_JSON" ]] && { echo "no-state"; exit 1; }
jq -e . >/dev/null 2>&1 <<<"$STATE_JSON" || { echo "bad-state"; exit 1; }

STATUS="$(jq -r '.status' <<<"$STATE_JSON")"
case "$STATUS" in
  planned|in_progress) ;;
  done)    echo "mission-done"; exit 1 ;;
  blocked) echo "mission-blocked"; exit 1 ;;
  *)       echo "bad-status:$STATUS"; exit 1 ;;
esac

FAILS="$(jq -r '.circuit_breaker.consecutive_failures // 0' <<<"$STATE_JSON")"
[[ "$FAILS" -ge 3 ]] && { echo "circuit-breaker-tripped"; exit 1; }

echo "ok"
