#!/usr/bin/env bash
# Record a deterministic decision taken on the user's behalf during a tick.
# Use when something would normally prompt the user but the skill must continue silently.
# Usage: log-decision.sh <issue_number_or_-> <situation> <action>
#   <issue_number_or_->  Issue number this relates to, or "-" if none yet locked.
#   <situation>          One-line phrase describing what came up (no newlines).
#   <action>             What was chosen instead of asking.
set -euo pipefail

ISSUE_ARG="${1:?usage: log-decision.sh <issue_number_or_-> <situation> <action>}"
SITUATION="${2:?usage: log-decision.sh <issue_number_or_-> <situation> <action>}"
ACTION="${3:?usage: log-decision.sh <issue_number_or_-> <situation> <action>}"

REPO_ROOT="$(rtk git rev-parse --show-toplevel 2>/dev/null || true)"
if [[ -z "$REPO_ROOT" ]]; then
  echo "not-a-repo" >&2
  exit 1
fi

STATE_FILE="$REPO_ROOT/.claude/issue-loop/state.json"
if [[ ! -f "$STATE_FILE" ]]; then
  echo "no-state-file — run preflight first" >&2
  exit 1
fi

if ! command -v jq >/dev/null 2>&1; then
  echo "missing-jq" >&2
  exit 1
fi

TMP="$STATE_FILE.tmp.$$"
jq \
  --arg ts "$(date -u +%FT%TZ)" \
  --arg iss "$ISSUE_ARG" \
  --arg sit "$SITUATION" \
  --arg act "$ACTION" '
  .decisions = ((.decisions // []) + [
    {timestamp: $ts, situation: $sit, action: $act}
    + (if $iss == "-" then {} else {issue: ($iss | tonumber)} end)
  ])
' "$STATE_FILE" > "$TMP" && mv "$TMP" "$STATE_FILE"

echo "logged"
