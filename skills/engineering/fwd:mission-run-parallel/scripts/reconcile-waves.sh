#!/usr/bin/env bash
# Crash-recovery for parallel waves.
# Run by the orchestrator at tick start BEFORE picking a wave.
# When it runs, no wave is in flight (orchestrator is single-threaded), so
# ANY slot artifact is a leftover from a previous crash.
#
# Actions:
#   1. Remove leftover slot worktrees: <WT_DIR>/mission/<slug>--slot-*
#   2. Remove leftover slot branches:  mission/<slug>--f*
#      (the mission branch itself "mission/<slug>" is NEVER touched)
#   3. Print a summary: "slots-removed <n> branches-removed <m>" or "slots-clean"
#   4. Delegate to serial reconcile.sh and surface its output + exit code
#
# Usage: reconcile-waves.sh <slug>
# Stdout: serial reconcile.sh output (adopted <fid> | cleaned | clean)
set -euo pipefail

SLUG="${1:?usage: reconcile-waves.sh <slug>}"
command -v jq >/dev/null 2>&1 || { echo "missing-jq" >&2; exit 1; }

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SERIAL_SCRIPTS="$SCRIPT_DIR/../../fwd:mission-run/scripts"

REPO_ROOT="$(dirname "$(rtk git rev-parse --path-format=absolute --git-common-dir)")"
WT_DIR="${FWD_MISSION_WORKTREE_DIR:-$REPO_ROOT/.trees}"

MISSION_WT="$WT_DIR/mission/$SLUG"

# ── 1. Remove leftover slot worktrees ────────────────────────────────────────
# Pattern: <WT_DIR>/mission/<slug>--slot-*
# These are worktrees for individual coder slots; never the mission worktree itself.

SLOTS_REMOVED=0

# Use glob to find candidate paths; avoid globbing outside this prefix.
shopt -s nullglob
for slot_path in "$WT_DIR/mission/$SLUG--slot-"*; do
  if [[ -d "$slot_path" ]]; then
    # Try git worktree remove --force; fall back to rm -rf + prune if it refuses.
    if rtk git worktree remove --force "$slot_path" >/dev/null 2>&1; then
      : # removed via git
    else
      rm -rf "$slot_path"
      rtk git worktree prune >/dev/null 2>&1 || true
    fi
    SLOTS_REMOVED=$((SLOTS_REMOVED + 1))
  fi
done
shopt -u nullglob

# Even if we removed all directories, prune any stale registrations left behind.
rtk git worktree prune >/dev/null 2>&1 || true

# ── 2. Remove leftover slot branches ─────────────────────────────────────────
# Pattern: refs/heads/mission/<slug>--f*
# Use for-each-ref with an exact prefix; this never matches the mission branch
# itself ("mission/<slug>") because we require the "--f" suffix.

BRANCHES_REMOVED=0

# Collect branch names matching the slot prefix using an exact glob.
# for-each-ref format: just the refname:short (e.g. mission/<slug>--f5)
# The glob "refs/heads/mission/<slug>--f*" never matches the mission branch
# itself ("mission/<slug>") because the mission branch lacks the "--f" infix.
mapfile -t SLOT_BRANCHES < <(
  rtk git for-each-ref --format='%(refname:short)' \
    "refs/heads/mission/$SLUG--f*" 2>/dev/null || true
)
for branch in "${SLOT_BRANCHES[@]:-}"; do
  [[ -z "$branch" ]] && continue
  rtk git branch -D "$branch" >/dev/null 2>&1 || true
  BRANCHES_REMOVED=$((BRANCHES_REMOVED + 1))
done

# ── 3. Print summary ──────────────────────────────────────────────────────────
if [[ "$SLOTS_REMOVED" -eq 0 && "$BRANCHES_REMOVED" -eq 0 ]]; then
  echo "slots-clean" >&2
else
  echo "slots-removed $SLOTS_REMOVED branches-removed $BRANCHES_REMOVED" >&2
fi

# ── 4. Delegate to serial reconcile.sh ───────────────────────────────────────
# Invoke it from within the mission worktree's repo context (same as how
# reconcile.sh is called in the serial runner flow).
exec bash "$SERIAL_SCRIPTS/reconcile.sh" "$SLUG"
