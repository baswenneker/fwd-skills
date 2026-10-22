#!/usr/bin/env bash
# review-flag: sets "review": true in .claude/fwd/plugin.json, keeps other keys,
# changes nothing on a re-run and refuses an explicit false.
source "$(dirname "$0")/lib.sh"

repo="$(make_repo flag)"
cd "$repo"

out="$(bash "$SCRIPTS/review-flag/install.sh" --scope project)"; code=$?
assert_eq "$code" 0 "fresh install exits 0"
assert_eq "$(jq -r .review .claude/fwd/plugin.json)" true "review flag set"
assert_contains "$out" "→" "stdout names what changed"

before="$(sha256sum .claude/fwd/plugin.json)"
bash "$SCRIPTS/review-flag/install.sh" --scope project >/dev/null; code=$?
assert_eq "$code" 0 "re-run exits 0"
assert_eq "$(sha256sum .claude/fwd/plugin.json)" "$before" "re-run leaves the file unchanged"

echo '{"smart-lint": false}' > .claude/fwd/plugin.json
bash "$SCRIPTS/review-flag/install.sh" --scope project >/dev/null; code=$?
assert_eq "$code" 0 "merge into existing file exits 0"
assert_eq "$(jq -c . .claude/fwd/plugin.json)" '{"smart-lint":false,"review":true}' "other keys kept"

echo '{"review": false}' > .claude/fwd/plugin.json
err="$(bash "$SCRIPTS/review-flag/install.sh" --scope project 2>&1 >/dev/null)"; code=$?
assert_eq "$code" 2 "explicit false is a collision"
assert_eq "$(jq -r .review .claude/fwd/plugin.json)" false "explicit false left alone"
assert_contains "$err" "false" "stderr explains the collision"

echo 'not json' > .claude/fwd/plugin.json
bash "$SCRIPTS/review-flag/install.sh" --scope project >/dev/null 2>&1; code=$?
assert_eq "$code" 2 "unreadable JSON is a collision"
assert_eq "$(cat .claude/fwd/plugin.json)" "not json" "unreadable JSON left alone"

bash "$SCRIPTS/review-flag/install.sh" --scope user >/dev/null 2>&1; code=$?
assert_eq "$code" 64 "user scope is refused"

finish
