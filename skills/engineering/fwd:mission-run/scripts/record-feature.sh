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

REPO_ROOT="$(dirname "$(rtk git rev-parse --path-format=absolute --git-common-dir)")"
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
    # Clean worktree, ignoring the copied .env* and boot artifacts (expected, untracked).
    DIRTY="$(rtk git status --porcelain | grep -vx 'ok' | grep -vE '(\.env(\.[^/]+)?|\.mission-boot\.(pid|log))$' || true)"
    if [[ -n "$DIRTY" ]]; then
      echo "worktree has uncommitted changes — coder must commit before record:" >&2
      echo "$DIRTY" >&2
      exit 1
    fi
    BASE="$(jq -r '.base_branch' "$STATE")"
    # Frontier = the git-NEWEST recorded feature commit (see reconcile.sh for why
    # array order is wrong once a remediation re-records an earlier feature).
    PREV=""; PREV_N=-1
    while IFS= read -r sha; do
      [[ -n "$sha" ]] || continue
      n="$(rtk git rev-list --count "$sha" 2>/dev/null | grep -oE '^[0-9]+' | head -1)"
      [[ -n "$n" ]] || continue
      if (( n > PREV_N )); then PREV_N="$n"; PREV="$sha"; fi
    done < <(jq -r '.features[].commit_sha // empty' "$STATE")
    [[ -z "$PREV" ]] && PREV="$BASE"
    # Require a real CODE commit since PREV — exclude the mission metadata dir, so the
    # previous feature's metadata-only "checkpoint" commit can't be mistaken for the
    # coder's work (which would false-pass a coder that committed nothing).
    CODE="$(rtk git diff --name-only "$PREV..HEAD" -- . ":(exclude).claude/missions/$SLUG" 2>/dev/null || true)"
    if [[ -z "$CODE" ]]; then
      echo "no new code commit since $PREV — coder did not implement the feature" >&2
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
