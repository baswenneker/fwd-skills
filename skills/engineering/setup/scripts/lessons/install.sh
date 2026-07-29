#!/usr/bin/env bash
# install.sh - Install the lessons memory file + CLAUDE.md instructions.
#
# Usage:
#   install.sh --scope <user|project>
#
# Behavior:
#   user:    scaffolds ~/.claude/lessons/LESSONS.md (if missing) and injects
#            an instructions section into ~/.claude/CLAUDE.md.
#   project: scaffolds <project>/.claude/lessons/LESSONS.md (if missing) and
#            injects an instructions section into <project>/CLAUDE.md.
#
# Idempotent: re-running refreshes the section between sentinel markers without
# touching the user's actual lessons. If the start marker is present without
# the end marker (or markers are out of order), exits 2 and refuses to modify.

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
PAYLOAD_DIR="$SCRIPT_DIR/payload"

if [[ ! -d "$PAYLOAD_DIR" ]]; then
    echo "install: payload not found at $PAYLOAD_DIR" >&2
    exit 1
fi

if [[ "$SCOPE" == "user" ]]; then
    CLAUDE_DIR="$HOME/.claude"
    CLAUDE_MD="$CLAUDE_DIR/CLAUDE.md"
    LESSONS_DIR="$CLAUDE_DIR/lessons"
    LESSONS_PATH_LITERAL='$HOME/.claude/lessons/LESSONS.md'
else
    PROJECT_ROOT="${CLAUDE_PROJECT_DIR:-$(pwd)}"
    CLAUDE_DIR="$PROJECT_ROOT/.claude"
    CLAUDE_MD="$PROJECT_ROOT/CLAUDE.md"
    LESSONS_DIR="$CLAUDE_DIR/lessons"
    LESSONS_PATH_LITERAL='.claude/lessons/LESSONS.md'
fi

LESSONS_FILE="$LESSONS_DIR/LESSONS.md"
START_MARKER='<!-- fwd:lessons:start -->'
END_MARKER='<!-- fwd:lessons:end -->'

# ── Scaffold LESSONS.md (only if missing — keep real lessons untouched) ───────

mkdir -p "$LESSONS_DIR"
if [[ ! -f "$LESSONS_FILE" ]]; then
    cp "$PAYLOAD_DIR/LESSONS.md" "$LESSONS_FILE"
    echo "✔ LESSONS.md scaffolded → $LESSONS_FILE"
else
    echo "✔ LESSONS.md already present → $LESSONS_FILE (kept as-is)"
fi

# ── Inject instructions into CLAUDE.md ────────────────────────────────────────

SECTION=$(sed "s|__LESSONS_PATH__|$LESSONS_PATH_LITERAL|g" "$PAYLOAD_DIR/instructions.md")

if [[ -f "$CLAUDE_MD" ]] && grep -qF "$START_MARKER" "$CLAUDE_MD"; then
    if ! grep -qF "$END_MARKER" "$CLAUDE_MD"; then
        printf '⚠  Found start marker but no end marker in %s\n' "$CLAUDE_MD" >&2
        printf '   The lessons section is corrupt. Repair the markers (or delete\n' >&2
        printf '   the region between them) and re-run /fwd:setup.\n' >&2
        exit 2
    fi

    START_LINE=$(grep -nF "$START_MARKER" "$CLAUDE_MD" | head -1 | cut -d: -f1)
    END_LINE=$(grep -nF "$END_MARKER" "$CLAUDE_MD" | head -1 | cut -d: -f1)

    if [[ "$START_LINE" -ge "$END_LINE" ]]; then
        printf '⚠  Markers out of order in %s (start at line %s, end at line %s)\n' \
            "$CLAUDE_MD" "$START_LINE" "$END_LINE" >&2
        printf '   Repair manually and re-run /fwd:setup.\n' >&2
        exit 2
    fi

    {
        head -n "$START_LINE" "$CLAUDE_MD"
        printf '%s\n' "$SECTION"
        tail -n "+$END_LINE" "$CLAUDE_MD"
    } > "$CLAUDE_MD.tmp"
    mv "$CLAUDE_MD.tmp" "$CLAUDE_MD"
    echo "✔ Lessons section refreshed in $CLAUDE_MD"
else
    mkdir -p "$(dirname "$CLAUDE_MD")"
    {
        if [[ -f "$CLAUDE_MD" ]]; then
            cat "$CLAUDE_MD"
            if [[ -n "$(tail -c 1 "$CLAUDE_MD")" ]]; then
                printf '\n'
            fi
            printf '\n'
        fi
        printf '%s\n' "$START_MARKER"
        printf '%s\n' "$SECTION"
        printf '%s\n' "$END_MARKER"
    } > "$CLAUDE_MD.tmp"
    mv "$CLAUDE_MD.tmp" "$CLAUDE_MD"
    echo "✔ Lessons section added to $CLAUDE_MD"
fi
