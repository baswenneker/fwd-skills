#!/usr/bin/env bash
# Finalize the current tick.
# Args: ok|blocked <issue-number> [reason]
set -euo pipefail

OUTCOME="${1:?ok|blocked required}"
ISSUE="${2:?issue number required}"
REASON="${3:-}"

[[ "$ISSUE" =~ ^[0-9]+$ ]] || { echo "issue number must be numeric" >&2; exit 1; }

# --git-common-dir resolves to main's .git from inside a worktree too, so
# finalize works whether invoked from the main checkout or from a worktree.
REPO_ROOT="$(dirname "$(rtk git rev-parse --path-format=absolute --git-common-dir)")"
STATE_FILE="$REPO_ROOT/.claude/issue-loop/state.json"
BASE_BRANCH="${FWD_ISSUE_FIX_BASE_BRANCH:-main}"

WT_PATH=$(jq -r --arg n "$ISSUE" '.issues[$n].worktree // empty' "$STATE_FILE")
BRANCH=$(jq -r --arg n "$ISSUE" '.issues[$n].branch // empty' "$STATE_FILE")

if [[ -z "$WT_PATH" || -z "$BRANCH" ]]; then
  echo "no worktree/branch recorded for issue #$ISSUE — was setup-worktree.sh run?" >&2
  exit 1
fi

case "$OUTCOME" in
  ok)
    if [[ ! -d "$WT_PATH" ]]; then
      echo "worktree directory missing: $WT_PATH" >&2
      exit 1
    fi
    cd "$WT_PATH"

    if [[ -n "$(rtk git status --porcelain | grep -vx 'ok' || true)" ]]; then
      echo "worktree has unstaged/untracked changes — refusing to mark done" >&2
      cd "$REPO_ROOT"
      exit 1
    fi

    COMMITS=$(rtk git rev-list --count "$BASE_BRANCH..HEAD" 2>/dev/null || echo 0)
    if [[ "$COMMITS" -lt 1 ]]; then
      echo "no new commits on $BRANCH — refusing to mark done" >&2
      cd "$REPO_ROOT"
      exit 1
    fi

    SHA=$(rtk git rev-parse HEAD)
    cd "$REPO_ROOT"

    TMP="$STATE_FILE.tmp.$$"
    jq --arg n "$ISSUE" \
       --arg s "$SHA" \
       --argjson c "$COMMITS" \
       --arg t "$(date -u +%FT%TZ)" '
      .issues[$n].status = "done"
      | .issues[$n].commit_sha = $s
      | .issues[$n].commits = $c
      | .issues[$n].completed_at = $t
      | .circuit_breaker.consecutive_failures = 0
    ' "$STATE_FILE" > "$TMP" && mv "$TMP" "$STATE_FILE"

    echo "done #$ISSUE — $COMMITS commit(s) on $BRANCH at $SHA"
    ;;

  blocked)
    cd "$REPO_ROOT"
    rtk git worktree remove --force "$WT_PATH" >/dev/null 2>&1 || rm -rf "$WT_PATH"
    rtk git branch -D "$BRANCH" >/dev/null 2>&1 || true

    TMP="$STATE_FILE.tmp.$$"
    jq --arg n "$ISSUE" \
       --arg r "${REASON:-no reason given}" \
       --arg t "$(date -u +%FT%TZ)" '
      .issues[$n].status = "blocked"
      | .issues[$n].error = $r
      | .issues[$n].completed_at = $t
      | .circuit_breaker.consecutive_failures += 1
    ' "$STATE_FILE" > "$TMP" && mv "$TMP" "$STATE_FILE"

    echo "blocked #$ISSUE — $REASON"
    ;;

  *)
    echo "invalid outcome '$OUTCOME' (expected ok|blocked)" >&2
    exit 1
    ;;
esac
