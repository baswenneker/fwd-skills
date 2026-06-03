#!/usr/bin/env bash
# Boot the mission app and wait until ready. Owned by the orchestrator (not the
# user-tester agent), so process lifecycle is deterministic. Best-effort, portable
# (no setsid — macOS-friendly).
# Args: <slug>
# Writes <wt>/.mission-boot.pid and <wt>/.mission-boot.log (untracked; teardown removes them).
# Stdout: "ready url=<url>" | "ready" | "no-boot" | "boot-timeout" | "boot-crashed"
# Exit:   0 ready | 1 timeout/crashed | 2 no boot command
set -uo pipefail

SLUG="${1:?usage: boot-app.sh <slug>}"
command -v jq >/dev/null 2>&1 || { echo "missing-jq" >&2; exit 2; }
GCD="$(rtk git rev-parse --path-format=absolute --git-common-dir 2>/dev/null || true)"
[[ -z "$GCD" ]] && { echo "not-a-repo" >&2; exit 2; }
REPO_ROOT="$(dirname "$GCD")"
WT_DIR="${FWD_MISSION_WORKTREE_DIR:-$REPO_ROOT/.trees}"
WT_PATH="$WT_DIR/mission/$SLUG"
STATE="$WT_PATH/.claude/missions/$SLUG/state.json"
[[ -f "$STATE" ]] || { echo "state.json missing: $STATE" >&2; exit 2; }

BOOT="$(jq -r '.user_testing.boot_command // empty' "$STATE")"
[[ -z "$BOOT" ]] && { echo "no-boot"; exit 2; }

PTYPE="$(jq -r '.user_testing.ready_probe.type // "sleep"' "$STATE")"
URL="$(jq -r '.user_testing.ready_probe.url // empty' "$STATE")"
EXPECT="$(jq -r '.user_testing.ready_probe.expect_status // 200' "$STATE")"
TIMEOUT="$(jq -r '.user_testing.ready_probe.timeout_sec // 60' "$STATE")"
PATTERN="$(jq -r '.user_testing.ready_probe.pattern // empty' "$STATE")"

PIDFILE="$WT_PATH/.mission-boot.pid"
LOG="$WT_PATH/.mission-boot.log"

# Tear down a stale boot if one is recorded.
if [[ -f "$PIDFILE" ]]; then
  OLD="$(cat "$PIDFILE" 2>/dev/null || true)"
  [[ -n "$OLD" ]] && { pkill -P "$OLD" 2>/dev/null || true; kill "$OLD" 2>/dev/null || true; }
  rm -f "$PIDFILE"
fi

# Launch in the background; survives this script exiting.
( cd "$WT_PATH" && nohup bash -c "$BOOT" >"$LOG" 2>&1 & echo $! ) > "$PIDFILE"
BOOT_PID="$(cat "$PIDFILE")"

interval=2; elapsed=0
while [[ "$elapsed" -lt "$TIMEOUT" ]]; do
  if ! kill -0 "$BOOT_PID" 2>/dev/null; then echo "boot-crashed"; exit 1; fi
  case "$PTYPE" in
    http)
      code="$(curl -s -o /dev/null -w '%{http_code}' "$URL" 2>/dev/null || echo 000)"
      [[ "$code" == "$EXPECT" ]] && { echo "ready url=$URL"; exit 0; }
      ;;
    log)
      [[ -n "$PATTERN" ]] && grep -q -- "$PATTERN" "$LOG" 2>/dev/null && { echo "ready"; exit 0; }
      ;;
    *)
      sleep $(( TIMEOUT < 5 ? TIMEOUT : 5 )); echo "ready"; exit 0
      ;;
  esac
  sleep "$interval"; elapsed=$(( elapsed + interval ))
done

kill "$BOOT_PID" 2>/dev/null || true
echo "boot-timeout"; exit 1
