#!/usr/bin/env bash
# Log a decision taken autonomously on the user's behalf into the mission state.
# Written now, committed at the next checkpoint (record-feature / record-validation).
# Usage: log-decision.sh <slug> <feature-id-or-> <situation> <action>
set -euo pipefail

SLUG="${1:?usage: log-decision.sh <slug> <feature-id-or-> <situation> <action>}"
FID="${2:?feature-id or -}"
SIT="${3:?situation}"
ACT="${4:?action}"
command -v jq >/dev/null 2>&1 || { echo "missing-jq" >&2; exit 1; }

REPO_ROOT="$(dirname "$(rtk git rev-parse --path-format=absolute --git-common-dir)")"
WT_DIR="${FWD_MISSION_WORKTREE_DIR:-$REPO_ROOT/.trees}"
STATE="$WT_DIR/mission/$SLUG/.claude/missions/$SLUG/state.json"
[[ -f "$STATE" ]] || { echo "state.json missing: $STATE" >&2; exit 1; }

TMP="$STATE.tmp.$$"
jq --arg ts "$(date -u +%FT%TZ)" --arg fid "$FID" --arg sit "$SIT" --arg act "$ACT" '
  .decisions += [ {timestamp: $ts, situation: $sit, action: $act}
    + (if $fid == "-" then {} else {feature: $fid} end) ]
' "$STATE" > "$TMP" && mv "$TMP" "$STATE"
echo "logged"
