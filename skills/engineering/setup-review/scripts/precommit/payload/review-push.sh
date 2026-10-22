#!/usr/bin/env bash
# review-push.sh - pre-push hook, installed by /fwd:setup-review: ask the Workcenter
# reviewer to look at the pushed branch now, instead of at its next 10-minute tick.
#
# First asks `reviewer --check`, waiting at most 5 seconds: a reviewer that cannot
# run (a scanner missing, gh logged out) says so here, in the terminal of whoever
# pushes. Then runs the review request detached and returns: the push never waits
# for the review. No SSH access to the Workcenter, no ssh, a check slower than 5
# seconds, a tag push or a remote that is not GitHub → nothing happens, silently
# (the Workcenter timer picks the PR up anyway). Always exits 0.
#
# pre-commit sets PRE_COMMIT_REMOTE_NAME and PRE_COMMIT_REMOTE_BRANCH for pre-push hooks.

remote="${PRE_COMMIT_REMOTE_NAME:-origin}"
ref="${PRE_COMMIT_REMOTE_BRANCH:-}"

case "$ref" in
    refs/heads/*) branch="${ref#refs/heads/}" ;;
    "") branch="$(git symbolic-ref --quiet --short HEAD 2>/dev/null)" ;;
    *) exit 0 ;;
esac
# ssh hands its arguments to the remote shell as one string, so a branch named
# `x;rm -rf ~` would run there. Git allows such names; this hook does not pass them on.
[[ "$branch" =~ ^[A-Za-z0-9_./-]+$ ]] || exit 0

# The configured URL, not the one git pushes to: an insteadOf rewrite should not
# hide which GitHub repo this is.
url="$(git config --get "remote.$remote.url" 2>/dev/null)"
url="${url%/}"
url="${url%.git}"
case "$url" in
    git@github.com:*) repo="${url#git@github.com:}" ;;
    ssh://git@github.com/*) repo="${url#ssh://git@github.com/}" ;;
    https://github.com/*) repo="${url#https://github.com/}" ;;
    *) exit 0 ;;
esac
[[ "$repo" =~ ^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$ ]] || exit 0

command -v ssh >/dev/null 2>&1 || exit 0

# The check, waited for by hand: macOS has no `timeout`. 255 is ssh's own failure
# (no route, no key): the Workcenter is out of reach, which is not news.
out="$(mktemp)"
ssh -o BatchMode=yes -o ConnectTimeout=3 workcenter reviewer --check </dev/null >"$out" 2>&1 &
pid=$!
for _ in 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20 21 22 23 24 25; do
    kill -0 "$pid" 2>/dev/null || break
    sleep 0.2
done
if kill -0 "$pid" 2>/dev/null; then
    kill "$pid" 2>/dev/null
    wait "$pid" 2>/dev/null
    rm -f "$out"
    exit 0
fi
wait "$pid"
rc=$?
if [[ $rc != 0 ]]; then
    if [[ $rc != 255 ]]; then
        {
            echo "fwd-review: the Workcenter reviewer cannot review this push:"
            sed 's/^/  /' "$out"
            echo "  The PR gets no review until that is fixed; it is reviewed then."
        } >&2
    fi
    rm -f "$out"
    exit 0
fi
rm -f "$out"

# All three streams away from the hook: pre-commit waits for its pipes to close, so a
# child that kept them would make the push wait for ssh after all.
nohup ssh -o BatchMode=yes -o ConnectTimeout=10 workcenter reviewer --now "$repo" "$branch" \
    </dev/null >/dev/null 2>&1 &

exit 0
