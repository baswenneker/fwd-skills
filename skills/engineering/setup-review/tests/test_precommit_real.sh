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
# --check answers at once (not ready when check-fails exists); --now hangs.
cat > "$stub/ssh" <<EOF
#!/usr/bin/env bash
if [[ "\$*" == *"reviewer --check"* ]]; then
    [[ -f "$WORK/check-fails" ]] || exit 0
    echo "  gitleaks is not installed"
    exit 1
fi
echo "\$*" > "$WORK/ssh-args"
sleep 5
EOF
chmod +x "$stub/ssh"
start=$(date +%s)
PATH="$stub:$PATH" git push -q origin main >/dev/null 2>&1 || fail "push succeeds"
elapsed=$(( $(date +%s) - start ))
[[ $elapsed -le 3 ]] || fail "push took ${elapsed}s, should not wait for ssh"
for _ in 1 2 3 4 5 6 7 8 9 10; do [[ -s "$WORK/ssh-args" ]] && break; sleep 0.2; done
assert_contains "$(cat "$WORK/ssh-args" 2>/dev/null)" "workcenter reviewer --now acme/widget main" "push hook asked the reviewer"

# Through pre-commit itself: the warning of a reviewer that cannot run reaches
# the terminal, and the push still goes through.
touch "$WORK/check-fails"
echo more >> README.md && git commit -qam more
out="$(PATH="$stub:$PATH" git push origin main 2>&1)" || fail "push succeeds while the reviewer cannot run"
assert_contains "$out" "gitleaks is not installed" "pre-commit shows the reviewer's warning"

# A new worktree of a JS repo gets its node_modules from the post-checkout hook,
# which the worktree shares with the main checkout.
repo="$(make_repo js)"
cd "$repo"
echo '{"devDependencies": {"prettier": "^3"}}' > package.json
echo '{}' > package-lock.json
bash "$SCRIPTS/precommit/install.sh" --scope project >/dev/null; code=$?
assert_eq "$code" 0 "JS install exits 0"
[[ -f .git/hooks/post-checkout ]] || fail "post-checkout hook installed"
git add -A && git commit -q --no-verify -m "add review setup"
printf '#!/usr/bin/env bash\necho "npm $* in $PWD" >> "%s/npm-calls"\nmkdir node_modules\n' "$WORK" > "$stub/npm"
chmod +x "$stub/npm"
out="$(PATH="$stub:$PATH" git worktree add -q "$WORK/js-tree" -b feature 2>&1)" || fail "worktree add succeeds"
# macOS reports the temp dir as /private/var/..., so match the end of the path only.
[[ "$(cat "$WORK/npm-calls" 2>/dev/null)" == "npm ci in "*/js-tree ]] || fail "new worktree ran npm ci in the worktree"
assert_contains "$out" "fwd-worktree-deps" "worktree add shows what it installed"
: > "$WORK/npm-calls"
(cd "$WORK/js-tree" && PATH="$stub:$PATH" git switch -q main 2>/dev/null; PATH="$stub:$PATH" git switch -q feature)
assert_eq "$(cat "$WORK/npm-calls")" "" "a branch switch installs nothing"

repo="$(make_repo husky)"
cd "$repo"
git config core.hooksPath .husky
err="$(bash "$SCRIPTS/precommit/install.sh" --scope project 2>&1 >/dev/null)"; code=$?
assert_eq "$code" 2 "core.hooksPath is a collision"
assert_contains "$err" "core.hooksPath" "stderr names core.hooksPath"

finish
