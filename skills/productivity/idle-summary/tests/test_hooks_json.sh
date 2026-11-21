#!/usr/bin/env bash
# The plugin's hooks.json: both hooks registered, the Stop hook async with a timeout above
# the default wait.
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

hooks="$PLUGIN_ROOT/hooks/hooks.json"
default_wait="$(sed -n 's/.*FWD_IDLE_SUMMARY_WAIT:-\([0-9]*\)}.*/\1/p' "$SCRIPTS/stop.sh")"
assert_eq "$default_wait" "3000" "the default wait is 50 minutes"

stop="$(jq -c '.hooks.Stop[].hooks[] | select(.command | contains("idle-summary/scripts/stop.sh"))' "$hooks")"
[[ -n "$stop" ]] || fail "no idle-summary Stop hook in $hooks"
assert_eq "$(jq -r .asyncRewake <<<"$stop")" "true" "the Stop hook runs async and may wake the session"
timeout="$(jq -r '.timeout // 0' <<<"$stop")"
((timeout > default_wait)) || fail "Stop hook timeout $timeout is not above the wait $default_wait"

prompt="$(jq -c '.hooks.UserPromptSubmit[].hooks[] | select(.command | contains("idle-summary/scripts/prompt.sh"))' "$hooks")"
[[ -n "$prompt" ]] || fail "no idle-summary UserPromptSubmit hook in $hooks"

for f in stop.sh prompt.sh; do
    [[ -f "$SCRIPTS/$f" ]] || fail "$f missing"
done

finish
