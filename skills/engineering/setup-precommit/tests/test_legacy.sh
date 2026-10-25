#!/usr/bin/env bash
# legacy: removes what /fwd:setup-review left (its workflows, the push script and
# "review" in .claude/fwd/plugin.json), and only that.
source "$(dirname "$0")/lib.sh"

OLD="# Written by /fwd:setup-review. Re-running it never overwrites this file."

repo="$(make_repo legacy)"
cd "$repo"
mkdir -p .github/workflows .claude/fwd
printf '%s\nname: fwd-review\n' "$OLD" > .github/workflows/fwd-review.yml
printf '%s\nname: fwd-osv-weekly\n' "$OLD" > .github/workflows/fwd-osv-weekly.yml
echo 'name: ci' > .github/workflows/ci.yml
printf '#!/usr/bin/env bash\n# review-push.sh - pre-push hook, installed by /fwd:setup-review: ask\n' > .claude/fwd/review-push.sh
echo '{"review": true, "smart-lint": false}' > .claude/fwd/plugin.json
out="$(bash "$SCRIPTS/legacy/install.sh" --scope project)"; code=$?
assert_eq "$code" 0 "legacy exits 0"
[[ ! -e .github/workflows/fwd-review.yml ]] || fail "fwd-review.yml removed"
[[ ! -e .github/workflows/fwd-osv-weekly.yml ]] || fail "fwd-osv-weekly.yml removed"
[[ -f .github/workflows/ci.yml ]] || fail "the repo's own workflow kept"
[[ ! -e .claude/fwd/review-push.sh ]] || fail "push script removed"
assert_eq "$(jq -c . .claude/fwd/plugin.json)" '{"smart-lint":false}' "review key removed, other keys kept"
assert_contains "$out" "removed" "stdout says what went"

before="$(snapshot "$repo")"
out="$(bash "$SCRIPTS/legacy/install.sh" --scope project)"
assert_eq "$(snapshot "$repo")" "$before" "re-run changes no file"
assert_contains "$out" "no change" "re-run says nothing changed"

# review as the only key: the file goes, and the empty directories with it.
repo="$(make_repo only)"
cd "$repo"
mkdir -p .claude/fwd .github/workflows
echo '{"review": true}' > .claude/fwd/plugin.json
printf '%s\n' "$OLD" > .github/workflows/fwd-review.yml
bash "$SCRIPTS/legacy/install.sh" --scope project >/dev/null
[[ ! -e .claude/fwd ]] || fail "empty .claude/fwd removed"
[[ ! -e .github ]] || fail "empty .github removed"

# A workflow with the same name that setup-review did not write stays.
repo="$(make_repo own)"
cd "$repo"
mkdir -p .github/workflows
echo 'name: my review' > .github/workflows/fwd-review.yml
bash "$SCRIPTS/legacy/install.sh" --scope project >/dev/null
[[ -f .github/workflows/fwd-review.yml ]] || fail "a fwd-review.yml the repo wrote stays"

finish
