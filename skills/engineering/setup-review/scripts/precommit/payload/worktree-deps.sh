#!/usr/bin/env bash
# worktree-deps.sh - post-checkout hook, installed by /fwd:setup-review: install the
# JavaScript dependencies in a new worktree, so the Prettier and ESLint hooks find the
# project's own copies there. A new worktree is an empty directory: no node_modules.
#
# Runs only on a new checkout (`git worktree add`: the previous HEAD is the null sha),
# only when package.json exists and node_modules (or Yarn PnP's .pnp.cjs) does not.
# Installs from the lockfile and never writes one: no lockfile → a hint, no install.
# A missing package manager or a failed install is reported. Always exits 0: the
# checkout already happened, and a failing hook would not undo it.
#
# pre-commit sets PRE_COMMIT_FROM_REF and PRE_COMMIT_CHECKOUT_TYPE for post-checkout hooks.

[[ "${PRE_COMMIT_CHECKOUT_TYPE:-}" == 1 ]] || exit 0
[[ "${PRE_COMMIT_FROM_REF:-}" =~ ^0+$ ]] || exit 0
[[ -f package.json ]] || exit 0
[[ -d node_modules || -f .pnp.cjs ]] && exit 0

if [[ -f pnpm-lock.yaml ]]; then
    cmd=(pnpm install --frozen-lockfile)
elif [[ -f yarn.lock && -f .yarnrc.yml ]]; then
    cmd=(yarn install --immutable)
elif [[ -f yarn.lock ]]; then
    cmd=(yarn install --frozen-lockfile)
elif [[ -f package-lock.json || -f npm-shrinkwrap.json ]]; then
    cmd=(npm ci)
else
    echo "fwd-worktree-deps: no lockfile, so nothing installed; run npm install here before you commit."
    exit 0
fi

if ! command -v "${cmd[0]}" >/dev/null 2>&1; then
    echo "fwd-worktree-deps: ${cmd[0]} is not installed; install it and run ${cmd[*]} here before you commit."
    exit 0
fi

echo "fwd-worktree-deps: new worktree, running ${cmd[*]}"
"${cmd[@]}" </dev/null 2>&1 ||
    echo "fwd-worktree-deps: ${cmd[*]} failed; run it by hand here before you commit."
exit 0
