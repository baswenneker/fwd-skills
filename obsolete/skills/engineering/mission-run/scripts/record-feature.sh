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
    # A handoff JSON is optional on stdin, but if one was actually piped in for
    # a "done" outcome, it must carry the fields the mission relies on downstream
    # (the milestone walkthrough, the finalize report, and the rules audit all
    # read these back out of state.json). Reject early with a field-specific
    # message rather than silently writing an incomplete handoff.
    if [[ "$HANDOFF" != 'null' ]]; then
      for field in implemented left_undone commands issues_discovered procedures_followed; do
        jq -e --arg f "$field" 'has($f)' >/dev/null 2>&1 <<<"$HANDOFF" \
          || { echo "handoff missing required field: $field" >&2; exit 1; }
      done
      # When the feature was assigned rule files to follow, the coder must report
      # back how each was applied — accountability without follow-through is refused.
      RULE_PATH_COUNT="$(jq -r --arg f "$FID" '(.features[] | select(.id == $f) | .rule_paths // []) | length' "$STATE")"
      if [[ "$RULE_PATH_COUNT" -gt 0 ]]; then
        RULES_APPLIED_COUNT="$(jq -r '(.rules_applied // []) | length' <<<"$HANDOFF")"
        [[ "$RULES_APPLIED_COUNT" -gt 0 ]] \
          || { echo "handoff missing non-empty rules_applied although this feature has rule_paths" >&2; exit 1; }
      fi
    fi
    # Clean worktree, ignoring the copied .env*, boot artifacts (expected, untracked),
    # and ANY change under this mission's metadata dir — the state.json that a
    # mid-feature log-decision.sh leaves tracked-dirty, plus the freshly written
    # handoff narrative. The checkpoint commit below folds that whole dir in anyway,
    # so refusing it here would only force the orchestrator into a separate commit.
    # A *tracked* file with uncommitted changes OUTSIDE that dir still fails the check.
    DIRTY="$(rtk git status --porcelain \
      | grep -vx 'ok' \
      | grep -vE '(\.env(\.[^/]+)?|\.mission-boot\.(pid|log))$' \
      | grep -vE "^.. \\.claude/missions/$SLUG/" \
      || true)"
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
    # No feature recorded a commit yet: anchor on the actual branch-off point, not
    # the base branch *tip*. The base may have advanced after we forked, and diffing
    # against its moved tip would count the base's own commits as "the coder's code".
    [[ -z "$PREV" ]] && PREV="$(rtk git merge-base "$BASE" HEAD 2>/dev/null || echo "$BASE")"
    # Require a real CODE commit since PREV — exclude the mission metadata dir, so the
    # previous feature's metadata-only "checkpoint" commit can't be mistaken for the
    # coder's work (which would false-pass a coder that committed nothing).
    CODE="$(rtk git diff --name-only "$PREV..HEAD" -- . ":(exclude).claude/missions/$SLUG" 2>/dev/null || true)"
    if [[ -z "$CODE" ]]; then
      echo "no new code commit since $PREV — coder did not implement the feature" >&2
      exit 1
    fi
    # commit_sha must point at real code: take the newest commit in range that touches
    # something outside the metadata dir, so a trailing metadata-only checkpoint commit
    # (e.g. an apart-committed state.json) never becomes the recorded feature SHA.
    SHA="$(rtk git log -1 --format=%H "$PREV..HEAD" -- . ":(exclude).claude/missions/$SLUG" 2>/dev/null || true)"
    [[ -z "$SHA" ]] && SHA="$(rtk git rev-parse HEAD)"
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
