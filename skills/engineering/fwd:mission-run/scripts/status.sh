#!/usr/bin/env bash
# Read-only progress report for a mission. Writes nothing. Reads state from the
# worktree if present, else from the branch (works on a fresh clone).
# Args: <slug>
set -uo pipefail

SLUG="${1:?usage: status.sh <slug>}"
command -v jq >/dev/null 2>&1 || { echo "missing-jq"; exit 1; }
GCD="$(rtk git rev-parse --path-format=absolute --git-common-dir 2>/dev/null || true)"
[[ -z "$GCD" ]] && { echo "not-a-repo"; exit 1; }
REPO_ROOT="$(dirname "$GCD")"
BRANCH="mission/$SLUG"
rtk git show-ref --verify --quiet "refs/heads/$BRANCH" || { echo "no-mission: $BRANCH"; exit 1; }

WT_DIR="${FWD_MISSION_WORKTREE_DIR:-$REPO_ROOT/.trees}"
STATE_REL=".claude/missions/$SLUG/state.json"
WT_STATE="$WT_DIR/mission/$SLUG/$STATE_REL"
if [[ -f "$WT_STATE" ]]; then STATE_JSON="$(cat "$WT_STATE")"; else STATE_JSON="$(rtk git show "$BRANCH:$STATE_REL" 2>/dev/null || true)"; fi
[[ -z "$STATE_JSON" ]] && { echo "no-state"; exit 1; }

jq -r '
  "mission \(.slug) — \(.status)   (branch \(.branch))",
  "  base: \(.base_branch)   worktree: \(.worktree)",
  "",
  "features:",
  (.features[] | "  \(.id) \(.status)\t\(if .commit_sha then .commit_sha[0:7] else "—" end)\t\(.title)\(if .error then "  [" + .error + "]" else "" end)"),
  "",
  "milestones:",
  (.milestones[] | "  \(.id) \(.validation_status)\t" + ((.vc_results // []) | map("\(.id)=\(if .passed == true then "pass" elif .passed == false then "FAIL" else "skip" end)") | join(" "))),
  "",
  "circuit breaker: \(.circuit_breaker.consecutive_failures)   decisions logged: \((.decisions // []) | length)"
' <<<"$STATE_JSON"
