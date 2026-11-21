#!/usr/bin/env bash
# toggle.sh [on|off] → turns the idle summary on or off for the repo of the current folder,
# then prints the choice. Without an argument it only prints it.
set -uo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

key="$(repo_key "$PWD")"

case "${1:-}" in
    on)
        if ! is_enabled "$PWD"; then
            mkdir -p "$STATE_DIR"
            echo "$key" >>"$ENABLED_FILE"
        fi
        ;;
    off)
        if [[ -f "$ENABLED_FILE" ]]; then
            tmp="$(mktemp "$STATE_DIR/.enabled.XXXXXX")"
            grep -Fxv -- "$key" "$ENABLED_FILE" >"$tmp"
            mv -f "$tmp" "$ENABLED_FILE"
        fi
        ;;
    "") ;;
    *)
        echo "usage: /fwd:idle-summary [on|off]" >&2
        exit 1
        ;;
esac

if is_enabled "$PWD"; then state=on; else state=off; fi
echo "Idle summary: $state ($key)"
