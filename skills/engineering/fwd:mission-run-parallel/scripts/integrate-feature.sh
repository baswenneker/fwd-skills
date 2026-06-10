#!/usr/bin/env bash
# Cherry-pick a slot branch's commits onto the mission branch, run wave-gates,
# and record the result through the unchanged record-feature.sh.
#
# Usage: integrate-feature.sh <slug> <feature-id>
#   Handoff JSON is read from stdin and passed through to record-feature.sh.
#
# Exit codes:
#   0  — integration + gates clean; feature recorded done
#   1  — hard/unexpected error (set -euo pipefail default)
#   3  — cherry-pick textual conflict; feature pinned serial_only (no attempt consumed)
#   4  — wave-gate failure after clean integration; feature pinned serial_only (attempt consumed)
#   5  — empty commit range (no slot commits); no state change
#   6  — second discard (discards >= 2); feature recorded blocked
#
# Environment:
#   FWD_MISSION_WORKTREE_DIR  override .trees root (default: <repo>/.trees)
#   FWD_MISSION_WAVE_GATES    1 (default) to run per-feature gates; 0 to skip
set -euo pipefail

SLUG="${1:?usage: integrate-feature.sh <slug> <feature-id>}"
FEATURE_ID="${2:?feature-id required}"

command -v jq >/dev/null 2>&1 || { echo "missing-jq" >&2; exit 1; }

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SERIAL_SCRIPTS="$SCRIPT_DIR/../../fwd:mission-run/scripts"

REPO_ROOT="$(dirname "$(rtk git rev-parse --path-format=absolute --git-common-dir)")"
WT_DIR="${FWD_MISSION_WORKTREE_DIR:-$REPO_ROOT/.trees}"

MISSION_BRANCH="mission/$SLUG"
MISSION_WT="$WT_DIR/mission/$SLUG"
STATE="$MISSION_WT/.claude/missions/$SLUG/state.json"

[[ -f "$STATE" ]] || { echo "state.json missing: $STATE" >&2; exit 1; }

# Verify mission worktree is on the correct branch
CURRENT_BRANCH="$(rtk git -C "$MISSION_WT" rev-parse --abbrev-ref HEAD)"
if [[ "$CURRENT_BRANCH" != "$MISSION_BRANCH" ]]; then
  echo "mission worktree is on '$CURRENT_BRANCH', expected '$MISSION_BRANCH'" >&2
  exit 1
fi

# Slurp stdin (handoff JSON) — will be forwarded to record-feature.sh
HANDOFF_JSON=""
if [[ ! -t 0 ]]; then
  HANDOFF_JSON="$(cat)"
fi

# ── Derive slot branch name ──────────────────────────────────────────────────
# Slot branch: mission/<slug>--f<lowercased-feature-id>
FID_LOWER="${FEATURE_ID,,}"
SLOT_BRANCH="mission/$SLUG--$FID_LOWER"

# Verify slot branch exists (use -C to operate in the repo that owns the mission WT)
rtk git -C "$MISSION_WT" show-ref --verify --quiet "refs/heads/$SLOT_BRANCH" \
  || { echo "slot branch not found: $SLOT_BRANCH" >&2; exit 1; }

# ── Commit range ─────────────────────────────────────────────────────────────
# Range = merge-base(mission-branch, slot-branch)..slot-branch
MISSION_HEAD="$(rtk git -C "$MISSION_WT" rev-parse "refs/heads/$MISSION_BRANCH")"
MERGE_BASE="$(rtk git -C "$MISSION_WT" merge-base "refs/heads/$MISSION_BRANCH" "refs/heads/$SLOT_BRANCH")"
RANGE="$MERGE_BASE..refs/heads/$SLOT_BRANCH"

# Check for empty range (exit 5)
COMMIT_COUNT="$(rtk git -C "$MISSION_WT" rev-list --count "$RANGE" 2>/dev/null || echo 0)"
if [[ "$COMMIT_COUNT" -eq 0 ]]; then
  echo "no slot commits in range $RANGE — nothing to integrate" >&2
  exit 5
fi

# Capture pre-integration HEAD (for reset on conflict/gate-fail)
PRE_INTEGRATION_SHA="$MISSION_HEAD"

# Derive milestone for gate runs
MILESTONE="$(jq -r --arg fid "$FEATURE_ID" \
  '.features[] | select(.id == $fid) | .milestone' "$STATE")"

# Current discard count (before any new discard)
CURRENT_DISCARDS="$(jq -r --arg fid "$FEATURE_ID" \
  '.features[] | select(.id == $fid) | (.discards // 0)' "$STATE")"

# ── Helper: pin procedure (conflict or gate-fail) ────────────────────────────
# Arguments: $1 = reason ("conflict" | "wave-gate"), $2 = attempt_delta (0 or 1)
_pin_feature() {
  local reason="$1"
  local consume_attempt="$2"  # "0" = no attempt; "1" = increment attempts

  # New discard count
  local new_discards=$(( CURRENT_DISCARDS + 1 ))

  if [[ "$new_discards" -ge 2 ]]; then
    # Second discard → blocked (via record-feature.sh which also increments attempts + breaker)
    # Ensure tree is clean (reset was done before calling this)
    DIRTY="$(rtk git -C "$MISSION_WT" status --porcelain | \
              grep -vx 'ok' | \
              grep -vE '(\.env(\.[^/]+)?|\.mission-boot\.(pid|log))$' || true)"
    if [[ -n "$DIRTY" ]]; then
      echo "ERROR: mission worktree dirty before blocked recording" >&2
      rtk git -C "$MISSION_WT" reset --hard "$PRE_INTEGRATION_SHA" >&2 || true
    fi

    # record-feature.sh blocked path increments attempts and breaker
    if [[ -n "$HANDOFF_JSON" ]]; then
      echo "$HANDOFF_JSON" | bash "$SERIAL_SCRIPTS/record-feature.sh" \
        "$SLUG" "$FEATURE_ID" blocked "two discards ($reason)"
    else
      bash "$SERIAL_SCRIPTS/record-feature.sh" \
        "$SLUG" "$FEATURE_ID" blocked "two discards ($reason)"
    fi
    return 6  # caller should exit 6
  fi

  # First or subsequent discard (not yet 2): pin serial_only + log decision
  local TMP="$STATE.tmp.$$"
  local NOW
  NOW="$(date -u +%FT%TZ)"
  local attempts_delta=0
  if [[ "$consume_attempt" == "1" ]]; then
    attempts_delta=1
  fi

  jq --arg fid "$FEATURE_ID" \
     --argjson nd "$new_discards" \
     --argjson adelta "$attempts_delta" \
     --arg now "$NOW" \
     --arg sit "cherry-pick $reason on $FEATURE_ID" \
     --arg act "pinned serial_only, discard $new_discards" '
    (.features[] | select(.id == $fid)) |= (
      .serial_only = true
      | .discards = $nd
      | .attempts = ((.attempts // 0) + $adelta)
    )
    | .decisions += [{
        timestamp: $now,
        feature: $fid,
        situation: $sit,
        action: $act
      }]
  ' "$STATE" > "$TMP" && mv "$TMP" "$STATE"

  # Commit the state change (state.json is dirty; record-feature.sh clean check would fail)
  rtk git -C "$MISSION_WT" add -- ".claude/missions/$SLUG" >&2
  rtk git -C "$MISSION_WT" commit -q \
    -m "chore(mission): pin $FEATURE_ID serial_only (discard $new_discards: $reason)" >&2

  return 0
}

# ── Attempt cherry-pick ───────────────────────────────────────────────────────
CHERRY_PICK_RC=0
rtk git -C "$MISSION_WT" cherry-pick --empty=drop "$RANGE" >/dev/null 2>&1 || CHERRY_PICK_RC=$?

if [[ "$CHERRY_PICK_RC" -ne 0 ]]; then
  # ── Conflict path ────────────────────────────────────────────────────────────
  # Abort the cherry-pick to leave the tree clean
  rtk git -C "$MISSION_WT" cherry-pick --abort >/dev/null 2>&1 || true

  # Belt-and-braces: reset to pre-integration
  rtk git -C "$MISSION_WT" reset --hard "$PRE_INTEGRATION_SHA" >/dev/null 2>&1

  # Verify clean
  DIRTY="$(rtk git -C "$MISSION_WT" status --porcelain | \
            grep -vx 'ok' | \
            grep -vE '(\.env(\.[^/]+)?|\.mission-boot\.(pid|log))$' || true)"
  if [[ -n "$DIRTY" ]]; then
    echo "ERROR: mission worktree still dirty after abort+reset — manual inspection required" >&2
    echo "$DIRTY" >&2
    exit 1
  fi

  # Pin (no attempt consumed)
  _pin_result=0
  _pin_feature "conflict" "0" || _pin_result=$?

  if [[ "$_pin_result" -eq 6 ]]; then
    exit 6
  fi

  exit 3
fi

# ── Cherry-pick succeeded — optionally run wave-gates ────────────────────────
WAVE_GATES="${FWD_MISSION_WAVE_GATES:-1}"

if [[ "$WAVE_GATES" == "1" ]]; then
  GATE_RESULT=""
  GATE_RC=0
  GATE_RESULT="$(bash "$SERIAL_SCRIPTS/run-gates.sh" "$SLUG" "$MILESTONE" 2>/dev/null)" \
    || GATE_RC=$?

  if [[ "$GATE_RC" -ne 0 ]]; then
    # ── Gate failure path ─────────────────────────────────────────────────────
    # Reset this feature's commits out of the mission branch
    rtk git -C "$MISSION_WT" reset --hard "$PRE_INTEGRATION_SHA" >/dev/null 2>&1

    # Verify clean
    DIRTY="$(rtk git -C "$MISSION_WT" status --porcelain | \
              grep -vx 'ok' | \
              grep -vE '(\.env(\.[^/]+)?|\.mission-boot\.(pid|log))$' || true)"
    if [[ -n "$DIRTY" ]]; then
      echo "ERROR: mission worktree dirty after gate-fail reset" >&2
      echo "$DIRTY" >&2
      exit 1
    fi

    # Pin (attempt IS consumed on gate-fail — semantic breakage is coder-attributable)
    _pin_result=0
    _pin_feature "wave-gate" "1" || _pin_result=$?

    if [[ "$_pin_result" -eq 6 ]]; then
      exit 6
    fi

    exit 4
  fi
fi

# ── Happy path: record the feature as done ───────────────────────────────────
if [[ -n "$HANDOFF_JSON" ]]; then
  echo "$HANDOFF_JSON" | bash "$SERIAL_SCRIPTS/record-feature.sh" \
    "$SLUG" "$FEATURE_ID" done
else
  bash "$SERIAL_SCRIPTS/record-feature.sh" \
    "$SLUG" "$FEATURE_ID" done
fi

exit 0
