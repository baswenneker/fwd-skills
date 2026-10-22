#!/usr/bin/env bash
# With the real pre-commit: a commit with a fake AWS key is blocked, a clean commit
# passes, the push hook is installed, and core.hooksPath (husky) is a collision.
source "$(dirname "$0")/lib.sh"
need_precommit "real pre-commit hooks"

repo="$(make_repo real)"
cd "$repo"
bash "$SCRIPTS/precommit/install.sh" --scope project >/dev/null; code=$?
assert_eq "$code" 0 "install exits 0"
[[ -f .git/hooks/pre-commit ]] || fail "pre-commit hook installed"
[[ -f .git/hooks/pre-push ]] || fail "pre-push hook installed"

git add -A
git commit -q -m "add review setup" >/dev/null 2>&1 || fail "clean commit passes"

printf 'aws_access_key_id = %s\n' "$(fake_aws_key)" > creds.ini
git add creds.ini
out="$(git commit -m "add creds" 2>&1)"; code=$?
[[ $code -ne 0 ]] || fail "commit with a fake AWS key is blocked"
assert_contains "$out" "aws-access-token" "gitleaks names the AWS rule"
git reset -q HEAD creds.ini; rm -f creds.ini

# A real push runs the push hook, which calls ssh in the background and does not wait.
bare="$WORK/remote.git"
git init -q --bare "$bare"
git config "url.$bare.insteadOf" git@github.com:acme/widget.git
stub="$WORK/stub"
mkdir -p "$stub"
printf '#!/usr/bin/env bash\necho "$*" > %q\nsleep 5\n' "$WORK/ssh-args" > "$stub/ssh"
chmod +x "$stub/ssh"
start=$(date +%s)
PATH="$stub:$PATH" git push -q origin main >/dev/null 2>&1 || fail "push succeeds"
elapsed=$(( $(date +%s) - start ))
[[ $elapsed -le 3 ]] || fail "push took ${elapsed}s, should not wait for ssh"
for _ in 1 2 3 4 5 6 7 8 9 10; do [[ -s "$WORK/ssh-args" ]] && break; sleep 0.2; done
assert_contains "$(cat "$WORK/ssh-args" 2>/dev/null)" "workcenter reviewer --now acme/widget main" "push hook asked the reviewer"

repo="$(make_repo husky)"
cd "$repo"
git config core.hooksPath .husky
err="$(bash "$SCRIPTS/precommit/install.sh" --scope project 2>&1 >/dev/null)"; code=$?
assert_eq "$code" 2 "core.hooksPath is a collision"
assert_contains "$err" "core.hooksPath" "stderr names core.hooksPath"

finish
