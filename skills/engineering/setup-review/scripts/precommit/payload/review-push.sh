#!/usr/bin/env bash
# review-push.sh - pre-push hook, installed by /fwd:setup-review: ask the Workcenter
# reviewer to look at the pushed branch now, instead of at its next 10-minute tick.
#
# Runs ssh detached and returns at once: the push never waits. No SSH access to the
# Workcenter, no ssh, a tag push or a remote that is not GitHub → nothing happens,
# silently (the Workcenter timer picks the PR up anyway). Always exits 0.
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

# All three streams away from the hook: pre-commit waits for its pipes to close, so a
# child that kept them would make the push wait for ssh after all.
nohup ssh -o BatchMode=yes -o ConnectTimeout=10 workcenter reviewer --now "$repo" "$branch" \
    </dev/null >/dev/null 2>&1 &

exit 0
