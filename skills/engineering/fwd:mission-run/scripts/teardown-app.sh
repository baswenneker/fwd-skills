#!/usr/bin/env bash
# Tear down the app booted by boot-app.sh. Best-effort; always safe to call.
# Args: <slug>
set -uo pipefail

SLUG="${1:?usage: teardown-app.sh <slug>}"
REPO_ROOT="$(rtk git rev-parse --show-toplevel 2>/dev/null || true)"
[[ -z "$REPO_ROOT" ]] && { echo "not-a-repo" >&2; exit 0; }
WT_DIR="${FWD_MISSION_WORKTREE_DIR:-$REPO_ROOT/.trees}"
WT_PATH="$WT_DIR/mission/$SLUG"
PIDFILE="$WT_PATH/.mission-boot.pid"
LOG="$WT_PATH/.mission-boot.log"

if [[ -f "$PIDFILE" ]]; then
  PID="$(cat "$PIDFILE" 2>/dev/null || true)"
  if [[ -n "$PID" ]]; then
    pkill -P "$PID" 2>/dev/null || true   # children first (e.g. node under npm)
    kill "$PID" 2>/dev/null || true
  fi
  rm -f "$PIDFILE"
fi
rm -f "$LOG"
echo "torn-down"
