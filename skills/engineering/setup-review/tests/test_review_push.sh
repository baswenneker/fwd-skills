#!/usr/bin/env bash
# The pre-push script asks the Workcenter reviewer for this repo and branch, detached:
# it returns at once even when ssh hangs, and a failing or missing ssh changes nothing.
source "$(dirname "$0")/lib.sh"

PUSH="$SCRIPTS/precommit/payload/review-push.sh"
repo="$(make_repo push)"
cd "$repo"

stub="$WORK/stub"
mkdir -p "$stub"
# --check answers at once with what check-rc says (0 by default); --now hangs.
cat > "$stub/ssh" <<EOF
#!/usr/bin/env bash
if [[ "\$*" == *"reviewer --check"* ]]; then
    echo "\$*" >> "$WORK/ssh-checks"
    [[ -f "$WORK/check-slow" ]] && sleep 30
    rc=\$(cat "$WORK/check-rc" 2>/dev/null || echo 0)
    [[ \$rc == 0 ]] || { echo "Not ready to review:"; echo "  gitleaks is not installed"; }
    exit \$rc
fi
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

# A reviewer that cannot run: the warning shows, no review is asked for.
git remote set-url origin git@github.com:acme/widget.git
rm -f "$WORK/ssh-args"
echo 1 > "$WORK/check-rc"
err="$(PATH="$stub:$PATH" bash "$PUSH" 2>&1 >/dev/null)"; code=$?
assert_eq "$code" 0 "not-ready reviewer still exits 0"
assert_contains "$err" "cannot review this push" "warning shows"
assert_contains "$err" "gitleaks is not installed" "warning says what is missing"
sleep 0.5
[[ ! -e "$WORK/ssh-args" ]] || fail "no --now when the reviewer cannot run"

# The Workcenter out of reach (ssh's own 255): silent.
echo 255 > "$WORK/check-rc"
err="$(PATH="$stub:$PATH" bash "$PUSH" 2>&1)"; code=$?
assert_eq "$code" 0 "unreachable exits 0"
assert_eq "$err" "" "unreachable says nothing"

# A check that hangs: given up after about 5 seconds, silently.
rm -f "$WORK/check-rc"
touch "$WORK/check-slow"
start=$(date +%s)
err="$(PATH="$stub:$PATH" bash "$PUSH" 2>&1)"; code=$?
elapsed=$(( $(date +%s) - start ))
rm -f "$WORK/check-slow"
assert_eq "$code" 0 "slow check exits 0"
[[ $elapsed -le 8 ]] || fail "slow check held the push for ${elapsed}s"
assert_eq "$err" "" "slow check says nothing"

# Failing ssh: still exit 0.
git remote set-url origin git@github.com:acme/widget.git
printf '#!/usr/bin/env bash\nexit 255\n' > "$stub/ssh"
PATH="$stub:$PATH" bash "$PUSH"; code=$?
assert_eq "$code" 0 "failing ssh still exits 0"

finish
