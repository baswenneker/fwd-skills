#!/usr/bin/env bash
# A new turn or prompt cancels a waiting hook; one summary per quiet period.
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

repo="$(make_repo widget)"
t="$WORK/t.jsonl"
make_transcript "$t" 3
toggle "$repo" on >/dev/null

# wait_in_background <session> → starts a waiting hook; its exit code lands in $WORK/<session>.rc
wait_in_background() {
    (
        bash "$SCRIPTS/stop.sh" <<<"$(stop_input "$1" "$t" "$repo")" 2>"$WORK/$1.err"
        echo $? >"$WORK/$1.rc"
    ) &
}

# A turn ends during the wait: the first hook stands down silently.
export FWD_IDLE_SUMMARY_WAIT=3
wait_in_background s-turn
sleep 1
run_stop "$(stop_input s-turn "$t" "$repo")"
wait
assert_eq "$(cat "$WORK/s-turn.rc")" "0" "turn: waiting hook exits 0"
assert_eq "$(cat "$WORK/s-turn.err")" "" "turn: waiting hook writes nothing"
assert_eq "$RC" "2" "turn: the hook of the newest turn still wakes"

# The user types a prompt during the wait: the waiting hook stands down silently.
wait_in_background s-prompt
sleep 1
run_prompt "$(prompt_input s-prompt "$repo")"
wait
assert_eq "$(cat "$WORK/s-prompt.rc")" "0" "prompt: waiting hook exits 0"
assert_eq "$(cat "$WORK/s-prompt.err")" "" "prompt: waiting hook writes nothing"

# After a summary no new wait starts, also not after later turns without user input.
export FWD_IDLE_SUMMARY_WAIT=1
run_stop "$(stop_input s-once "$t" "$repo")"
assert_eq "$RC" "2" "once: first summary"
export FWD_IDLE_SUMMARY_WAIT=5
for turn in summary-turn message-from-another-session; do
    run_stop "$(stop_input s-once "$t" "$repo")"
    assert_eq "$RC" "0" "once: $turn starts no wait"
    assert_eq "$ERR" "" "once: $turn writes nothing"
    ((ELAPSED < 3)) || fail "once: $turn waited ${ELAPSED}s"
done

# A notification that arrives as a prompt does not count as user input.
run_prompt "$(prompt_input s-once "$repo" $'<task-notification>\n<task-id>b1</task-id>\n</task-notification>')"
run_stop "$(stop_input s-once "$t" "$repo")"
assert_eq "$RC" "0" "once: a task notification does not reset"

# A prompt from the user clears the marker: the next turn waits again.
export FWD_IDLE_SUMMARY_WAIT=1
run_prompt "$(prompt_input s-once "$repo")"
run_stop "$(stop_input s-once "$t" "$repo")"
assert_eq "$RC" "2" "once: after a user prompt a new summary comes"

finish
