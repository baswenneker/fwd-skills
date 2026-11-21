#!/usr/bin/env bash
# /fwd:idle-summary on, off and without argument; the choice holds per repository.
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

repo="$(make_repo widget)"
git -C "$repo" worktree add -q "$WORK/widget-wt" -b wt
other="$(make_repo other)"

assert_contains "$(toggle "$repo")" "Idle summary: off" "default is off"

toggle "$repo" on >/dev/null
assert_contains "$(toggle "$repo")" "Idle summary: on" "on sticks"
assert_contains "$(toggle "$WORK/widget-wt")" "Idle summary: on" "a worktree of the same repo shares the choice"
assert_contains "$(toggle "$other")" "Idle summary: off" "another repo keeps its own choice"
assert_eq "$(git -C "$repo" status --porcelain)" "" "the choice is not stored in the repo"

toggle "$repo" on >/dev/null
assert_eq "$(grep -c . "$CLAUDE_PLUGIN_DATA/idle-summary/enabled")" "1" "on twice stores one line"

toggle "$WORK/widget-wt" off >/dev/null
assert_contains "$(toggle "$repo")" "Idle summary: off" "off from the worktree turns it off for the repo"

plain="$WORK/plain"
mkdir -p "$plain"
toggle "$plain" on >/dev/null
assert_contains "$(toggle "$plain")" "Idle summary: on" "outside git the choice holds for the folder"

toggle "$repo" bogus >/dev/null 2>&1
assert_eq "$?" "1" "an unknown argument fails"

if out="$(cd "$repo" && env -u CLAUDE_PLUGIN_DATA bash "$SCRIPTS/toggle.sh" on 2>&1)"; then
    fail "without CLAUDE_PLUGIN_DATA toggle must fail"
fi
assert_contains "$out" "CLAUDE_PLUGIN_DATA" "without CLAUDE_PLUGIN_DATA toggle says why"

finish
