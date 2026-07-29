#!/usr/bin/env bash
# Emit the next feature to work (first with status != done, status != blocked, and
# whose dependencies — direct or transitive, via features[].depends_on — are all
# done) and whether completing it closes its milestone.
# Stdout: JSON {"feature": {...}, "closes_milestone": "<id>"|null}, or empty when
# there is nothing to hand out. Empty stdout covers two distinct situations that
# callers must not conflate:
#   - all features are done (exit 0) — proceed to finalize.
#   - features remain, but every one of them is blocked or depends (directly or
#     transitively) on a feature that isn't done yet (exit 3, with a message on
#     stderr naming the stuck features) — do NOT finalize; report the blockage.
# A feature without depends_on (or with an empty list) behaves exactly as before
# this field existed: it is ready as soon as it isn't done or blocked itself.
set -euo pipefail

SLUG="${1:?usage: pick-next-unit.sh <slug>}"
command -v jq >/dev/null 2>&1 || { echo "missing-jq" >&2; exit 1; }

REPO_ROOT="$(dirname "$(rtk git rev-parse --path-format=absolute --git-common-dir)")"
WT_DIR="${FWD_MISSION_WORKTREE_DIR:-$REPO_ROOT/.trees}"
STATE="$WT_DIR/mission/$SLUG/.claude/missions/$SLUG/state.json"
[[ -f "$STATE" ]] || { echo "state.json missing: $STATE" >&2; exit 1; }

# First pass: find a ready candidate (if any), plus enough bookkeeping to tell
# "all done" apart from "stuck behind blocked/undone dependencies".
RESULT="$(jq -c '
  def deps_ok(fid; status; deps; visited):
    (deps[fid] // []) as $ds
    | reduce $ds[] as $d
        (true;
          if . == false then false
          elif (visited | index($d)) then .            # cycle guard: do not re-descend
          elif (status[$d] // "missing") != "done" then false
          else deps_ok($d; status; deps; visited + [$d])
          end);

  (.features | map({key: .id, value: .status}) | from_entries) as $status
  | (.features | map({key: .id, value: (.depends_on // [])}) | from_entries) as $deps
  | (.features | map(select(.status != "done" and .status != "blocked"))) as $candidates
  | (reduce $candidates[] as $c
       (null;
         if . != null then .
         elif deps_ok($c.id; $status; $deps; [$c.id]) then $c
         else .
         end)) as $winner
  | {
      winner: $winner,
      all_done: (all(.features[]; .status == "done")),
      remaining_ids: [.features[] | select(.status != "done") | .id]
    }
' "$STATE")"

WINNER="$(jq -c '.winner' <<<"$RESULT")"

if [[ "$WINNER" != "null" ]]; then
  jq -c --argjson w "$WINNER" '
    $w.milestone as $m
    | ([.features[] | select(.milestone == $m and .id != $w.id and .status != "done")] | length) as $rest
    | { feature: $w, closes_milestone: (if $rest == 0 then $m else null end) }
  ' "$STATE"
  exit 0
fi

ALL_DONE="$(jq -r '.all_done' <<<"$RESULT")"
if [[ "$ALL_DONE" == "true" ]]; then
  # Nothing left at all — the original "empty output = all done" convention.
  exit 0
fi

REMAINING="$(jq -r '.remaining_ids | join(", ")' <<<"$RESULT")"
echo "blocked: no executable feature — remaining ($REMAINING) are each blocked or depend (directly or transitively) on a feature that is not done" >&2
exit 3
