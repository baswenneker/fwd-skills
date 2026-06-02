#!/usr/bin/env bash
# Record a feature outcome + handoff and commit the checkpoint on the mission branch.
# Usage:
#   echo '<handoff-json>' | record-feature.sh <slug> <feature-id> done
#   record-feature.sh <slug> <feature-id> blocked "<reason>"   (handoff JSON optional on stdin)
# "done" requires the worktree to be clean (ignoring the copied .env*) and a new
# commit since the previously recorded feature SHA.
set -euo pipefail

SLUG="${1:?usage: record-feature.sh <slug> <feature-id> done|blocked [reason]}"
FID="${2:?feature-id required}"
OUTCOME="${3:?outcome required (done|blocked)}"
REASON="${4:-}"
command -v jq >/dev/null 2>&1 || { echo "missing-jq" >&2; exit 1; }

REPO_ROOT="$(rtk git rev-parse --show-toplevel)"
WT_DIR="${FWD_MISSION_WORKTREE_DIR:-$REPO_ROOT/.trees}"
WT_PATH="$WT_DIR/mission/$SLUG"
STATE="$WT_PATH/.claude/missions/$SLUG/state.json"
[[ -f "$STATE" ]] || { echo "state.json missing: $STATE" >&2; exit 1; }

# Handoff JSON from stdin (if piped and valid).
HANDOFF='null'
if [[ ! -t 0 ]]; then
  IN="$(cat)"
  if [[ -n "$IN" ]] && jq -e . >/dev/null 2>&1 <<<"$IN"; then HANDOFF="$IN"; fi
fi

jq -e --arg f "$FID" 'any(.features[]; .id == $f)' "$STATE" >/dev/null 2>&1 \
  || { echo "no such feature: $FID" >&2; exit 1; }

NOW="$(date -u +%FT%TZ)"
TMP="$STATE.tmp.$$"
cd "$WT_PATH"

case "$OUTCOME" in
  done)
    # Clean worktree, ignoring the copied .env* (expected, untracked).
    DIRTY="$(rtk git status --porcelain | grep -vx 'ok' | grep -vE '\.env(\.[^/]+)?$' || true)"
    if [[ -n "$DIRTY" ]]; then
      echo "worktree has uncommitted changes — coder must commit before record:" >&2
      echo "$DIRTY" >&2
      exit 1
    fi
    BASE="$(jq -r '.base_branch' "$STATE")"
    PREV="$(jq -r '[.features[].commit_sha | select(. != null)] | last // empty' "$STATE")"
    [[ -z "$PREV" ]] && PREV="$BASE"
    NEW="$(rtk git rev-list --count "$PREV..HEAD" 2>/dev/null || echo 0)"
    if [[ "$NEW" -lt 1 ]]; then
      echo "no new commit since $PREV — coder did not commit" >&2
      exit 1
    fi
    SHA="$(rtk git rev-parse HEAD)"
    jq --arg f "$FID" --arg s "$SHA" --arg t "$NOW" --argjson h "$HANDOFF" '
      (.features[] | select(.id == $f)) |= (
        .status = "done" | .commit_sha = $s | .completed_at = $t
        | .attempts = ((.attempts // 0) + 1) | .handoff = $h
        | .started_at = (.started_at // $t)
      ) | .circuit_breaker.consecutive_failures = 0
    ' "$STATE" > "$TMP" && mv "$TMP" "$STATE"
    MSG="chore(mission): checkpoint $FID done"
    ;;
  blocked)
    jq --arg f "$FID" --arg r "${REASON:-no reason given}" --arg t "$NOW" --argjson h "$HANDOFF" '
      (.features[] | select(.id == $f)) |= (
        .status = "blocked" | .error = $r | .completed_at = $t
        | .attempts = ((.attempts // 0) + 1) | .handoff = $h
      ) | .circuit_breaker.consecutive_failures = ((.circuit_breaker.consecutive_failures // 0) + 1)
    ' "$STATE" > "$TMP" && mv "$TMP" "$STATE"
    MSG="chore(mission): checkpoint $FID blocked"
    ;;
  *) echo "invalid outcome '$OUTCOME' (done|blocked)" >&2; exit 1 ;;
esac

rtk git add -- ".claude/missions/$SLUG" >&2
rtk git commit -q -m "$MSG" >&2
echo "recorded $FID $OUTCOME"
