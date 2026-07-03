#!/usr/bin/env bash
# Record a milestone's validation outcome and commit the checkpoint on the branch.
# Args: <slug> <milestone-id> <validation_status>   (pending|gates_passed|failed|passed)
# Stdin: JSON {"gate_results":[...], "vc_results":[{id,passed,evidence,report_path}, ...],
#              "concerns":[{location,issue,why_it_matters,category}, ...]}
#   vc_results are merged BY ID onto the milestone's existing assertions.
#   concerns (OPTIONAL, schema v5): when the key is present, it REPLACES the
#   milestone's concerns for this round (an empty array clears them); when the
#   key is absent the field is left untouched — older payloads stay valid.
# Circuit breaker: passed -> reset; failed -> increment. Concerns touch neither.
set -euo pipefail

SLUG="${1:?usage: record-validation.sh <slug> <milestone-id> <validation_status>}"
MID="${2:?milestone-id required}"
VSTATUS="${3:?validation_status required}"
case "$VSTATUS" in pending|gates_passed|failed|passed) ;; *) echo "bad validation_status: $VSTATUS" >&2; exit 1 ;; esac
command -v jq >/dev/null 2>&1 || { echo "missing-jq" >&2; exit 1; }

REPO_ROOT="$(dirname "$(rtk git rev-parse --path-format=absolute --git-common-dir)")"
WT_DIR="${FWD_MISSION_WORKTREE_DIR:-$REPO_ROOT/.trees}"
WT_PATH="$WT_DIR/mission/$SLUG"
STATE="$WT_PATH/.claude/missions/$SLUG/state.json"
[[ -f "$STATE" ]] || { echo "state.json missing: $STATE" >&2; exit 1; }

IN='{}'
[[ ! -t 0 ]] && IN="$(cat)"
# Refuse malformed input instead of silently recording an empty result: a checkpoint
# without its verdicts is worse than no checkpoint (the evidence is gone for good).
jq -e . >/dev/null 2>&1 <<<"$IN" \
  || { echo "invalid JSON on stdin — refusing to record validation (verdicts would be lost)" >&2; exit 1; }
GATES="$(jq -c '.gate_results // []' <<<"$IN")"
VCS="$(jq -c '.vc_results // []'   <<<"$IN")"
HAS_CONCERNS="$(jq 'has("concerns")' <<<"$IN")"
# Refuse a non-array concerns value loudly (like vc_results does) instead of
# persisting garbage that violates the documented [{...}] schema.
if [[ "$HAS_CONCERNS" == "true" ]]; then
  jq -e '.concerns == null or (.concerns | type == "array")' >/dev/null 2>&1 <<<"$IN" \
    || { echo "invalid concerns on stdin — must be an array (or absent) — refusing to record" >&2; exit 1; }
fi
CONCERNS="$(jq -c '.concerns // []' <<<"$IN")"

jq -e --arg m "$MID" 'any(.milestones[]; .id == $m)' "$STATE" >/dev/null 2>&1 \
  || { echo "no such milestone: $MID" >&2; exit 1; }

TMP="$STATE.tmp.$$"
jq --arg m "$MID" --arg vs "$VSTATUS" --arg t "$(date -u +%FT%TZ)" \
   --argjson g "$GATES" --argjson v "$VCS" \
   --argjson hc "$HAS_CONCERNS" --argjson c "$CONCERNS" '
  ($v | map({key: .id, value: .}) | from_entries) as $vmap
  | .milestones |= map(
      if .id == $m then
        .gate_results = $g
        # Update existing entries by id AND append incoming verdicts for ids not yet
        # present — a plan that starts with an empty vc_results array must not make
        # recorded verdicts vanish.
        | .vc_results = (
            ((.vc_results // []) | map(. + ($vmap[.id] // {}))) as $updated
            | ($updated | map(.id)) as $have
            | $updated + ($v | map(select(.id as $i | ($have | index($i)) | not)))
          )
        # Concerns are per-round state, not history: replace when the payload
        # carries the key, leave untouched when it does not (schema v5, additive).
        | (if $hc then .concerns = $c else . end)
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
