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

# ── Rules-manifest check (schema v3, additive) ───────────────────────────────
# Only runs when state.json is present, valid JSON, AND .rules_manifest is a
# non-empty array. Plans without the field (v1/v2) pass through unchanged.
if [[ -f "$STATE" ]] && jq -e '.' "$STATE" >/dev/null 2>&1 \
   && jq -e '(.rules_manifest | type) == "array" and (.rules_manifest | length) > 0' \
      "$STATE" >/dev/null 2>&1; then

  # Resolve repo root: scripts may be called from anywhere, so use the worktree.
  MANIFEST_REPO_ROOT="$(rtk git -C "$WT_PATH" rev-parse --show-toplevel 2>/dev/null \
    || rtk git -C "$WT_PATH" rev-parse --git-common-dir 2>/dev/null | xargs dirname \
    || echo "$WT_PATH")"

  # Choose hashing tool: shasum (macOS) with sha256sum as fallback.
  if command -v shasum >/dev/null 2>&1; then
    _sha256() { shasum -a 256 "$1" | awk '{print $1}'; }
  elif command -v sha256sum >/dev/null 2>&1; then
    _sha256() { sha256sum "$1" | awk '{print $1}'; }
  else
    errs+=("rules_manifest: no sha256 tool found (need shasum or sha256sum)")
    _sha256() { echo ""; }
  fi

  manifest_len="$(jq '.rules_manifest | length' "$STATE")"
  for ((i=0; i<manifest_len; i++)); do
    entry_path="$(jq -r ".rules_manifest[$i].path" "$STATE")"
    entry_sha="$(jq  -r ".rules_manifest[$i].sha256" "$STATE")"
    full_path="$MANIFEST_REPO_ROOT/$entry_path"

    if [[ ! -f "$full_path" ]]; then
      errs+=("rules_manifest: file missing: $entry_path")
    else
      actual_sha="$(_sha256 "$full_path")"
      if [[ "$actual_sha" != "$entry_sha" ]]; then
        errs+=("rules_manifest: hash mismatch for $entry_path (expected $entry_sha, got $actual_sha)")
      fi
    fi
  done
fi
# ── end rules-manifest check ─────────────────────────────────────────────────

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
