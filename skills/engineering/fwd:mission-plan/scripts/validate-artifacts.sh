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
