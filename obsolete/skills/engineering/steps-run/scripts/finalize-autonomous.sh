#!/usr/bin/env bash
# Finalize an autonomous run: commit everything the --no-commit steps accumulated in the
# working tree as a SINGLE commit, and set the plan status from what remains — done when no
# step is still todo, in_progress on a partial finalize after an early break-out. State was
# already marked step-by-step by record-step.sh --no-commit; this only makes it durable.
# Usage: finalize-autonomous.sh <slug> "<commit message>"
# Stdout: finalized=<done>/<total> · commit=<sha> · status=<plan status>
set -euo pipefail

SLUG="${1:?usage: finalize-autonomous.sh <slug> \"<commit message>\"}"
MSG="${2:?commit message required}"
command -v jq >/dev/null 2>&1 || { echo "missing-jq — install jq (brew install jq)" >&2; exit 1; }

REPO_ROOT="$(rtk git rev-parse --show-toplevel)"
STATE="$REPO_ROOT/.claude/steps/$SLUG/state.json"
[[ -f "$STATE" ]] || { echo "state.json missing: $STATE" >&2; exit 1; }

DIRTY="$(rtk git status --porcelain | grep -vx 'ok' || true)"
[[ -n "$DIRTY" ]] || { echo "nothing to finalize — the working tree is clean for $SLUG" >&2; exit 1; }

NOW="$(date -u +%FT%TZ)"
TMP="$(mktemp)"
trap 'rm -f "$TMP"' EXIT
jq --arg t "$NOW" '
  .status = (if all(.steps[]; .status != "todo") then "done" else "in_progress" end)
  | .completed_at = (if .status == "done" then $t else .completed_at end)
' "$STATE" > "$TMP"
mv "$TMP" "$STATE"
trap - EXIT

rtk git add -A
rtk git commit -m "$MSG" >&2

DONE="$(jq -r '[.steps[] | select(.status == "done")] | length' "$STATE")"
TOTAL="$(jq -r '.steps | length' "$STATE")"
STATUS="$(jq -r '.status' "$STATE")"
SHA="$(rtk git rev-parse --short HEAD)"

echo "finalized=$DONE/$TOTAL"
echo "commit=$SHA"
echo "status=$STATUS"
