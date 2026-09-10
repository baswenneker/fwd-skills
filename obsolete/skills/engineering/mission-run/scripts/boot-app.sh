#!/usr/bin/env bash
# Boot the mission app and wait until ready. Owned by the orchestrator (not the
# user-tester agent), so process lifecycle is deterministic. Best-effort, portable
# (no setsid — macOS-friendly).
# Args: <slug>  —  or:  --probe [<dir>]  (plan-time preflight, user_testing JSON on stdin;
#                        see the probe block below — adds "port-in-use" to the outputs)
# Writes <wt>/.mission-boot.pid and <wt>/.mission-boot.log (untracked; teardown removes them).
# Stdout: "ready url=<url>" | "ready" | "no-boot" | "boot-timeout" | "boot-crashed"
# Exit:   0 ready | 1 timeout/crashed | 2 no boot command
set -uo pipefail

# ── Probe mode (plan-time boot-preflight) ────────────────────────────────────
# fwd:mission-plan (stap 4.7) calls this BEFORE the worktree exists:
#   echo '<user_testing-json>' | boot-app.sh --probe [<dir>]
# Boots in <dir> (default: cwd, i.e. the main checkout), waits for the
# ready_probe, then tears itself down. No smoke_commands, no state.json;
# pid/log live in a throwaway tmpdir. Before booting it checks whether the
# probe URL already answers — that means another process (a sibling workspace)
# owns the port, and a later "ready" would prove the wrong app.
# Stdout: "ready url=<url>" | "ready" | "port-in-use" | "boot-timeout" | "boot-crashed" | "no-boot"
# Exit:   0 ready | 1 port-in-use/timeout/crashed | 2 no boot command / bad input
if [[ "${1:-}" == "--probe" ]]; then
  command -v jq >/dev/null 2>&1 || { echo "missing-jq" >&2; exit 2; }
  PROBE_DIR="${2:-$PWD}"
  [[ -d "$PROBE_DIR" ]] || { echo "no-such-dir: $PROBE_DIR" >&2; exit 2; }
  IN=""
  [[ ! -t 0 ]] && IN="$(cat)"
  jq -e . >/dev/null 2>&1 <<<"$IN" \
    || { echo "invalid user_testing JSON on stdin" >&2; exit 2; }

  BOOT="$(jq -r '.boot_command // empty' <<<"$IN")"
  [[ -z "$BOOT" ]] && { echo "no-boot"; exit 2; }
  PTYPE="$(jq -r '.ready_probe.type // "sleep"' <<<"$IN")"
  URL="$(jq -r '.ready_probe.url // empty' <<<"$IN")"
  EXPECT="$(jq -r '.ready_probe.expect_status // 200' <<<"$IN")"
  TIMEOUT="$(jq -r '.ready_probe.timeout_sec // 60' <<<"$IN")"
  PATTERN="$(jq -r '.ready_probe.pattern // empty' <<<"$IN")"

  TMPD="$(mktemp -d)"
  LOG="$TMPD/boot.log"
  PIDFILE="$TMPD/boot.pid"

  probe_teardown() {
    local pid
    pid="$(cat "$PIDFILE" 2>/dev/null || true)"
    [[ -n "$pid" ]] && { pkill -P "$pid" 2>/dev/null || true; kill "$pid" 2>/dev/null || true; }
    rm -rf "$TMPD"
  }
  trap probe_teardown EXIT

  # Squatter check: anything answering on the URL before we boot is not us.
  # Note: on a refused connection curl still prints "000" via -w AND exits
  # non-zero, so a trailing `|| echo 000` would double the string — capture
  # with `|| true` and treat only a real status code as occupied. Timeouts are
  # bounded: a listener that accepts TCP but never answers HTTP (dead tunnel,
  # paused server) must not hang the interactive plan session.
  if [[ "$PTYPE" == "http" && -n "$URL" ]]; then
    pre="$(curl -s -o /dev/null --connect-timeout 2 --max-time 5 -w '%{http_code}' "$URL" 2>/dev/null || true)"
    [[ -n "$pre" && "$pre" != "000" ]] && { echo "port-in-use"; exit 1; }
  fi

  ( cd "$PROBE_DIR" && nohup bash -c "$BOOT" >"$LOG" 2>&1 & echo $! ) > "$PIDFILE"
  BOOT_PID="$(cat "$PIDFILE")"

  interval=2; elapsed=0
  while [[ "$elapsed" -lt "$TIMEOUT" ]]; do
    if ! kill -0 "$BOOT_PID" 2>/dev/null; then echo "boot-crashed"; exit 1; fi
    case "$PTYPE" in
      http)
        # Bounded, unlike slug mode: a hung request may not stall the planner.
        code="$(curl -s -o /dev/null --connect-timeout 2 --max-time 5 -w '%{http_code}' "$URL" 2>/dev/null || true)"
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
  echo "boot-timeout"; exit 1
fi
# ── end probe mode ───────────────────────────────────────────────────────────

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
