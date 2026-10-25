#!/usr/bin/env bash
# With the real pre-commit: all three hooks are installed, a clean commit passes, a
# message that is not a Conventional Commit and a fake AWS key are blocked, trailing
# whitespace is fixed, and core.hooksPath (husky) is a collision.
source "$(dirname "$0")/lib.sh"
need_precommit "real pre-commit hooks"

repo="$(make_repo real)"
cd "$repo"
bash "$SCRIPTS/precommit/install.sh" --scope project >/dev/null; code=$?
assert_eq "$code" 0 "install exits 0"
for h in pre-commit commit-msg pre-push; do
    [[ -f ".git/hooks/$h" ]] || fail "$h hook installed"
done

git add -A
git commit -q -m "chore: add hooks" >/dev/null 2>&1 || fail "clean commit with a Conventional message passes"

echo more >> README.md && git add README.md
out="$(git commit -m "more stuff" 2>&1)" && fail "a message that is not a Conventional Commit is blocked"
assert_contains "$out" "Conventional Commits" "the hook says why"
git commit -q -m "docs: more" >/dev/null 2>&1 || fail "same change with a Conventional message passes"

printf 'aws_access_key_id = %s\n' "$(fake_aws_key)" > creds.ini
git add creds.ini
out="$(git commit -m "feat: add creds" 2>&1)" && fail "commit with a fake AWS key is blocked"
assert_contains "$out" "aws-access-token" "gitleaks names the AWS rule"
git reset -q HEAD creds.ini; rm -f creds.ini

printf 'line   \n' > notes.txt
git add notes.txt
git commit -q -m "docs: notes" >/dev/null 2>&1 && fail "a file with trailing whitespace stops the commit"
assert_eq "$(cat notes.txt)" "line" "trailing whitespace removed"
git add notes.txt
git commit -q -m "docs: notes" >/dev/null 2>&1 || fail "the fixed file commits"

# A push runs only the push hooks: no fixer that could rewrite files mid-push.
printf 'f() {\n    echo hi\n}\n' > run.sh
git add run.sh && git commit -q -m "feat: script" >/dev/null 2>&1
bash "$SCRIPTS/precommit/install.sh" --scope project >/dev/null
git add -A && git commit -q -m "chore: shell hooks" >/dev/null 2>&1
remote="$WORK/remote.git"
git init -q --bare "$remote"
git remote set-url origin "$remote"
out="$(git push -q origin main 2>&1)" || fail "push without push hooks succeeds"
for name in "trim trailing whitespace" "fix end of files" "check for added large files" shfmt; do
    assert_not_contains "$out" "$name" "$name does not run on push"
done

repo="$(make_repo husky)"
cd "$repo"
git config core.hooksPath .husky
err="$(bash "$SCRIPTS/precommit/install.sh" --scope project 2>&1 >/dev/null)"; code=$?
assert_eq "$code" 2 "core.hooksPath is a collision"
assert_contains "$err" "core.hooksPath" "stderr names core.hooksPath"

finish
