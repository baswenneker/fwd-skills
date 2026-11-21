#!/usr/bin/env bash
# Shared state for the idle-summary hooks and toggle. Source it.
#
# Plain git, not rtk: these scripts run on other machines where rtk may be missing, and
# their git output never reaches Claude.
#
# State lives outside the repo, under $XDG_STATE_HOME/fwd-idle-summary:
#   enabled              one repo key per line (repo has idle summary on)
#   sessions/<id>.seq    turn counter of a session; a waiting hook with an old number stops
#   sessions/<id>.done   this quiet period already got its summary

STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/fwd-idle-summary"
ENABLED_FILE="$STATE_DIR/enabled"
SESSIONS_DIR="$STATE_DIR/sessions"

# repo_key <dir> → the repo's shared .git dir (same for all its worktrees); outside git the
# folder itself.
repo_key() {
    git -C "$1" rev-parse --path-format=absolute --git-common-dir 2>/dev/null ||
        (cd "$1" 2>/dev/null && pwd -P) ||
        printf '%s\n' "$1"
}

is_enabled() {
    [[ -f "$ENABLED_FILE" ]] && grep -Fxq -- "$(repo_key "$1")" "$ENABLED_FILE"
}

# valid_session <id> → true when the id is safe to use as a file name.
valid_session() { [[ "$1" =~ ^[A-Za-z0-9_-]+$ ]]; }

read_seq() { cat "$SESSIONS_DIR/$1.seq" 2>/dev/null || echo 0; }

# bump_seq <id> → prints the new turn number.
bump_seq() {
    local next tmp
    next=$(($(read_seq "$1") + 1))
    mkdir -p "$SESSIONS_DIR"
    tmp="$(mktemp "$SESSIONS_DIR/.seq.XXXXXX")"
    echo "$next" >"$tmp" && mv -f "$tmp" "$SESSIONS_DIR/$1.seq"
    echo "$next"
}
