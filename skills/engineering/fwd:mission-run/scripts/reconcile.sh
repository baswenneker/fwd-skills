#!/usr/bin/env bash
# Resume reconciliation — run once at loop start (after setup-worktree).
# Handles the crash window between a coder commit and record-feature.sh:
#  - if real (non-metadata) code was committed since the last recorded feature
#    SHA and a not-done feature exists, ADOPT that feature as done at HEAD;
#  - else discard any uncommitted crash leftovers so the next coder starts clean.
# Idempotent: a healthy resume (HEAD == last recorded SHA, clean tree) is a no-op.
# Args: <slug>. Stdout: "adopted <fid>" | "cleaned" | "clean".
set -euo pipefail

SLUG="${1:?usage: reconcile.sh <slug>}"
command -v jq >/dev/null 2>&1 || { echo "missing-jq" >&2; exit 1; }
REPO_ROOT="$(dirname "$(rtk git rev-parse --path-format=absolute --git-common-dir)")"
WT_DIR="${FWD_MISSION_WORKTREE_DIR:-$REPO_ROOT/.trees}"
WT_PATH="$WT_DIR/mission/$SLUG"
STATE="$WT_PATH/.claude/missions/$SLUG/state.json"
[[ -f "$STATE" ]] || { echo "state.json missing: $STATE" >&2; exit 1; }
cd "$WT_PATH"

BASE="$(jq -r '.base_branch' "$STATE")"
# Frontier = the git-NEWEST recorded feature commit, not the array-last one. A
# milestone remediation can re-record an earlier feature and advance its commit
# past the positionally-last feature's; array order would then leave the frontier
# behind and make the diff below adopt an unrelated, unbuilt feature. Pick the
# recorded commit with the greatest history depth (linear branch → the tip).
PREV=""; PREV_N=-1
while IFS= read -r sha; do
  [[ -n "$sha" ]] || continue
  n="$(rtk git rev-list --count "$sha" 2>/dev/null | grep -oE '^[0-9]+' | head -1)"
  [[ -n "$n" ]] || continue
  if (( n > PREV_N )); then PREV_N="$n"; PREV="$sha"; fi
done < <(jq -r '.features[].commit_sha // empty' "$STATE")
[[ -z "$PREV" ]] && PREV="$BASE"
FID="$(jq -r 'first(.features[] | select(.status != "done") | .id) // empty' "$STATE")"

# Real code committed since PREV (excluding the mission metadata dir)?
CODE="$(rtk git diff --name-only "$PREV..HEAD" -- . ":(exclude).claude/missions/$SLUG" 2>/dev/null || true)"

if [[ -n "$CODE" && -n "$FID" ]]; then
  SHA="$(rtk git rev-parse HEAD)"
  TMP="$STATE.tmp.$$"
  jq --arg f "$FID" --arg s "$SHA" --arg t "$(date -u +%FT%TZ)" '
    (.features[] | select(.id == $f)) |= (
      .status = "done" | .commit_sha = $s | .completed_at = $t
      | .attempts = ((.attempts // 0) + 1)
      | .started_at = (.started_at // $t)
      | .handoff = {narrative: "adopted orphan commit on resume (committed before the previous tick recorded it)",
                    implemented: [], left_undone: [], commands: [],
                    issues_discovered: ["adopted on resume"], procedures_followed: []}
    ) | .circuit_breaker.consecutive_failures = 0
  ' "$STATE" > "$TMP" && mv "$TMP" "$STATE"
  rtk git add -- ".claude/missions/$SLUG" >&2
  rtk git commit -q -m "chore(mission): reconcile $FID (adopted)" >&2
  echo "adopted $FID"
  exit 0
fi

# Uncommitted TRACKED leftovers from a crashed attempt? (untracked .env/boot are left alone)
LEFT="$(rtk git status --porcelain --untracked-files=no | grep -vx 'ok' || true)"
if [[ -n "$LEFT" ]]; then
  rtk git reset --hard HEAD >&2
  echo "cleaned"
  exit 0
fi

echo "clean"
