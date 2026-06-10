#!/usr/bin/env bash
# Validate a mission's artifacts, then commit the plan on the mission branch.
# Run by fwd:mission-plan after Claude has written mission.md / validation-contract.md /
# state.json into the worktree. Non-zero exit = fix what's reported and re-run.
# Args: <slug>
set -euo pipefail

SLUG="${1:?usage: validate-artifacts.sh <slug>}"
command -v jq >/dev/null 2>&1 || { echo "missing-jq — install jq (brew install jq)" >&2; exit 1; }

REPO_ROOT="$(rtk git rev-parse --show-toplevel)"
WT_DIR="${FWD_MISSION_WORKTREE_DIR:-$REPO_ROOT/.trees}"
WT_PATH="$WT_DIR/mission/$SLUG"
MDIR="$WT_PATH/.claude/missions/$SLUG"
STATE="$MDIR/state.json"

[[ -d "$WT_PATH" ]] || { echo "worktree missing: $WT_PATH — run init-mission.sh first" >&2; exit 1; }

errs=()
for f in mission.md validation-contract.md state.json; do
  [[ -f "$MDIR/$f" ]] || errs+=("missing $f")
done

if [[ -f "$STATE" ]]; then
  if ! jq -e . "$STATE" >/dev/null 2>&1; then
    errs+=("state.json is not valid JSON")
  else
    jq -e '.status and (.slug|type=="string") and (.features|type=="array") and (.milestones|type=="array") and (.gates|type=="array")' "$STATE" >/dev/null 2>&1 \
      || errs+=("state.json missing required fields (status/slug/features/milestones/gates)")
    [[ "$(jq '.features  | length' "$STATE" 2>/dev/null || echo 0)" -ge 1 ]] || errs+=("state.json has no features")
    [[ "$(jq '.milestones | length' "$STATE" 2>/dev/null || echo 0)" -ge 1 ]] || errs+=("state.json has no milestones")
    jq -e 'all(.features[];   .id and .status and (.vc_ids|type=="array"))' "$STATE" >/dev/null 2>&1 || errs+=("a feature is missing id/status/vc_ids")
    jq -e 'all(.milestones[]; .id and (.feature_ids|type=="array"))'        "$STATE" >/dev/null 2>&1 || errs+=("a milestone is missing id/feature_ids")
  fi
fi

if [[ -f "$MDIR/validation-contract.md" ]]; then
  grep -Eq 'VC-[0-9]+' "$MDIR/validation-contract.md" || errs+=("validation-contract.md has no VC- assertions")
fi

# ── DAG validation (depends_on — schema v2, additive) ────────────────────────
# Only runs when state.json is present and valid JSON with required fields.
# A state.json without any depends_on at all (v1) is fully valid.
if [[ -f "$STATE" ]] && jq -e '.' "$STATE" >/dev/null 2>&1 \
   && jq -e '.features and .milestones' "$STATE" >/dev/null 2>&1; then

  # Check 1: refs exist — every id in depends_on must name a real feature id.
  bad_refs=$(jq -r '
    [.features[].id] as $ids |
    .features[] |
    . as $f |
    (.depends_on // [])[] |
    select(. != null and . != "") |
    . as $dep |
    if ($ids | index($dep)) == null
    then "\($f.id) depends on unknown feature \($dep)"
    else empty
    end
  ' "$STATE" 2>/dev/null)
  while IFS= read -r line; do
    [[ -n "$line" ]] && errs+=("depends_on ref: $line")
  done <<< "$bad_refs"

  # Check 2: self-dependency counts as a cycle — catch it early with a clear message.
  self_deps=$(jq -r '
    .features[] |
    . as $f |
    (.depends_on // [])[] |
    select(. == $f.id) |
    "\($f.id) depends on itself (self-cycle)"
  ' "$STATE" 2>/dev/null)
  while IFS= read -r line; do
    [[ -n "$line" ]] && errs+=("depends_on cycle: $line")
  done <<< "$self_deps"

  # Check 3: no cycles — Kahn-style iterative peeling.
  # Build adjacency, repeatedly strip features whose all deps are satisfied.
  # If features remain after no progress in a pass → cycle; report one member.
  # Self-deps are already caught by Check 2 but still included here (they block peeling).
  cycle_err=$(jq -r '
    # Build map: id -> [deps]
    [.features[].id] as $ids |
    [.features[] | {key: .id, value: [(.depends_on // [])[] | select(. != null and . != "")]} ] |
    from_entries as $graph |

    # Kahn peel: iterate until stable
    ($ids | map(select($graph[.] | length == 0))) as $initial_ready |
    { remaining: ($ids | map(select($graph[.] | length > 0))), done: $initial_ready } |
    until(
      (.remaining | length) == 0 or
      # No progress: capture done first, then check remaining
      (
        (.done) as $done_set |
        [ .remaining[] | . as $f | select( ($graph[$f] | map(select(. as $d | ($done_set | index($d)) == null)) | length) == 0 ) ] | length == 0
      );
      # Find features whose deps are all in done set
      (.done) as $done_set |
      (.remaining | map(select(
        ($graph[.] | map(select(. as $d | ($done_set | index($d)) == null)) | length) == 0
      ))) as $newly_done |
      {
        done: (.done + $newly_done),
        remaining: (.remaining | map(select(
          ($graph[.] | map(select(. as $d | ($done_set | index($d)) == null)) | length) > 0
        )))
      }
    ) |
    if (.remaining | length) > 0
    then "cycle detected involving feature \(.remaining[0])"
    else empty
    end
  ' "$STATE" 2>/dev/null)
  while IFS= read -r line; do
    [[ -n "$line" ]] && errs+=("depends_on cycle: $line")
  done <<< "$cycle_err"

  # Check 4: no forward-milestone deps — a feature may only depend on features
  # in the same or an earlier milestone (milestone order = order of milestones[]).
  fwd_ms_err=$(jq -r '
    . as $root |
    # Build milestone rank map: milestone id -> index (0-based)
    [ $root.milestones | to_entries[] | {key: .value.id, value: .key} ] |
    from_entries as $ms_rank |
    # Build feature->milestone map
    [ $root.features[] | {key: .id, value: .milestone} ] |
    from_entries as $f_ms |
    # Check every dep edge
    $root.features[] |
    . as $f |
    ($f.depends_on // [])[] |
    select(. != null and . != "") |
    . as $dep |
    ($f_ms[$f.id]) as $f_ms_id |
    ($f_ms[$dep])  as $dep_ms_id |
    # Only flag if both milestones are known (unknown refs already caught above)
    select($f_ms_id != null and $dep_ms_id != null) |
    select(($ms_rank[$dep_ms_id] // 0) > ($ms_rank[$f_ms_id] // 0)) |
    "\($f.id) (milestone \($f_ms_id)) depends on \($dep) (milestone \($dep_ms_id)) which is in a later milestone"
  ' "$STATE" 2>/dev/null)
  while IFS= read -r line; do
    [[ -n "$line" ]] && errs+=("depends_on forward-milestone: $line")
  done <<< "$fwd_ms_err"

fi
# ── end DAG validation ────────────────────────────────────────────────────────

if [[ ${#errs[@]} -gt 0 ]]; then
  echo "invalid mission artifacts for $SLUG:" >&2
  for e in "${errs[@]}"; do echo "  - $e" >&2; done
  exit 1
fi

# Commit the plan on the mission branch. Stage ONLY the mission dir — never the
# copied .env or anything else that might be sitting in the worktree.
cd "$WT_PATH"
rtk git add -- ".claude/missions/$SLUG" >&2
if rtk git diff --cached --quiet; then
  echo "ok — artifacts valid (nothing new to commit)"
  exit 0
fi
rtk git commit -q -m "docs(mission): scope $SLUG" >&2
echo "ok — committed plan for $SLUG on mission/$SLUG ($(rtk git rev-parse --short HEAD))"
