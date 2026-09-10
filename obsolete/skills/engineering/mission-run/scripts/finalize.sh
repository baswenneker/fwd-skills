#!/usr/bin/env bash
# Finalize a mission: derive done|blocked from feature/milestone states, commit the
# final state, scrub the copied .env* + boot artifacts from the worktree, and KEEP
# the worktree for review.
# Args: <slug>. Stdout: "done" | "blocked". Exit 1 if the mission isn't complete yet.
set -euo pipefail

SLUG="${1:?usage: finalize.sh <slug>}"
command -v jq >/dev/null 2>&1 || { echo "missing-jq" >&2; exit 1; }
REPO_ROOT="$(dirname "$(rtk git rev-parse --path-format=absolute --git-common-dir)")"
WT_DIR="${FWD_MISSION_WORKTREE_DIR:-$REPO_ROOT/.trees}"
WT_PATH="$WT_DIR/mission/$SLUG"
STATE="$WT_PATH/.claude/missions/$SLUG/state.json"
[[ -f "$STATE" ]] || { echo "state.json missing: $STATE" >&2; exit 1; }

BLOCKED_F="$(jq    '[.features[]   | select(.status == "blocked")] | length' "$STATE")"
PENDING_FEAT="$(jq '[.features[]   | select(.status != "done" and .status != "blocked")] | length' "$STATE")"
FAILED_M="$(jq     '[.milestones[] | select(.validation_status == "failed")]  | length' "$STATE")"
PENDING_M="$(jq    '[.milestones[] | select(.validation_status == "pending")] | length' "$STATE")"

if (( BLOCKED_F > 0 || FAILED_M > 0 )); then
  OUT=blocked
elif (( PENDING_FEAT > 0 )); then
  echo "mission not complete: $PENDING_FEAT feature(s) still to do — keep running" >&2
  exit 1
elif (( PENDING_M > 0 )); then
  echo "all features done but $PENDING_M milestone(s) never validated — marking blocked for review" >&2
  OUT=blocked
else
  OUT=done
fi

# A bootable deliverable may only be "done" after a successful cold start: the runner
# must have booted it fresh (the way the user will) and recorded the proof in state.
# The human waiver (FWD_MISSION_ACCEPT_UNVERIFIED) covers this refusal too — it is
# the same "unproven" family as null verdicts, and there is only ONE waiver.
WAIVER=""
if [[ "$OUT" == "done" ]]; then
  BOOT_CMD="$(jq -r '.user_testing.boot_command // empty' "$STATE")"
  PROOF_OK="$(jq -r '.cold_start_proof.ok // false' "$STATE")"
  if [[ -n "$BOOT_CMD" && "$PROOF_OK" != "true" ]]; then
    if [[ -n "${FWD_MISSION_ACCEPT_UNVERIFIED:-}" ]]; then
      WAIVER="${FWD_MISSION_ACCEPT_UNVERIFIED}"
      echo "missing cold-start-proof accepted by human waiver: $WAIVER" >&2
    else
      echo "no cold-start-proof: boot_command is set but cold_start_proof.ok is not true — run the RUNBOOK cold start first" >&2
      echo "a human can accept this knowingly: FWD_MISSION_ACCEPT_UNVERIFIED=\"<reden>\" bash \"$0\" \"$SLUG\"" >&2
      OUT=blocked
    fi
  fi
fi

# Unproven verdicts (passed: null) or milestones stuck on gates_passed never roll up
# into a silent "done". Only a human may accept them, by re-running finalize with
# FWD_MISSION_ACCEPT_UNVERIFIED="<reden>" — the reason lands in state.json.
if [[ "$OUT" == "done" ]]; then
  NULL_VCS="$(jq '[.milestones[] | (.vc_results // [])[] | select(.passed == null)] | length' "$STATE")"
  GP_M="$(jq '[.milestones[] | select(.validation_status == "gates_passed")] | length' "$STATE")"
  if (( NULL_VCS > 0 || GP_M > 0 )); then
    if [[ -n "${FWD_MISSION_ACCEPT_UNVERIFIED:-}" ]]; then
      WAIVER="${FWD_MISSION_ACCEPT_UNVERIFIED}"
      echo "unverified items accepted by human waiver: $WAIVER" >&2
    else
      echo "unproven verdicts remain ($NULL_VCS null VC(s), $GP_M gates_passed milestone(s)) — refusing a silent done." >&2
      jq -r '.milestones[] | .id as $m | (.vc_results // [])[] | select(.passed == null) | "  - \($m)/\(.id): \(.evidence // "no reason recorded")"' "$STATE" >&2
      jq -r '.milestones[] | select(.validation_status == "gates_passed") | "  - \(.id): gates_passed — niet alles bewezen"' "$STATE" >&2
      echo "a human can accept these knowingly: FWD_MISSION_ACCEPT_UNVERIFIED=\"<reden>\" bash \"$0\" \"$SLUG\"" >&2
      OUT=blocked
    fi
  fi
fi

TMP="$STATE.tmp.$$"
if [[ -n "$WAIVER" ]]; then
  jq --arg s "$OUT" --arg t "$(date -u +%FT%TZ)" --arg w "$WAIVER" \
     '.status = $s | .completed_at = $t | .unverified_waiver = {reason: $w, at: $t}' "$STATE" > "$TMP" && mv "$TMP" "$STATE"
else
  jq --arg s "$OUT" --arg t "$(date -u +%FT%TZ)" '.status = $s | .completed_at = $t' "$STATE" > "$TMP" && mv "$TMP" "$STATE"
fi

cd "$WT_PATH"
rtk git add -- ".claude/missions/$SLUG" >&2
rtk git commit -q -m "chore(mission): finalize $SLUG ($OUT)" >&2

# Scrub the copied secrets + boot artifacts; keep the worktree itself for review.
# Only remove env files that are NOT tracked by git (the copied secrets). A bare
# `rm .env.*` also matches tracked templates like .env.example and would delete
# them from the branch — so check each file and keep anything git tracks.
shopt -s nullglob
for f in "$WT_PATH"/.env "$WT_PATH"/.env.*; do
  [[ -e "$f" ]] || continue
  if git -C "$WT_PATH" ls-files --error-unmatch -- "$f" >/dev/null 2>&1; then
    continue  # tracked template (e.g. .env.example) — keep it
  fi
  rm -f "$f"
done
rm -f "$WT_PATH"/.mission-boot.pid "$WT_PATH"/.mission-boot.log
shopt -u nullglob

echo "$OUT"
