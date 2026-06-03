#!/usr/bin/env bash
# Emit the next feature to work (first with status != done) and whether completing
# it closes its milestone. Stdout: JSON {"feature": {...}, "closes_milestone": "<id>"|null}
# or empty output if all features are done.
set -euo pipefail

SLUG="${1:?usage: pick-next-unit.sh <slug>}"
command -v jq >/dev/null 2>&1 || { echo "missing-jq" >&2; exit 1; }

REPO_ROOT="$(dirname "$(rtk git rev-parse --path-format=absolute --git-common-dir)")"
WT_DIR="${FWD_MISSION_WORKTREE_DIR:-$REPO_ROOT/.trees}"
STATE="$WT_DIR/mission/$SLUG/.claude/missions/$SLUG/state.json"
[[ -f "$STATE" ]] || { echo "state.json missing: $STATE" >&2; exit 1; }

jq -c '
  (.features | map(select(.status != "done")) | .[0]) as $f
  | if $f == null then empty
    else
      $f.milestone as $m
      | ([.features[] | select(.milestone == $m and .id != $f.id and .status != "done")] | length) as $rest
      | { feature: $f, closes_milestone: (if $rest == 0 then $m else null end) }
    end
' "$STATE"
