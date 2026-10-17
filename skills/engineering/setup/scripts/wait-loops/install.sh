#!/usr/bin/env bash
# install.sh - Install the wait-loops rule: every background loop that waits
# or polls runs under `timeout`, so it cannot outlive the work it watched and
# block Claude Code from exiting or restarting.
#
# Usage:
#   install.sh --scope <user|project> [--remove]
#
# Behavior:
#   user:    injects the rule into ${CLAUDE_CONFIG_DIR:-~/.claude}/CLAUDE.md.
#            fwd:setup calls it this way.
#   project: injects the rule into <project>/CLAUDE.md.
#   --remove deletes the marker-bracketed block. Not called by fwd:setup;
#            run by hand to undo.
#
# Idempotent: re-running refreshes the block between the sentinel markers in
# place. Corrupt markers or an unmanaged copy of the rule (its heading outside the markers) exit 2 and leave the
# file untouched. The block handling lives in ../lib/md-block.sh.

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
PAYLOAD="$SCRIPT_DIR/payload/rule.md"
LIB_BLOCK="$SCRIPT_DIR/../lib/md-block.sh"

if [[ "$SCOPE" == "user" ]]; then
    CLAUDE_MD="${CLAUDE_CONFIG_DIR:-$HOME/.claude}/CLAUDE.md"
else
    CLAUDE_MD="${CLAUDE_PROJECT_DIR:-$(pwd)}/CLAUDE.md"
fi

if [[ "$REMOVE" -eq 1 ]]; then
    exec bash "$LIB_BLOCK" remove "$CLAUDE_MD" wait-loops
fi
exec bash "$LIB_BLOCK" install "$CLAUDE_MD" wait-loops "$PAYLOAD" "$(head -1 "$PAYLOAD")"
