#!/usr/bin/env bash
# md-block.sh - Install, refresh or remove a marker-bracketed block in a
# markdown file (a CLAUDE.md, typically).
#
# Usage:
#   md-block.sh install <file> <feature> <payload-file> [<guard-line>]
#   md-block.sh remove  <file> <feature>
#
# The block is bracketed by `<!-- fwd:<feature>:start -->` and
# `<!-- fwd:<feature>:end -->`.
#
#   install  appends the block (after one blank separator line) when absent,
#            or replaces the region between the markers when present.
#   remove   deletes the block, markers included, plus the blank separator
#            line install wrote before it. No block → no change, exit 0.
#
# <guard-line> (optional): a line that marks an unmanaged copy of the same
# text, e.g. its heading. Found outside the markers → exit 2, because
# installing would put the text in the file twice.
#
# Exit codes: 0 done (or nothing to do), 2 corrupt markers or unmanaged copy
# (file left untouched), 64 usage error.

set -euo pipefail

ACTION="${1:-}"
FILE="${2:-}"
FEATURE="${3:-}"
PAYLOAD="${4:-}"
GUARD="${5:-}"

case "$ACTION" in
    install) [[ -n "$FILE" && -n "$FEATURE" && -f "$PAYLOAD" ]] || { echo "md-block: install needs <file> <feature> <payload-file>" >&2; exit 64; } ;;
    remove)  [[ -n "$FILE" && -n "$FEATURE" ]] || { echo "md-block: remove needs <file> <feature>" >&2; exit 64; } ;;
    *)       echo "md-block: action must be 'install' or 'remove'" >&2; exit 64 ;;
esac

START_MARKER="<!-- fwd:${FEATURE}:start -->"
END_MARKER="<!-- fwd:${FEATURE}:end -->"

# ── Validate markers ──────────────────────────────────────────────────────────

START_LINE=""
END_LINE=""
if [[ -f "$FILE" ]]; then
    START_LINE=$(grep -nF "$START_MARKER" "$FILE" | head -1 | cut -d: -f1 || true)
    END_LINE=$(grep -nF "$END_MARKER" "$FILE" | head -1 | cut -d: -f1 || true)
fi

if [[ -n "$START_LINE" && -z "$END_LINE" ]] || [[ -z "$START_LINE" && -n "$END_LINE" ]]; then
    printf '⚠  Found only one of the %s markers in %s\n' "$FEATURE" "$FILE" >&2
    printf '   The %s section is corrupt. Repair the markers (or delete\n' "$FEATURE" >&2
    printf '   the region between them) and re-run /fwd:setup.\n' >&2
    exit 2
fi

if [[ -n "$START_LINE" && "$START_LINE" -ge "$END_LINE" ]]; then
    printf '⚠  %s markers out of order in %s (start at line %s, end at line %s)\n' \
        "$FEATURE" "$FILE" "$START_LINE" "$END_LINE" >&2
    printf '   Repair manually and re-run /fwd:setup.\n' >&2
    exit 2
fi

# ── Remove ────────────────────────────────────────────────────────────────────

if [[ "$ACTION" == "remove" ]]; then
    if [[ -z "$START_LINE" ]]; then
        echo "✔ No ${FEATURE} block present → $FILE (nothing removed)"
        exit 0
    fi

    # Drop the blank separator line install wrote before the start marker.
    CUT_FROM="$START_LINE"
    if [[ "$START_LINE" -gt 1 ]] && [[ -z "$(sed -n "$((START_LINE - 1))p" "$FILE")" ]]; then
        CUT_FROM=$((START_LINE - 1))
    fi

    {
        if [[ "$CUT_FROM" -gt 1 ]]; then
            head -n "$((CUT_FROM - 1))" "$FILE"
        fi
        tail -n "+$((END_LINE + 1))" "$FILE"
    } > "$FILE.tmp"
    mv "$FILE.tmp" "$FILE"
    echo "✔ ${FEATURE} block removed → $FILE"
    exit 0
fi

# ── Guard against an unmanaged copy ───────────────────────────────────────────

if [[ -n "$GUARD" && -f "$FILE" ]]; then
    OUTSIDE=$(awk -v s="$START_MARKER" -v e="$END_MARKER" -v g="$GUARD" '
        $0 == s { inside = 1; next }
        $0 == e { inside = 0; next }
        !inside && $0 == g { print NR }
    ' "$FILE" | head -1)
    if [[ -n "$OUTSIDE" ]]; then
        printf '⚠  %s already holds an unmanaged copy of the %s text (line %s: "%s").\n' \
            "$FILE" "$FEATURE" "$OUTSIDE" "$GUARD" >&2
        printf '   Installing would add it twice. Delete that section by hand,\n' >&2
        printf '   then re-run /fwd:setup.\n' >&2
        exit 2
    fi
fi

# ── Install / refresh ─────────────────────────────────────────────────────────

if [[ -n "$START_LINE" ]]; then
    {
        head -n "$START_LINE" "$FILE"
        cat "$PAYLOAD"
        tail -n "+$END_LINE" "$FILE"
    } > "$FILE.tmp"
    mv "$FILE.tmp" "$FILE"
    echo "✔ ${FEATURE} block refreshed → $FILE"
else
    mkdir -p "$(dirname "$FILE")"
    {
        if [[ -s "$FILE" ]]; then
            cat "$FILE"
            if [[ -n "$(tail -c 1 "$FILE")" ]]; then
                printf '\n'
            fi
            printf '\n'
        fi
        printf '%s\n' "$START_MARKER"
        cat "$PAYLOAD"
        printf '%s\n' "$END_MARKER"
    } > "$FILE.tmp"
    mv "$FILE.tmp" "$FILE"
    echo "✔ ${FEATURE} block added → $FILE"
fi
