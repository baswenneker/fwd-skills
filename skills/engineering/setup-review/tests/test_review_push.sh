#!/usr/bin/env bash
# The pre-push script asks the Workcenter reviewer for this repo and branch, detached:
# it returns at once even when ssh hangs, and a failing or missing ssh changes nothing.
source "$(dirname "$0")/lib.sh"

PUSH="$SCRIPTS/precommit/payload/review-push.sh"
repo="$(make_repo push)"
cd "$repo"

stub="$WORK/stub"
mkdir -p "$stub"
cat > "$stub/ssh" <<EOF
#!/usr/bin/env bash
echo "\$*" > "$WORK/ssh-args"
sleep 5
EOF
chmod +x "$stub/ssh"

start=$(date +%s)
PATH="$stub:$PATH" PRE_COMMIT_REMOTE_NAME=origin PRE_COMMIT_REMOTE_BRANCH=refs/heads/feature/x bash "$PUSH"; code=$?
elapsed=$(( $(date +%s) - start ))
assert_eq "$code" 0 "exits 0"
[[ $elapsed -le 2 ]] || fail "returned after ${elapsed}s, should not wait for ssh"
for _ in 1 2 3 4 5 6 7 8 9 10; do [[ -s "$WORK/ssh-args" ]] && break; sleep 0.2; done
args="$(cat "$WORK/ssh-args" 2>/dev/null)"
assert_contains "$args" "-o BatchMode=yes" "ssh never prompts"
assert_contains "$args" "workcenter reviewer --now acme/widget feature/x" "ssh gets repo and branch"

# https remote, branch from HEAD when pre-commit gives none.
git remote set-url origin https://github.com/acme/gadget.git
rm -f "$WORK/ssh-args"
PATH="$stub:$PATH" bash "$PUSH"; code=$?
assert_eq "$code" 0 "https remote exits 0"
for _ in 1 2 3 4 5 6 7 8 9 10; do [[ -s "$WORK/ssh-args" ]] && break; sleep 0.2; done
assert_contains "$(cat "$WORK/ssh-args" 2>/dev/null)" "--now acme/gadget main" "https remote parsed, branch from HEAD"

# Tags and non-GitHub remotes are not reviewed.
rm -f "$WORK/ssh-args"
PATH="$stub:$PATH" PRE_COMMIT_REMOTE_BRANCH=refs/tags/v1 bash "$PUSH"; code=$?
assert_eq "$code" 0 "tag push exits 0"
git remote set-url origin git@gitlab.com:acme/widget.git
PATH="$stub:$PATH" bash "$PUSH"; code=$?
assert_eq "$code" 0 "gitlab remote exits 0"
sleep 0.5
[[ ! -e "$WORK/ssh-args" ]] || fail "ssh called for a tag or a non-GitHub remote"

# Failing ssh: still exit 0.
git remote set-url origin git@github.com:acme/widget.git
printf '#!/usr/bin/env bash\nexit 255\n' > "$stub/ssh"
PATH="$stub:$PATH" bash "$PUSH"; code=$?
assert_eq "$code" 0 "failing ssh still exits 0"

finish
