#!/usr/bin/env bash
# Preflight checks for fwd:issue-fix.
# Single-line status on stdout. Non-zero exit halts the tick.
# Logs every non-ok exit to state.json's decisions[] so morning-review sees skipped ticks.
set -euo pipefail

REPO_ROOT="$(rtk git rev-parse --show-toplevel 2>/dev/null || true)"
if [[ -z "$REPO_ROOT" ]]; then
  echo "not-a-repo"
  exit 1
fi

STATE_DIR="$REPO_ROOT/.claude/issue-loop"
STATE_FILE="$STATE_DIR/state.json"
mkdir -p "$STATE_DIR"

if [[ ! -f "$STATE_FILE" ]]; then
  printf '%s\n' '{"version":1,"issues":{},"circuit_breaker":{"consecutive_failures":0},"decisions":[]}' > "$STATE_FILE"
fi

# Log a skip-tick decision to state.json. Best-effort: silent on failure
# (e.g. jq missing or state file unwritable — preflight may itself be exiting
# because of those conditions).
log_skip() {
  local reason="$1"
  command -v jq >/dev/null 2>&1 || return 0
  [[ -w "$STATE_FILE" ]] || return 0
  local tmp="$STATE_FILE.tmp.$$"
  jq --arg ts "$(date -u +%FT%TZ)" --arg r "$reason" '
    .decisions = ((.decisions // []) + [{timestamp: $ts, action: "skip-tick", reason: $r}])
  ' "$STATE_FILE" > "$tmp" 2>/dev/null && mv "$tmp" "$STATE_FILE" || rm -f "$tmp"
}

if ! command -v jq >/dev/null 2>&1; then
  echo "missing-jq — install jq (brew install jq)"
  exit 1
fi

if ! timeout 10s gh auth status >/dev/null 2>&1; then
  log_skip "gh-not-authenticated"
  echo "gh-not-authenticated — run: gh auth login"
  exit 1
fi

if [[ -n "$(rtk git status --porcelain | grep -vx 'ok' || true)" ]]; then
  log_skip "main-checkout-dirty"
  echo "main-checkout-dirty — stash or commit changes in the main checkout first"
  exit 1
fi

FAILS=$(jq -r '.circuit_breaker.consecutive_failures // 0' "$STATE_FILE")
if [[ "$FAILS" -ge 3 ]]; then
  log_skip "circuit-breaker-tripped"
  echo "circuit-breaker-tripped — $FAILS consecutive failures. Reset:"
  echo "  jq '.circuit_breaker.consecutive_failures=0' $STATE_FILE > /tmp/x && mv /tmp/x $STATE_FILE"
  exit 1
fi

# Stale lock recovery: in_progress > 60 min old becomes blocked
STALE_THRESHOLD_SEC=3600
NOW=$(date +%s)
STALE=$(jq -r --argjson now "$NOW" --argjson th "$STALE_THRESHOLD_SEC" '
  .issues
  | to_entries
  | map(select(.value.status == "in_progress" and (($now - (.value.started_at_epoch // 0)) > $th)))
  | (.[0].key // empty)
' "$STATE_FILE")

if [[ -n "$STALE" ]]; then
  TMP="$STATE_FILE.tmp.$$"
  jq --arg n "$STALE" --arg t "$(date -u +%FT%TZ)" '
    .issues[$n].status = "blocked"
    | .issues[$n].error = "stale lock — process killed mid-flight, auto-recovered"
    | .issues[$n].completed_at = $t
    | .circuit_breaker.consecutive_failures += 1
  ' "$STATE_FILE" > "$TMP" && mv "$TMP" "$STATE_FILE"
  echo "ok — recovered stale lock on issue #$STALE"
  exit 0
fi

echo "ok"
