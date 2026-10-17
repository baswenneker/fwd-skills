#!/usr/bin/env bash
# install.sh - Disable Claude Code's default commit/PR attribution.
#
# Usage:
#   install.sh --scope <user|project>
#
# Behavior:
#   user:    sets `attribution.commit = ""`, `attribution.pr = ""` and
#            `attribution.sessionUrl = false` in ~/.claude/settings.json
#   project: same in <project>/.claude/settings.local.json
#
# sessionUrl false keeps the link to the Claude session out of commits and PRs.
#
# Idempotent. If all three fields already hold those values, we skip silently.
# If commit or pr holds a non-empty string, or sessionUrl is explicitly true,
# we exit 2 — the user chose that attribution and we don't overwrite it.

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

# ── Detect existing values ────────────────────────────────────────────────────
#
# Three possible states per field:
#   missing  → field not present (or `.attribution` not an object)
#   ""       → already empty (matches desired state)
#   "<str>"  → user-set custom attribution → collision
#
# `tojson` quotes strings, so "" comes back as the literal three-char string
# '""'. That lets us cleanly distinguish "empty" from "missing" without using
# jq's `//` operator (which would conflate explicit "" with absent).

read_field() {
    local key="$1"
    if [[ -f "$SETTINGS_FILE" ]] && command -v jq >/dev/null 2>&1; then
        jq -r --arg k "$key" '
            if (.attribution? | type) == "object" and (.attribution | has($k))
            then .attribution[$k] | tojson
            else "missing"
            end
        ' "$SETTINGS_FILE" 2>/dev/null || echo "missing"
    else
        echo "missing"
    fi
}

CURRENT_COMMIT=$(read_field "commit")
CURRENT_PR=$(read_field "pr")
CURRENT_SESSION_URL=$(read_field "sessionUrl")

collision=0
for value in "$CURRENT_COMMIT" "$CURRENT_PR"; do
    case "$value" in
        '""'|missing) ;;
        *)            collision=1 ;;
    esac
done
case "$CURRENT_SESSION_URL" in
    false|missing) ;;
    *)             collision=1 ;;
esac

if (( collision )); then
    printf '⚠  attribution holds a custom value in %s\n' "$SETTINGS_FILE" >&2
    printf '   attribution.commit     = %s\n   attribution.pr         = %s\n   attribution.sessionUrl = %s\n' \
        "$CURRENT_COMMIT" "$CURRENT_PR" "$CURRENT_SESSION_URL" >&2
    printf '   Refusing to overwrite a custom attribution.\n' >&2
    printf '   To disable: set `attribution.commit` and `attribution.pr` to "" and\n' >&2
    printf '   `attribution.sessionUrl` to false\n' >&2
    printf '   in %s, then re-run /fwd:setup.\n' "$SETTINGS_FILE" >&2
    exit 2
fi

if [[ "$CURRENT_COMMIT" == '""' && "$CURRENT_PR" == '""' && "$CURRENT_SESSION_URL" == false ]]; then
    echo "✔ Attribution already off (commit, pr, sessionUrl) → $SETTINGS_FILE, no change"
    exit 0
fi

# ── Merge ─────────────────────────────────────────────────────────────────────

SNIPPET=$(cat "$PAYLOAD_FILE")
bash "$LIB_MERGE" "$SETTINGS_FILE" "$SNIPPET"
echo "✔ Attribution off (commit, pr, sessionUrl) → $SETTINGS_FILE"
