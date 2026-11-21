#!/usr/bin/env bash
# UserPromptSubmit hook of the idle summary: a prompt from the user cancels a waiting Stop
# hook (new turn number) and opens a new quiet period (clears the summary marker).
set -uo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

input="$(cat)"
field() { jq -r "$1 // empty" <<<"$input" 2>/dev/null; }

dir="$(field .cwd)"
is_enabled "${dir:-$PWD}" || exit 0
session="$(field .session_id)"
valid_session "$session" || exit 0
# A task notification is not user input.
[[ "$(field .prompt)" == "<task-notification>"* ]] && exit 0

bump_seq "$session" >/dev/null
rm -f "$SESSIONS_DIR/$session.done"
exit 0
