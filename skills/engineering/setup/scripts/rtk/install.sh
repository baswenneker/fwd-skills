#!/usr/bin/env bash
# install.sh - Install the RTK PreToolUse hook. RTK (Rust Token Killer) rewrites
# Bash commands such as `git status` to `rtk git status`, which filters their
# output before it reaches the context window.
#
# Usage:
#   install.sh --scope <user|project>
#
# Behavior:
#   user:    merges the hook into ${CLAUDE_CONFIG_DIR:-~/.claude}/settings.json.
#            fwd:setup calls it this way.
#   project: merges the hook into <project>/.claude/settings.local.json.
#
# Skips (exit 0, a `↷` line the fwd:setup report shows as skipped) when the
# `rtk` on PATH is not RTK — missing entirely, or the
# unrelated reachingforthejack/rtk, which has the same name. A hook pointing
# at a missing binary would fail on every Bash call.
#
# Idempotent: the exact hook already present → no change. Another PreToolUse
# command that calls `rtk hook` or an rtk rewrite script → exit 2, because a
# second one would rewrite every command twice.

set -euo pipefail

# ── Parse args ────────────────────────────────────────────────────────────────

SCOPE=""
while [[ $# -gt 0 ]]; do
    case "$1" in
        --scope)
            [[ $# -ge 2 ]] || { echo "install: --scope needs an argument" >&2; exit 64; }
            SCOPE="$2"
            shift 2
            ;;
        *)
            echo "install: unknown argument: $1" >&2
            exit 64
            ;;
    esac
done

if [[ "$SCOPE" != "user" && "$SCOPE" != "project" ]]; then
    echo "install: --scope must be 'user' or 'project'" >&2
    exit 64
fi

# ── Resolve paths ─────────────────────────────────────────────────────────────

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PAYLOAD_FILE="$SCRIPT_DIR/payload/hooks.json"
LIB_MERGE="$SCRIPT_DIR/../lib/merge-json.sh"

if [[ ! -f "$PAYLOAD_FILE" ]]; then
    echo "install: payload not found at $PAYLOAD_FILE" >&2
    exit 1
fi
if [[ ! -x "$LIB_MERGE" ]]; then
    echo "install: merge helper not found or not executable at $LIB_MERGE" >&2
    exit 1
fi

if [[ "$SCOPE" == "user" ]]; then
    SETTINGS_FILE="${CLAUDE_CONFIG_DIR:-$HOME/.claude}/settings.json"
else
    SETTINGS_FILE="${CLAUDE_PROJECT_DIR:-$(pwd)}/.claude/settings.local.json"
fi

EXPECTED_CMD="rtk hook claude"

# ── Is RTK installed? ─────────────────────────────────────────────────────────
#
# `rtk gain` exists only in RTK, not in the Rust Type Kit that shares the name.

if ! command -v rtk >/dev/null 2>&1; then
    echo "↷ rtk not installed → skipped (install RTK, then re-run /fwd:setup)"
    exit 0
fi
if ! rtk gain >/dev/null 2>&1; then
    echo "↷ the rtk on PATH is not RTK (no 'rtk gain') → skipped (install RTK, then re-run /fwd:setup)"
    exit 0
fi

# ── Detect existing hooks ─────────────────────────────────────────────────────

if [[ -f "$SETTINGS_FILE" ]] && command -v jq >/dev/null 2>&1; then
    EXACT_MATCH=$(jq --arg cmd "$EXPECTED_CMD" \
        '[.hooks.PreToolUse[]?.hooks[]?.command // empty] | any(. == $cmd)' \
        "$SETTINGS_FILE" 2>/dev/null || echo "false")

    if [[ "$EXACT_MATCH" == "true" ]]; then
        echo "✔ RTK hook already installed → $SETTINGS_FILE"
        exit 0
    fi

    OTHER_VARIANTS=$(jq -r \
        '[.hooks.PreToolUse[]?.hooks[]?.command // empty | select(test("rtk hook|rtk-rewrite"))] | .[]' \
        "$SETTINGS_FILE" 2>/dev/null || true)

    if [[ -n "$OTHER_VARIANTS" ]]; then
        printf '⚠  Another RTK hook was found in %s:\n' "$SETTINGS_FILE" >&2
        printf '%s\n' "$OTHER_VARIANTS" | sed 's/^/    /' >&2
        printf '   Skipping install to avoid rewriting every command twice.\n' >&2
        printf '   To use the bundled hook: remove that entry, then re-run /fwd:setup.\n' >&2
        exit 2
    fi
fi

# ── Merge ─────────────────────────────────────────────────────────────────────

bash "$LIB_MERGE" "$SETTINGS_FILE" "$(cat "$PAYLOAD_FILE")"
echo "✔ RTK hook merged → $SETTINGS_FILE"
