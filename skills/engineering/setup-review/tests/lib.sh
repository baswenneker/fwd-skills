#!/usr/bin/env bash
# Shared helpers for the fwd:setup-review tests. Source this file; it sets SCRIPTS
# (the skill's scripts/ dir) and gives each test a throwaway repo under a temp dir
# that is removed on exit.
set -uo pipefail

SCRIPTS="$(cd "$(dirname "${BASH_SOURCE[0]}")/../scripts" && pwd)"
SETUP_SCRIPTS="$(cd "$SCRIPTS/../../setup/scripts" && pwd)"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

FAILED=0

fail() { echo "FAIL: $*"; FAILED=1; }

assert_eq() { [[ "$1" == "$2" ]] || fail "$3 (expected '$2', got '$1')"; }

assert_contains() { [[ "$1" == *"$2"* ]] || fail "$3 (no '$2' in: $1)"; }

assert_not_contains() { [[ "$1" != *"$2"* ]] || fail "$3 (unexpected '$2' in: $1)"; }

# make_repo <name> → path of a fresh git repo with one commit, origin pointing at GitHub.
make_repo() {
    local dir="$WORK/$1"
    mkdir -p "$dir"
    git -C "$dir" init -q -b main
    git -C "$dir" config user.email test@example.com
    git -C "$dir" config user.name test
    git -C "$dir" config commit.gpgsign false
    git -C "$dir" remote add origin git@github.com:acme/widget.git
    echo "# widget" > "$dir/README.md"
    git -C "$dir" add README.md
    git -C "$dir" commit -q -m init
    echo "$dir"
}

# sha256 <file>... → sha256sum on Linux, shasum on macOS (which has no sha256sum).
sha256() {
    if command -v sha256sum >/dev/null 2>&1; then sha256sum "$@"; else shasum -a 256 "$@"; fi
}

# snapshot <dir> → one line per file (path + sha256), .git internals except hooks left out.
snapshot() {
    (cd "$1" && find . -type f ! -path './.git/*' -o -type f -path './.git/hooks/*' | LC_ALL=C sort |
        while IFS= read -r f; do sha256 "$f"; done)
}

# fake_aws_key → an AWS access key id gitleaks treats as real (no EXAMPLE suffix).
fake_aws_key() {
    printf 'AKIA'
    LC_ALL=C tr -dc 'A-Z2-7' </dev/urandom | head -c 16
}

need_precommit() {
    if [[ -n "${FWD_TEST_OFFLINE:-}" ]] || ! command -v pre-commit >/dev/null 2>&1; then
        echo "SKIP: $1 (needs pre-commit and the network)"
        exit 0
    fi
}

finish() { exit "$FAILED"; }
