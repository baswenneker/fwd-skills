#!/usr/bin/env bash
# Stop hook (asyncRewake) of the idle summary. After a finished turn it decides whether to
# wait; after the wait it wakes the session by exiting 2 with the summary prompt on stderr.
# Every early exit is 0 without output, so the hook stays silent where it does nothing.
set -uo pipefail
HERE="$(dirname "${BASH_SOURCE[0]}")"
source "$HERE/lib.sh"

# 50 minutes: 10 minutes before the 1-hour prompt cache expires. The hook timeout in
# hooks/hooks.json must stay above this.
WAIT="${FWD_IDLE_SUMMARY_WAIT:-3000}"

input="$(cat)"
field() { jq -r "$1 // empty" <<<"$input" 2>/dev/null; }

dir="$(field .cwd)"
dir="${dir:-$PWD}"
is_enabled "$dir" || exit 0

session="$(field .session_id)"
valid_session "$session" || exit 0
# Drop state of sessions untouched for 30 days; the transcript check below still sees an
# earlier wake.
find "$SESSIONS_DIR" -type f -mtime +30 -delete 2>/dev/null
# A new number first, so a hook still waiting from an earlier turn stands down, also when
# this turn starts no wait itself.
seq="$(bump_seq "$session")"

[[ -f "$SESSIONS_DIR/$session.done" ]] && exit 0

# Background tasks or scheduled tasks still running: the session is not settled yet.
busy="$(jq -r '((.background_tasks // []) | length) + ((.session_crons // []) | length)' <<<"$input" 2>/dev/null)"
[[ "$busy" == 0 ]] || exit 0

transcript="$(field .transcript_path)"
[[ -f "$transcript" ]] || exit 0

# One pass over the transcript: typed prompts, whether the session was woken after the last
# one, whether the first one is a factory job, and the cache TTL the last cache write used.
# A prompt counts when Claude Code marks it as human; transcripts without that marker count
# plain text that is not a tag (tool results, notifications and hook messages are arrays or
# start with "<").
verdict="$(jq -rs '
    def typed: .type == "user" and (.isMeta | not) and
        (if .origin then .origin.kind == "human"
         else (.message.content | type == "string" and (startswith("<") | not)) end);
    def text: .message.content | if type == "string" then . else ([.[]? | .text? // empty] | join("")) end;
    [.[] | select(typed)] as $p |
    # Woken after the last typed prompt: this quiet period had its summary, also when the
    # marker file was pruned.
    ([to_entries[] | select(.value | typed) | .key] | last // -1) as $lastp |
    ([to_entries[] | select(.key > $lastp and .value.type == "user" and
        ((.value.message.content | tostring) | contains("Idle summary. The user has been away")))] | length > 0) as $woken |
    # The first prompt, slash commands included: without an origin marker a command starts with "<".
    ([.[] | select(.type == "user" and (.isMeta | not) and ((.origin.kind // "human") == "human")
        and (.message.content | type == "string"))] | first) as $first |
    ([.[] | select(.type == "assistant") | .message.usage.cache_creation? // empty
        | select((.ephemeral_1h_input_tokens // 0) + (.ephemeral_5m_input_tokens // 0) > 0)]
        | last) as $c |
    if $woken then "done"
    elif ($p | length) < 3 then "few"
    elif ($first | text | startswith("/factory:job") or contains("<command-name>/factory:job</command-name>")) then "job"
    elif (($c.ephemeral_1h_input_tokens // 0) > 0) then "go"
    else "short-cache" end
' "$transcript" 2>/dev/null)"
[[ "$verdict" == go ]] || exit 0

sleep "$WAIT"

# Stand down when a turn or prompt came in meanwhile, or the idle summary was turned off.
[[ "$(read_seq "$session")" == "$seq" ]] || exit 0
is_enabled "$dir" || exit 0

touch "$SESSIONS_DIR/$session.done"
cat "$HERE/prompt.txt" >&2
exit 2
