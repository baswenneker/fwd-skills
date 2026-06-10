#!/usr/bin/env bash
# Emit the next parallel wave of ready features (deps ⊆ done, current milestone, cap).
# Refuses v1 missions (no depends_on key anywhere) with exit 2.
# Warns on chain DAGs (max antichain = 1) but proceeds.
# Stdout: empty if all features done; else one JSON object:
#   {"milestone":"<mid>","wave":[<feature objects, plan order>],"closes_milestone":"<mid>"|null}
# Stderr: warnings only. Exit 0 on success, exit 2 on v1 refusal.
# Usage: pick-wave.sh <slug>
set -euo pipefail

SLUG="${1:?usage: pick-wave.sh <slug>}"
command -v jq >/dev/null 2>&1 || { echo "missing-jq" >&2; exit 1; }

REPO_ROOT="$(dirname "$(rtk git rev-parse --path-format=absolute --git-common-dir)")"
WT_DIR="${FWD_MISSION_WORKTREE_DIR:-$REPO_ROOT/.trees}"
STATE="$WT_DIR/mission/$SLUG/.claude/missions/$SLUG/state.json"
[[ -f "$STATE" ]] || { echo "state.json missing: $STATE" >&2; exit 1; }

CAP="${FWD_MISSION_MAX_PARALLEL:-3}"

# ── v1 refusal ──────────────────────────────────────────────────────────────
# A v1 mission has NO feature with a depends_on key anywhere. Exit 2.
HAS_DAG="$(jq 'any(.features[]; has("depends_on"))' "$STATE")"
if [[ "$HAS_DAG" == "false" ]]; then
  cat >&2 <<'EOF'
REFUSE: This mission has no dependency DAG (v1 plan). fwd:mission-run-parallel
requires depends_on fields to schedule parallel waves.
Run /fwd:mission-run <slug> to execute serially, or re-plan with
/fwd:mission-plan to add a DAG.
EOF
  exit 2
fi

# ── All done? ────────────────────────────────────────────────────────────────
NOT_DONE="$(jq -r '[.features[] | select(.status != "done")] | length' "$STATE")"
if [[ "$NOT_DONE" -eq 0 ]]; then
  exit 0
fi

# ── Current milestone ────────────────────────────────────────────────────────
# First feature (plan order) with status != done; its milestone = current milestone.
CURRENT_MID="$(jq -r 'first(.features[] | select(.status != "done") | .milestone)' "$STATE")"

# ── Build effective deps (chain semantics for absent depends_on) ──────────────
# For each feature: if depends_on key is present use it; else if it has a
# predecessor in the features[] array use that as implicit dep. depends_on: [] = no deps.
# We work in jq; produce an array of {id, milestone, status, serial_only, effective_deps[]}.
READY_JSON="$(jq -c --arg mid "$CURRENT_MID" '
  # Build index: feature id -> array index
  (.features | to_entries | map({key: .value.id, value: .key}) | from_entries) as $idx

  # Produce effective deps for every feature
  | [ .features | to_entries[] |
      .key as $i | .value as $f |
      ($f | has("depends_on")) as $has_dep |
      (if $has_dep then $f.depends_on
       elif $i > 0 then [.features[$i-1].id]
       else []
       end) as $eff_deps |
      { id: $f.id,
        milestone: $f.milestone,
        status: $f.status,
        serial_only: ($f.serial_only // false),
        effective_deps: $eff_deps }
    ]
  | . as $all

  # Ready = in current milestone, status pending, ALL effective deps are done
  | [ $all[] |
      select(
        .milestone == $mid and
        .status == "pending" and
        ( .effective_deps | all(. as $dep | $all[] | select(.id == $dep) | .status == "done") )
      )
    ]
' "$STATE")"

# ── Chain-DAG warning ────────────────────────────────────────────────────────
# Chain-shaped DAG: every wave would be size 1 (max antichain = 1).
# We test: across ALL features, the maximum set of mutually independent features = 1.
# Equivalent: every non-first feature has the previous as its only effective dep (pure chain).
# We compute this by checking: does any pair of features share no dependency relationship?
# Simplified heuristic: if in the current milestone every ready feature has >= 1 dep,
# and the ready set has size <= 1, warn. For a real chain detection we look at all features.
IS_CHAIN="$(jq '
  # Build effective deps for all features
  [ .features | to_entries[] |
    .key as $i | .value as $f |
    ($f | has("depends_on")) as $has_dep |
    (if $has_dep then $f.depends_on
     elif $i > 0 then [.features[$i-1].id]
     else []
     end) as $eff_deps |
    { id: $f.id, effective_deps: $eff_deps }
  ] as $all_deps

  # A pure chain: every feature (except possibly the first) depends on exactly one
  # predecessor, forming a linear sequence. We check: no two features can both be
  # in-deps-independent of each other (i.e. neither is in the other'"'"'s transitive deps).
  # Simplified: maximum antichain size = 1 iff all features form a total order by deps.
  # We detect chain by checking: for every pair (a,b), one transitively depends on the other.
  # Practical approximation: if every feature has at most 1 effective dep and it forms a chain.
  | ($all_deps | map(.effective_deps | length) | max) as $max_deg
  | ($all_deps | length) as $n
  | if $n <= 1 then false
    else
      # Count features with exactly 1 dep (chain links) vs 0 deps (roots/independent)
      ($all_deps | map(select(.effective_deps | length == 0)) | length) as $roots
      | ($all_deps | map(select(.effective_deps | length == 1)) | length) as $chain_links
      | ($roots <= 1 and ($roots + $chain_links) == $n)
    end
' "$STATE")"

if [[ "$IS_CHAIN" == "true" ]]; then
  echo "WARNING: DAG is chain-shaped (every wave is size 1; no parallelism gain). Consider /fwd:mission-run <slug> for serial execution." >&2
fi

# ── Wave formation ───────────────────────────────────────────────────────────
# READY_JSON is an array of ready feature descriptors.
# We need the full feature objects from state.json in plan order.
WAVE_JSON="$(jq -c --arg mid "$CURRENT_MID" --argjson cap "$CAP" --argjson ready "$READY_JSON" '
  # Index ready ids
  ($ready | map(.id) | map({key: ., value: true}) | from_entries) as $ready_ids

  # Collect full feature objects that are ready, in plan order
  | [.features[] | select(.id | in($ready_ids))] as $ready_features

  # Wave formation logic
  | if ($ready_features | length) == 0 then
      []
    elif ($ready_features[0].serial_only // false) then
      # First ready is serial_only: solo wave of exactly that one
      [$ready_features[0]]
    else
      # Collect non-serial_only ready features up to cap,
      # stopping BEFORE the first serial_only ready feature
      reduce $ready_features[] as $f (
        {"wave": [], "stop": false};
        if .stop then .
        elif ($f.serial_only // false) then .stop = true
        elif (.wave | length) >= $cap then .stop = true
        else .wave += [$f]
        end
      ) | .wave
    end
' "$STATE")"

WAVE_LEN="$(echo "$WAVE_JSON" | jq 'length')"

# If nothing ready (all blocked or waiting), return nothing (serial would also stall).
if [[ "$WAVE_LEN" -eq 0 ]]; then
  exit 0
fi

# ── closes_milestone ─────────────────────────────────────────────────────────
# Set iff this wave contains ALL remaining not-done features of the current milestone.
CLOSES="$(jq -c --arg mid "$CURRENT_MID" --argjson wave "$WAVE_JSON" '
  ($wave | map(.id) | map({key: ., value: true}) | from_entries) as $wave_ids
  | ([.features[] | select(.milestone == $mid and .status != "done") | .id] |
     all(. | in($wave_ids))) as $all_covered
  | if $all_covered then $mid else null end
' "$STATE")"

# ── Emit ─────────────────────────────────────────────────────────────────────
jq -cn --arg mid "$CURRENT_MID" --argjson wave "$WAVE_JSON" --argjson closes "$CLOSES" '
  {milestone: $mid, wave: $wave, closes_milestone: $closes}
'
