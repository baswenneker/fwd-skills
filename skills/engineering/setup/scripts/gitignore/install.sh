#!/usr/bin/env bash
# install.sh - Append HeadingFWD runtime-artefact patterns to gitignore.
#
# Usage:
#   install.sh --scope <user|project>
#
# Behavior:
#   user:    appends/refreshes a marker-bracketed block in
#            $XDG_CONFIG_HOME/git/ignore (default ~/.config/git/ignore).
#            Creates the file and parent dirs if missing.
#   project: appends/refreshes the same block in <project>/.gitignore.
#            Creates the file if missing.
#
# Idempotent: re-running refreshes the body between sentinel markers in
# place. Exits 2 if markers are corrupt (start without end, or out of
# order).

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
PAYLOAD_FILE="$SCRIPT_DIR/payload/entries"

if [[ ! -f "$PAYLOAD_FILE" ]]; then
    echo "install: payload not found at $PAYLOAD_FILE" >&2
    exit 1
fi

if [[ "$SCOPE" == "user" ]]; then
    TARGET="${XDG_CONFIG_HOME:-$HOME/.config}/git/ignore"
    mkdir -p "$(dirname "$TARGET")"
else
    PROJECT_ROOT="${CLAUDE_PROJECT_DIR:-$(pwd)}"
    TARGET="$PROJECT_ROOT/.gitignore"
fi

START_MARKER='# fwd:setup:gitignore:start (managed by /fwd:setup — do not edit manually)'
END_MARKER='# fwd:setup:gitignore:end'

# Body is the payload content; markers wrap it on install.
BODY="$(cat "$PAYLOAD_FILE")"

# ── Install ───────────────────────────────────────────────────────────────────

touch "$TARGET"

if grep -qxF "$START_MARKER" "$TARGET"; then
    if ! grep -qxF "$END_MARKER" "$TARGET"; then
        printf '⚠  Found start marker but no end marker in %s\n' "$TARGET" >&2
        printf '   The gitignore section is corrupt. Repair the markers (or delete\n' >&2
        printf '   the region between them) and re-run /fwd:setup.\n' >&2
        exit 2
    fi

    START_LINE=$(grep -nxF "$START_MARKER" "$TARGET" | head -1 | cut -d: -f1)
    END_LINE=$(grep -nxF "$END_MARKER" "$TARGET" | head -1 | cut -d: -f1)

    if [[ "$START_LINE" -ge "$END_LINE" ]]; then
        printf '⚠  Markers out of order in %s (start at line %s, end at line %s)\n' \
            "$TARGET" "$START_LINE" "$END_LINE" >&2
        printf '   Repair manually and re-run /fwd:setup.\n' >&2
        exit 2
    fi

    {
        head -n "$START_LINE" "$TARGET"
        printf '%s\n' "$BODY"
        tail -n "+$END_LINE" "$TARGET"
    } > "$TARGET.tmp"
    mv "$TARGET.tmp" "$TARGET"
    echo "✔ gitignore section refreshed in $TARGET"
else
    {
        if [[ -s "$TARGET" ]]; then
            cat "$TARGET"
            if [[ -n "$(tail -c 1 "$TARGET")" ]]; then
                printf '\n'
            fi
            printf '\n'
        fi
        printf '%s\n' "$START_MARKER"
        printf '%s\n' "$BODY"
        printf '%s\n' "$END_MARKER"
    } > "$TARGET.tmp"
    mv "$TARGET.tmp" "$TARGET"
    echo "✔ gitignore section added to $TARGET"
fi
