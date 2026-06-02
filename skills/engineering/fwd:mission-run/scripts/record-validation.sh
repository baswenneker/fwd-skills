#!/usr/bin/env bash
# Record a milestone's validation outcome and commit the checkpoint on the branch.
# Args: <slug> <milestone-id> <validation_status>   (pending|gates_passed|failed|passed)
# Stdin: JSON {"gate_results":[...], "vc_results":[{id,passed,evidence,report_path}, ...]}
#   vc_results are merged BY ID onto the milestone's existing assertions.
# Circuit breaker: passed -> reset; failed -> increment.
set -euo pipefail

SLUG="${1:?usage: record-validation.sh <slug> <milestone-id> <validation_status>}"
MID="${2:?milestone-id required}"
VSTATUS="${3:?validation_status required}"
case "$VSTATUS" in pending|gates_passed|failed|passed) ;; *) echo "bad validation_status: $VSTATUS" >&2; exit 1 ;; esac
command -v jq >/dev/null 2>&1 || { echo "missing-jq" >&2; exit 1; }

REPO_ROOT="$(rtk git rev-parse --show-toplevel)"
WT_DIR="${FWD_MISSION_WORKTREE_DIR:-$REPO_ROOT/.trees}"
WT_PATH="$WT_DIR/mission/$SLUG"
STATE="$WT_PATH/.claude/missions/$SLUG/state.json"
[[ -f "$STATE" ]] || { echo "state.json missing: $STATE" >&2; exit 1; }

IN='{}'
[[ ! -t 0 ]] && IN="$(cat)"
jq -e . >/dev/null 2>&1 <<<"$IN" || IN='{}'
GATES="$(jq -c '.gate_results // []' <<<"$IN")"
VCS="$(jq -c '.vc_results // []'   <<<"$IN")"

jq -e --arg m "$MID" 'any(.milestones[]; .id == $m)' "$STATE" >/dev/null 2>&1 \
  || { echo "no such milestone: $MID" >&2; exit 1; }

TMP="$STATE.tmp.$$"
jq --arg m "$MID" --arg vs "$VSTATUS" --arg t "$(date -u +%FT%TZ)" \
   --argjson g "$GATES" --argjson v "$VCS" '
  ($v | map({key: .id, value: .}) | from_entries) as $vmap
  | .milestones |= map(
      if .id == $m then
        .gate_results = $g
        | .vc_results = (.vc_results | map(. + ($vmap[.id] // {})))
        | .validation_status = $vs
        | .validated_at = $t
      else . end)
  | .circuit_breaker.consecutive_failures =
      (if $vs == "passed" then 0
       elif $vs == "failed" then ((.circuit_breaker.consecutive_failures // 0) + 1)
       else (.circuit_breaker.consecutive_failures // 0) end)
' "$STATE" > "$TMP" && mv "$TMP" "$STATE"

( cd "$WT_PATH" \
  && rtk git add -- ".claude/missions/$SLUG" >&2 \
  && rtk git commit -q -m "chore(mission): validate $MID ($VSTATUS)" >&2 )
echo "recorded validation $MID $VSTATUS"
