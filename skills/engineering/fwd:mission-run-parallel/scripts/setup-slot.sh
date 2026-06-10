#!/usr/bin/env bash
# Provision (or reset) a slot worktree for one wave member.
# Slots are created at the wave base = current HEAD of mission/<slug>.
# Slot path: <WT_DIR>/mission/<slug>--slot-<n>
# Temp branch: mission/<slug>--f<lowercased-feature-id>  (forced to the wave base)
# Reuses an existing slot worktree across waves (reset + branch switch) to preserve
# per-slot setup cost (e.g. node_modules). Copies .env* into the slot root.
# Safety: verifies .env is gitignored in the slot before proceeding.
# Stdout: absolute path of the slot worktree (last line).
# Usage: setup-slot.sh <slug> <slot-n> <feature-id>
set -euo pipefail

SLUG="${1:?usage: setup-slot.sh <slug> <slot-n> <feature-id>}"
SLOT_N="${2:?usage: setup-slot.sh <slug> <slot-n> <feature-id>}"
FEATURE_ID="${3:?usage: setup-slot.sh <slug> <slot-n> <feature-id>}"

command -v jq >/dev/null 2>&1 || { echo "missing-jq" >&2; exit 1; }

REPO_ROOT="$(dirname "$(rtk git rev-parse --path-format=absolute --git-common-dir)")"
WT_DIR="${FWD_MISSION_WORKTREE_DIR:-$REPO_ROOT/.trees}"

MISSION_BRANCH="mission/$SLUG"
# Lowercased feature id: F5 -> f5
FID_LOWER="${FEATURE_ID,,}"
SLOT_BRANCH="mission/$SLUG--$FID_LOWER"
SLOT_PATH="$WT_DIR/mission/$SLUG--slot-$SLOT_N"

# Verify the mission branch exists
rtk git show-ref --verify --quiet "refs/heads/$MISSION_BRANCH" \
  || { echo "no-mission: $MISSION_BRANCH" >&2; exit 1; }

# ── Wave base = current HEAD of mission/<slug> ───────────────────────────────
WAVE_BASE="$(rtk git rev-parse "refs/heads/$MISSION_BRANCH")"

# ── Create or reuse the slot worktree ────────────────────────────────────────
if [[ ! -d "$SLOT_PATH" ]]; then
  # Fresh create: make the branch first (no checkout conflict possible yet),
  # then add the worktree.
  mkdir -p "$(dirname "$SLOT_PATH")"
  rtk git branch -f "$SLOT_BRANCH" "$WAVE_BASE" >&2
  rtk git worktree add "$SLOT_PATH" "$SLOT_BRANCH" >&2
else
  # Slot exists from a previous wave.
  # 1. Detach HEAD in the slot so git branch -f can safely move the branch.
  #    (git branch -f refuses to move a branch checked out anywhere, including this slot.)
  rtk git -C "$SLOT_PATH" checkout --detach HEAD >&2

  # 2. Force-move (or create) the temp branch to the new wave base.
  rtk git branch -f "$SLOT_BRANCH" "$WAVE_BASE" >&2

  # 3. Check out the freshly moved branch in the slot.
  rtk git -C "$SLOT_PATH" checkout "$SLOT_BRANCH" >&2

  # 4. Reset hard to the wave base — cleans tracked dirty files; leaves untracked alone.
  #    (This is the intended behaviour: node_modules and other untracked artifacts survive.)
  rtk git -C "$SLOT_PATH" reset --hard "$WAVE_BASE" >&2
fi

# ── Copy .env* from the main checkout root ───────────────────────────────────
# Same mechanism as serial setup-worktree.sh; overwrites stale copies.
shopt -s nullglob
for f in "$REPO_ROOT"/.env "$REPO_ROOT"/.env.*; do
  [[ -f "$f" ]] && cp -f "$f" "$SLOT_PATH/"
done
shopt -u nullglob

# ── Safety: .env must be gitignored in the slot ──────────────────────────────
# Only verify if a .env was actually copied.
if [[ -f "$SLOT_PATH/.env" ]]; then
  rtk git -C "$SLOT_PATH" check-ignore -q .env 2>/dev/null \
    || { echo "ERROR: .env is NOT gitignored in slot $SLOT_PATH — refusing to continue." >&2; exit 1; }
fi

echo "$SLOT_PATH"
