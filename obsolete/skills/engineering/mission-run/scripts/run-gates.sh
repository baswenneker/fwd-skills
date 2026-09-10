#!/usr/bin/env bash
# Run a milestone's Layer-A gates in the worktree and capture exit codes.
# Args: <slug> <milestone-id>
# Stdout: JSON array [{id, command, exit_code, passed}].
# Exit: 0 if every gate passed, 1 if any failed, 2 on setup error.
set -uo pipefail

SLUG="${1:?usage: run-gates.sh <slug> <milestone-id>}"
MID="${2:?milestone-id required}"
command -v jq >/dev/null 2>&1 || { echo "missing-jq" >&2; exit 2; }

GCD="$(rtk git rev-parse --path-format=absolute --git-common-dir 2>/dev/null || true)"
[[ -z "$GCD" ]] && { echo "not-a-repo" >&2; exit 2; }
REPO_ROOT="$(dirname "$GCD")"
WT_DIR="${FWD_MISSION_WORKTREE_DIR:-$REPO_ROOT/.trees}"
WT_PATH="$WT_DIR/mission/$SLUG"
STATE="$WT_PATH/.claude/missions/$SLUG/state.json"
[[ -f "$STATE" ]] || { echo "state.json missing: $STATE" >&2; exit 2; }

TIMEOUT="${FWD_MISSION_GATE_TIMEOUT:-600}"
TO=(); command -v timeout >/dev/null 2>&1 && TO=(timeout "$TIMEOUT")

results='[]'
all_pass=0
while IFS=$'\t' read -r gid gcmd exp; do
  [[ -z "$gid" ]] && continue
  ( cd "$WT_PATH" && ${TO[@]+"${TO[@]}"} bash -c "$gcmd" ) >/dev/null 2>&1
  code=$?
  if [[ "$code" -eq "$exp" ]]; then pass=true; else pass=false; all_pass=1; fi
  results="$(jq --arg id "$gid" --arg c "$gcmd" --argjson code "$code" --argjson p "$pass" \
    '. + [{id:$id, command:$c, exit_code:$code, passed:$p}]' <<<"$results")"
done < <(jq -r '.gates[] | [.id, .command, (.expected_exit // 0)] | @tsv' "$STATE")

echo "$results"
exit $all_pass
