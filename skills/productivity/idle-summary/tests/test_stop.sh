#!/usr/bin/env bash
# The Stop hook: when it waits, when it wakes the session, and what it writes.
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

repo="$(make_repo widget)"
t="$WORK/t.jsonl"
make_transcript "$t" 3

# Off: stops at once, wakes nothing.
export FWD_IDLE_SUMMARY_WAIT=5
run_stop "$(stop_input off-1 "$t" "$repo")"
assert_eq "$RC" "0" "off: exit 0"
assert_eq "$ERR" "" "off: no output"
((ELAPSED < 3)) || fail "off: waited ${ELAPSED}s"

toggle "$repo" on >/dev/null

# Every condition met: exit 2 after the wait, with the prompt from the spec on stderr.
export FWD_IDLE_SUMMARY_WAIT=2
run_stop "$(stop_input on-1 "$t" "$repo")"
assert_eq "$RC" "2" "on: exit 2"
((ELAPSED >= 2)) || fail "on: woke after ${ELAPSED}s, before the wait"
spec="$PLUGIN_ROOT/docs/specs/idle-summary.md"
expected="$(awk '/^````text$/ {on = 1; next} /^````$/ {on = 0} on' "$spec")"
[[ -n "$expected" ]] || fail "no prompt block found in $spec"
assert_eq "$ERR" "$expected" "stderr is the prompt from the spec"
assert_contains "$ERR" "**Aan zet:**" "prompt carries the Dutch labels"
assert_contains "$ERR" "**Next up:**" "prompt carries the English labels"
assert_contains "$ERR" "PR #431" "prompt carries the example"

# Conditions that start no wait: each run must end at once, with exit 0 and no output.
export FWD_IDLE_SUMMARY_WAIT=5
quick_skip() { # <label> <stop input>
    run_stop "$2"
    assert_eq "$RC" "0" "$1: exit 0"
    assert_eq "$ERR" "" "$1: no output"
    ((ELAPSED < 3)) || fail "$1: waited ${ELAPSED}s"
}

make_transcript "$WORK/two.jsonl" 2
quick_skip "two typed prompts" "$(stop_input c-two "$WORK/two.jsonl" "$repo")"

make_transcript "$WORK/5m.jsonl" 3 5m
quick_skip "5-minute cache" "$(stop_input c-5m "$WORK/5m.jsonl" "$repo")"

make_transcript "$WORK/job.jsonl" 3 1h \
    $'<command-message>factory:job</command-message>\n<command-name>/factory:job</command-name>\n<command-args>fwdos#42</command-args>'
quick_skip "factory job" "$(stop_input c-job "$WORK/job.jsonl" "$repo")"

make_transcript "$WORK/job-plain.jsonl" 3 1h "/factory:job fwdos#42"
quick_skip "factory job typed plain" "$(stop_input c-job2 "$WORK/job-plain.jsonl" "$repo")"

quick_skip "background task" "$(stop_input c-bg "$t" "$repo" '[{"id":"b1","status":"running"}]')"
quick_skip "scheduled task" "$(stop_input c-cron "$t" "$repo" '[]' '[{"id":"c1"}]')"

finish
