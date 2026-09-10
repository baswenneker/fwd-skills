#!/usr/bin/env bash
# Create a NEW mission: branch + worktree + scaffolded artifact dir (status: planned).
# Called by fwd:mission-plan at approval time. Refuses if the mission already exists
# (resume an existing mission with /fwd:mission-run <slug> instead).
# Args: <slug>
# Stdout: absolute worktree path — Claude writes mission.md / validation-contract.md /
#         state.json into <worktree>/.claude/missions/<slug>/, then runs validate-artifacts.sh.
set -euo pipefail

SLUG="${1:?usage: init-mission.sh <slug>}"

[[ "$SLUG" =~ ^[a-z0-9]+(-[a-z0-9]+)*$ ]] || { echo "slug must be kebab-case [a-z0-9]+(-[a-z0-9]+)* (got: $SLUG)" >&2; exit 1; }
[[ ${#SLUG} -le 50 ]] || { echo "slug too long (${#SLUG} chars, max 50)" >&2; exit 1; }
command -v jq >/dev/null 2>&1 || { echo "missing-jq — install jq (brew install jq)" >&2; exit 1; }

REPO_ROOT="$(rtk git rev-parse --show-toplevel)"
WT_DIR="${FWD_MISSION_WORKTREE_DIR:-$REPO_ROOT/.trees}"
WT_PATH="$WT_DIR/mission/$SLUG"
BRANCH="mission/$SLUG"

# Base branch: explicit override, else the current branch (detached HEAD → its SHA).
BASE="${FWD_MISSION_BASE_BRANCH:-}"
if [[ -z "$BASE" ]]; then
  BASE="$(rtk git rev-parse --abbrev-ref HEAD)"
  [[ "$BASE" == "HEAD" ]] && BASE="$(rtk git rev-parse HEAD)"
fi

# Refuse to clobber an existing mission.
if rtk git show-ref --verify --quiet "refs/heads/$BRANCH"; then
  echo "branch $BRANCH already exists — pick a more specific slug, or resume with /fwd:mission-run $SLUG" >&2
  exit 1
fi
[[ -e "$WT_PATH" ]] && { echo "worktree path already exists: $WT_PATH" >&2; exit 1; }

# Ensure the worktree root is gitignored so it never dirties the main checkout.
GI="$REPO_ROOT/.gitignore"
if ! { [[ -f "$GI" ]] && grep -qxF '.trees/' "$GI"; }; then
  printf '%s\n' '.trees/' >> "$GI"
  echo "added .trees/ to .gitignore" >&2
fi

mkdir -p "$WT_DIR/mission"

# Worktree off the base branch. The mission's .claude/missions/<slug>/ lives INSIDE it
# as a real, tracked directory (committed on the branch) — deliberately NOT symlinked
# back to the main checkout, so the state travels with the branch to any fresh tree.
rtk git worktree add "$WT_PATH" -b "$BRANCH" "$BASE" >&2

MDIR="$WT_PATH/.claude/missions/$SLUG"
mkdir -p "$MDIR/handoffs"

# Skeleton state.json — git-derived fields are authoritative; Claude fills the rest
# (gates / user_testing / features / milestones) while preserving these top-level keys.
jq -n \
  --arg slug "$SLUG" \
  --arg branch "$BRANCH" \
  --arg wt "$WT_PATH" \
  --arg base "$BASE" \
  --arg t "$(date -u +%FT%TZ)" '
{
  version: 1,
  slug: $slug,
  title: $slug,
  status: "planned",
  branch: $branch,
  worktree: $wt,
  base_branch: $base,
  created_at: $t,
  started_at: null,
  started_at_epoch: null,
  completed_at: null,
  gates: [],
  user_testing: { boot_command: null, ready_probe: null, smoke_commands: [], playwright_present: false, teardown_command: null },
  features: [],
  milestones: [],
  circuit_breaker: { consecutive_failures: 0 },
  decisions: []
}' > "$MDIR/state.json"

# mission.md and validation-contract.md are written fresh by Claude (the planning
# skill) — no placeholders, so Write doesn't trip its read-before-write guard.

echo "$WT_PATH"
