#!/usr/bin/env bash
# install.sh - Install the grilling rule: narrows Matt Pocock's `grilling`
# skill (grill-me / grill-with-docs) to ask only the real questions and list
# the rest as assumptions. Leaves that skill untouched so plugin updates keep
# arriving; the override lives in CLAUDE.md.
#
# Usage:
#   install.sh --scope <user|project> [--remove]
#
# Behavior:
#   user:    injects the rule into ${CLAUDE_CONFIG_DIR:-~/.claude}/CLAUDE.md.
#            fwd:setup calls it this way — the one feature it installs globally.
#   project: injects the rule into <project>/CLAUDE.md.
#   --remove deletes the marker-bracketed block (markers included) and the
#            blank separator line install added before it. Not called by
#            fwd:setup; run by hand to undo.
#
# Idempotent: re-running refreshes the block between the sentinel markers in
# place. Corrupt markers (one without the other, or out of order) exit 2 and
# leave the file unmodified — for both install and --remove.

set -euo pipefail

# ── Parse args ────────────────────────────────────────────────────────────────

SCOPE=""
REMOVE=0
while [[ $# -gt 0 ]]; do
    case "$1" in
        --scope)
            [[ $# -ge 2 ]] || { echo "install: --scope needs an argument" >&2; exit 64; }
            SCOPE="$2"
            shift 2
            ;;
        --remove)
            REMOVE=1
            shift
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
PAYLOAD="$SCRIPT_DIR/payload/rule.md"

if [[ ! -f "$PAYLOAD" ]]; then
    echo "install: payload not found at $PAYLOAD" >&2
    exit 1
fi

if [[ "$SCOPE" == "user" ]]; then
    CLAUDE_MD="${CLAUDE_CONFIG_DIR:-$HOME/.claude}/CLAUDE.md"
else
    CLAUDE_MD="${CLAUDE_PROJECT_DIR:-$(pwd)}/CLAUDE.md"
fi

START_MARKER='<!-- fwd:grilling:start -->'
END_MARKER='<!-- fwd:grilling:end -->'

# ── Validate markers ──────────────────────────────────────────────────────────

START_LINE=""
END_LINE=""
if [[ -f "$CLAUDE_MD" ]]; then
    START_LINE=$(grep -nF "$START_MARKER" "$CLAUDE_MD" | head -1 | cut -d: -f1 || true)
    END_LINE=$(grep -nF "$END_MARKER" "$CLAUDE_MD" | head -1 | cut -d: -f1 || true)
fi

if [[ -n "$START_LINE" && -z "$END_LINE" ]] || [[ -z "$START_LINE" && -n "$END_LINE" ]]; then
    printf '⚠  Found only one of the grilling markers in %s\n' "$CLAUDE_MD" >&2
    printf '   The grilling section is corrupt. Repair the markers (or delete\n' >&2
    printf '   the region between them) and re-run /fwd:setup.\n' >&2
    exit 2
fi

if [[ -n "$START_LINE" && "$START_LINE" -ge "$END_LINE" ]]; then
    printf '⚠  Grilling markers out of order in %s (start at line %s, end at line %s)\n' \
        "$CLAUDE_MD" "$START_LINE" "$END_LINE" >&2
    printf '   Repair manually and re-run /fwd:setup.\n' >&2
    exit 2
fi

# ── Remove ────────────────────────────────────────────────────────────────────

if [[ "$REMOVE" -eq 1 ]]; then
    if [[ -z "$START_LINE" ]]; then
        echo "✔ No grilling rule present → $CLAUDE_MD (nothing removed)"
        exit 0
    fi

    # Drop the blank separator line install wrote before the start marker.
    CUT_FROM="$START_LINE"
    if [[ "$START_LINE" -gt 1 ]] && [[ -z "$(sed -n "$((START_LINE - 1))p" "$CLAUDE_MD")" ]]; then
        CUT_FROM=$((START_LINE - 1))
    fi

    {
        if [[ "$CUT_FROM" -gt 1 ]]; then
            head -n "$((CUT_FROM - 1))" "$CLAUDE_MD"
        fi
        tail -n "+$((END_LINE + 1))" "$CLAUDE_MD"
    } > "$CLAUDE_MD.tmp"
    mv "$CLAUDE_MD.tmp" "$CLAUDE_MD"
    echo "✔ Grilling rule removed → $CLAUDE_MD"
    exit 0
fi

# ── Install / refresh ─────────────────────────────────────────────────────────

if [[ -n "$START_LINE" ]]; then
    {
        head -n "$START_LINE" "$CLAUDE_MD"
        cat "$PAYLOAD"
        tail -n "+$END_LINE" "$CLAUDE_MD"
    } > "$CLAUDE_MD.tmp"
    mv "$CLAUDE_MD.tmp" "$CLAUDE_MD"
    echo "✔ Grilling rule refreshed → $CLAUDE_MD"
else
    mkdir -p "$(dirname "$CLAUDE_MD")"
    {
        if [[ -f "$CLAUDE_MD" ]]; then
            cat "$CLAUDE_MD"
            if [[ -s "$CLAUDE_MD" && -n "$(tail -c 1 "$CLAUDE_MD")" ]]; then
                printf '\n'
            fi
            if [[ -s "$CLAUDE_MD" ]]; then
                printf '\n'
            fi
        fi
        printf '%s\n' "$START_MARKER"
        cat "$PAYLOAD"
        printf '%s\n' "$END_MARKER"
    } > "$CLAUDE_MD.tmp"
    mv "$CLAUDE_MD.tmp" "$CLAUDE_MD"
    echo "✔ Grilling rule added → $CLAUDE_MD"
fi
