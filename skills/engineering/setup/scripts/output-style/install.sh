#!/usr/bin/env bash
# install.sh - Install the fwd-skills output style (Dutch, short, and the
# next-steps block at the end of a finished turn) and make it the active one.
#
# Usage:
#   install.sh --scope <user|project> [--remove]
#
# Behavior:
#   Copies payload/fwd-skills-outputstyle.md to <config>/output-styles/ and sets
#   "outputStyle" in <config>/settings.json, where <config> is
#   ${CLAUDE_CONFIG_DIR:-~/.claude} (user) or <project>/.claude (project; the
#   setting then goes to settings.local.json).
#   Also removes the legacy fwd:next-steps block from CLAUDE.md: the style
#   carries that rule now, so keeping both would state it twice.
#   --remove deletes the style file and unsets outputStyle when it is ours.
#
# Idempotent. An outputStyle that is not ours and not the old "mens-eerst" is a
# deliberate choice: the style file is still installed, the setting is left
# alone, and the script prints a note (exit 0).
#
# Exit codes: 0 done, 64 usage error, 1 I/O error or jq missing.

set -euo pipefail

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

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PAYLOAD="$SCRIPT_DIR/payload/fwd-skills-outputstyle.md"
LIB_BLOCK="$SCRIPT_DIR/../lib/md-block.sh"
NAME="fwd-skills-outputstyle"

if [[ "$SCOPE" == "user" ]]; then
    CONFIG_DIR="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
    CLAUDE_MD="$CONFIG_DIR/CLAUDE.md"
    SETTINGS="$CONFIG_DIR/settings.json"
else
    CONFIG_DIR="${CLAUDE_PROJECT_DIR:-$(pwd)}/.claude"
    CLAUDE_MD="${CLAUDE_PROJECT_DIR:-$(pwd)}/CLAUDE.md"
    SETTINGS="$CONFIG_DIR/settings.local.json"
fi
STYLE_FILE="$CONFIG_DIR/output-styles/$NAME.md"

command -v jq >/dev/null 2>&1 || { echo "install: jq is required to edit $SETTINGS" >&2; exit 1; }

current_style() {
    [[ -f "$SETTINGS" ]] && jq -r '.outputStyle // empty' "$SETTINGS" 2>/dev/null || true
}

write_settings() { # $1 = jq filter
    local tmp
    [[ -f "$SETTINGS" ]] || { mkdir -p "$(dirname "$SETTINGS")"; echo '{}' > "$SETTINGS"; }
    tmp="$(mktemp)"
    jq "$1" "$SETTINGS" > "$tmp" && mv "$tmp" "$SETTINGS"
}

if [[ "$REMOVE" -eq 1 ]]; then
    rm -f "$STYLE_FILE"
    [[ "$(current_style)" == "$NAME" ]] && write_settings 'del(.outputStyle)'
    echo "✔ output style removed → $STYLE_FILE"
    exit 0
fi

mkdir -p "$(dirname "$STYLE_FILE")"
cp "$PAYLOAD" "$STYLE_FILE"

# Legacy: the next-steps rule used to live in CLAUDE.md as its own block.
[[ -f "$CLAUDE_MD" ]] && bash "$LIB_BLOCK" remove "$CLAUDE_MD" next-steps

CURRENT="$(current_style)"
if [[ -z "$CURRENT" || "$CURRENT" == "mens-eerst" || "$CURRENT" == "$NAME" ]]; then
    write_settings ".outputStyle = \"$NAME\""
    echo "✔ output style $NAME active → $STYLE_FILE"
else
    echo "✔ output style installed, not activated (outputStyle is \"$CURRENT\"; set it to \"$NAME\" to use it) → $STYLE_FILE"
fi
