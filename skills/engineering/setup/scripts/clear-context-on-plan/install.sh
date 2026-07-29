#!/usr/bin/env bash
# install.sh - Enable Claude Code's "Clear context?" prompt on plan accept.
#
# Usage:
#   install.sh --scope <user|project>
#
# Behavior:
#   user:    sets `showClearContextOnPlanAccept: true` in ~/.claude/settings.json
#   project: sets it in <project>/.claude/settings.local.json
#
# Idempotent. If the setting is already `true` we skip silently. If it's
# explicitly `false`, we exit 2 — the user made a deliberate choice and we
# don't overwrite it; they need to remove the line and re-run /fwd:setup.

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
PAYLOAD_FILE="$SCRIPT_DIR/payload/snippet.json"
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
    SETTINGS_FILE="$HOME/.claude/settings.json"
else
    PROJECT_ROOT="${CLAUDE_PROJECT_DIR:-$(pwd)}"
    SETTINGS_FILE="$PROJECT_ROOT/.claude/settings.local.json"
fi

# ── Detect existing value ─────────────────────────────────────────────────────

CURRENT="missing"
if [[ -f "$SETTINGS_FILE" ]] && command -v jq >/dev/null 2>&1; then
    # `tojson` produces "true"/"false"/"null"; `has()` distinguishes missing
    # from explicit-null, and avoids jq's `//` operator (which would treat
    # an explicit `false` as "fallback to default").
    CURRENT=$(jq -r '
        if has("showClearContextOnPlanAccept")
        then .showClearContextOnPlanAccept | tojson
        else "missing"
        end
    ' "$SETTINGS_FILE" 2>/dev/null || echo "missing")
fi

case "$CURRENT" in
    true)
        echo "✔ showClearContextOnPlanAccept already true in $SETTINGS_FILE — no change"
        exit 0
        ;;
    false)
        printf '⚠  showClearContextOnPlanAccept is explicitly set to false in %s\n' "$SETTINGS_FILE" >&2
        printf '   Refusing to overwrite an explicit user choice.\n' >&2
        printf '   To enable: remove the `showClearContextOnPlanAccept` line from\n' >&2
        printf '   %s and re-run /fwd:setup.\n' "$SETTINGS_FILE" >&2
        exit 2
        ;;
esac

# ── Merge ─────────────────────────────────────────────────────────────────────

SNIPPET=$(cat "$PAYLOAD_FILE")
bash "$LIB_MERGE" "$SETTINGS_FILE" "$SNIPPET"
echo "✔ showClearContextOnPlanAccept → true in $SETTINGS_FILE"
