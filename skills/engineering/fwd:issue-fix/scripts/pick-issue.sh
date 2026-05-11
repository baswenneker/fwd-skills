#!/usr/bin/env bash
# Pick the oldest open issue assigned to @me, not already done/blocked/in_progress.
# Outputs JSON {"number":N,"title":"...","body":"..."} on stdout, or empty if no work.
set -euo pipefail

REPO_ROOT="$(rtk git rev-parse --show-toplevel)"
STATE_FILE="$REPO_ROOT/.claude/issue-loop/state.json"

EXCLUDED=$(jq -c '
  [.issues
   | to_entries[]
   | select(.value.status == "done" or .value.status == "blocked" or .value.status == "in_progress")
   | .key
   | tonumber]
' "$STATE_FILE")

# Network-bounded query. Empty result on timeout is treated as no-work.
RAW=$(timeout 30s gh issue list \
  --assignee @me \
  --state open \
  --json number,title,body,createdAt \
  --limit 100 2>/dev/null || echo "[]")

NEXT=$(echo "$RAW" | jq -c --argjson excluded "$EXCLUDED" '
  map(select(.number as $n | ($excluded | index($n)) | not))
  | sort_by(.createdAt)
  | (.[0] // empty)
  | if . then {number, title, body} else empty end
')

if [[ -z "$NEXT" ]]; then
  exit 0
fi

echo "$NEXT"
