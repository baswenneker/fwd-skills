#!/usr/bin/env bash
# Shared helpers for the fwd:idle-summary tests. Source this file; it sets SCRIPTS (the
# skill's scripts/ dir), points CLAUDE_PLUGIN_DATA at a throwaway dir and removes it on exit.
# shellcheck disable=SC2034  # PLUGIN_ROOT, RC, ERR and ELAPSED are read by the tests that source this.
set -uo pipefail

SCRIPTS="$(cd "$(dirname "${BASH_SOURCE[0]}")/../scripts" && pwd)"
PLUGIN_ROOT="$(cd "$SCRIPTS/../../../.." && pwd)"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
export CLAUDE_PLUGIN_DATA="$WORK/plugin-data"
export FWD_IDLE_SUMMARY_WAIT=1

FAILED=0

fail() {
    echo "FAIL: $*"
    FAILED=1
}

assert_eq() { [[ "$1" == "$2" ]] || fail "$3 (expected '$2', got '$1')"; }

assert_contains() { [[ "$1" == *"$2"* ]] || fail "$3 (no '$2' in: $1)"; }

# make_repo <name> → path of a fresh git repo with one commit.
make_repo() {
    local dir="$WORK/$1"
    mkdir -p "$dir"
    git -C "$dir" init -q -b main
    git -C "$dir" -c user.email=t@example.com -c user.name=t -c commit.gpgsign=false \
        commit -q --allow-empty -m init
    echo "$dir"
}

# typed_prompt <text> → one transcript line for a prompt the user typed.
typed_prompt() {
    jq -cn --arg t "$1" '{type: "user", origin: {kind: "human"}, message: {role: "user", content: $t}}'
}

# assistant_turn <1h|5m> → one transcript line for an answer that wrote the cache with that TTL.
assistant_turn() {
    local h=0 m=0
    if [[ "$1" == 1h ]]; then h=500; else m=500; fi
    jq -cn --argjson h "$h" --argjson m "$m" '{type: "assistant", message: {role: "assistant",
        content: [{type: "text", text: "ok"}], usage: {cache_read_input_tokens: 9000,
        cache_creation_input_tokens: ($h + $m),
        cache_creation: {ephemeral_1h_input_tokens: $h, ephemeral_5m_input_tokens: $m}}}}'
}

# make_transcript <file> <typed prompts> [cache 1h|5m] [first prompt]
# Writes a transcript with that many typed prompts, each followed by noise that must not
# count as a prompt: a tool result, a meta line, a task notification and a hook message.
make_transcript() {
    local file="$1" n="$2" cache="${3:-1h}" first="${4:-please build the thing}" i
    : >"$file"
    for ((i = 1; i <= n; i++)); do
        if ((i == 1)); then typed_prompt "$first"; else typed_prompt "prompt $i"; fi
        assistant_turn "$cache"
        jq -cn '{type: "user", message: {role: "user", content: [{type: "tool_result", tool_use_id: "x", content: "done"}]}}'
        jq -cn '{type: "user", isMeta: true, message: {role: "user", content: "<local-command-caveat>x</local-command-caveat>"}}'
        jq -cn '{type: "user", origin: {kind: "task-notification"}, message: {role: "user", content: "<task-notification>\n<task-id>b1</task-id>\n</task-notification>"}}'
        jq -cn '{type: "user", message: {role: "user", content: "<task-notification>\n<summary>Stop hook feedback</summary>\n</task-notification>"}}'
        assistant_turn "$cache"
    done >>"$file"
}

# stop_input <session> <transcript> <cwd> [background_tasks json] [session_crons json]
stop_input() {
    jq -cn --arg s "$1" --arg t "$2" --arg c "$3" --argjson b "${4:-[]}" --argjson k "${5:-[]}" \
        '{session_id: $s, transcript_path: $t, cwd: $c, hook_event_name: "Stop",
          stop_hook_active: false, background_tasks: $b, session_crons: $k}'
}

# prompt_input <session> <cwd> [prompt]
prompt_input() {
    jq -cn --arg s "$1" --arg c "$2" --arg p "${3:-next question}" \
        '{session_id: $s, cwd: $c, hook_event_name: "UserPromptSubmit", prompt: $p}'
}

# run_stop <input json> → sets RC, ERR and ELAPSED (whole seconds).
run_stop() {
    local start=$SECONDS
    bash "$SCRIPTS/stop.sh" <<<"$1" >/dev/null 2>"$WORK/stderr"
    RC=$?
    ERR="$(cat "$WORK/stderr")"
    ELAPSED=$((SECONDS - start))
}

run_prompt() { bash "$SCRIPTS/prompt.sh" <<<"$1" >/dev/null 2>&1; }

toggle() { (cd "$1" && bash "$SCRIPTS/toggle.sh" "${@:2}"); }

finish() { exit "$FAILED"; }
