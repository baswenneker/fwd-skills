#!/usr/bin/env bash
# smart-lint-test.sh - Behaviour tests for the smartlint Stop-hook payload.
#
# Usage:
#   smart-lint-test.sh
#
# Builds throwaway git repos in a temp dir, puts stub linters on PATH that
# record the arguments they receive (one per line), and runs the wrapper the
# way the Stop hook does. Exit 0 when every check passes, 1 otherwise.

set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SMARTLINT_DIR="$(cd "$HERE/.." && pwd)"
PAYLOAD="$SMARTLINT_DIR/payload"

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
FAILS=0

pass() { echo "ok   - $*"; }
fail() { echo "FAIL - $*" >&2; FAILS=$((FAILS + 1)); }

# ── Stub linters ──────────────────────────────────────────────────────────────

STUBS="$TMP/stubs"
mkdir -p "$STUBS"
for tool in ruff black pyright mypy flake8 shellcheck; do
    printf '#!/usr/bin/env bash\nprintf "%%s\\n" "$@" >> "$LINT_LOG"\n' > "$STUBS/$tool"
    chmod +x "$STUBS/$tool"
done
export PATH="$STUBS:$PATH"

# ── Helpers ───────────────────────────────────────────────────────────────────

git_t() { git -c user.name=test -c user.email=test@example.com "$@"; }

# new_repo <dir>: git repo with one commit holding <dir>/a.py
new_repo() {
    git init -q "$1"
    echo 'x = 1' > "$1/a.py"
    git_t -C "$1" add a.py
    git_t -C "$1" commit -q -m init
}

# run_wrapper <cwd> <log>: run the wrapper as the Stop hook would, from <cwd>
run_wrapper() {
    : > "$2"
    (cd "$1" && LINT_LOG="$2" CLAUDE_PROJECT_DIR="$1" \
        "$PAYLOAD/smart-lint-wrapper.sh" <<< '{}') > "$2.out" 2>&1
}

# linted <log> <path>: the stub linters got <path> as one argument
linted() { grep -qxF -- "$2" "$1"; }

# ── 1. Runs in a git worktree ─────────────────────────────────────────────────

new_repo "$TMP/main"
git_t -C "$TMP/main" worktree add -q "$TMP/wt" 2>/dev/null
echo 'x = 2' > "$TMP/wt/a.py"
run_wrapper "$TMP/wt" "$TMP/wt.log"
if linted "$TMP/wt.log" a.py; then
    pass "wrapper lints a changed file in a git worktree"
else
    fail "wrapper did not lint a.py in a git worktree"
fi

# ── 2. File names with spaces stay one argument ───────────────────────────────

new_repo "$TMP/space"
mkdir -p "$TMP/space/docs"
echo 'y = 1' > "$TMP/space/docs/my notes.py"
echo 'z = 1' > "$TMP/space/b c.py"
git_t -C "$TMP/space" add "b c.py"
git_t -C "$TMP/space" commit -q -m "add b c"
echo 'z = 2' > "$TMP/space/b c.py"
run_wrapper "$TMP/space" "$TMP/space.log"
if linted "$TMP/space.log" "docs/my notes.py" && linted "$TMP/space.log" "b c.py" \
    && ! linted "$TMP/space.log" "docs/my" && ! linted "$TMP/space.log" "notes.py"; then
    pass "untracked and modified files with spaces are linted as one file each"
else
    fail "file names with spaces were split: $(tr '\n' '|' < "$TMP/space.log")"
fi

# ── 3. Session started in a subfolder ─────────────────────────────────────────

new_repo "$TMP/sub"
mkdir -p "$TMP/sub/pkg"
echo 'w = 1' > "$TMP/sub/pkg/m.py"
run_wrapper "$TMP/sub/pkg" "$TMP/sub.log"
if linted "$TMP/sub.log" pkg/m.py; then
    pass "wrapper started in a subfolder lints with repo-relative paths"
else
    fail "wrapper in a subfolder did not lint pkg/m.py: $(tr '\n' '|' < "$TMP/sub.log")"
fi

# ── 4. Outside a git repo: silent no-op ──────────────────────────────────────

mkdir -p "$TMP/nogit"
echo 'v = 1' > "$TMP/nogit/n.py"
if run_wrapper "$TMP/nogit" "$TMP/nogit.log" && [[ ! -s "$TMP/nogit.log" ]]; then
    pass "wrapper outside a git repo exits 0 without linting"
else
    fail "wrapper outside a git repo linted or failed"
fi

# ── 5. Whole-project mode (no --files) keeps found paths whole ───────────────

mkdir -p "$TMP/whole/node_modules"
echo 'echo hi' > "$TMP/whole/s p.sh"
echo 'echo hi' > "$TMP/whole/node_modules/dep.sh"
: > "$TMP/whole.log"
(cd "$TMP/whole" && LINT_LOG="$TMP/whole.log" "$PAYLOAD/smart-lint.sh") > "$TMP/whole.out" 2>&1
if linted "$TMP/whole.log" "./s p.sh" && ! grep -q "node_modules" "$TMP/whole.log"; then
    pass "whole-project mode lints found files with spaces and skips node_modules"
else
    fail "whole-project mode got: $(tr '\n' '|' < "$TMP/whole.log")"
fi

# ── 6. hooks.json timeout is in seconds ──────────────────────────────────────

TIMEOUT=$(jq '.hooks.Stop[0].hooks[0].timeout' "$PAYLOAD/hooks.json")
if [[ "$TIMEOUT" == "180" ]]; then
    pass "hooks.json timeout is 180 seconds"
else
    fail "hooks.json timeout is $TIMEOUT, want 180 (seconds)"
fi

# ── 7. Re-running the installer fixes an installed 50-hour timeout ───────────

export HOME="$TMP/home"
mkdir -p "$HOME/.claude"
OLD_CMD="test -f \"\$HOME/.claude/hooks/smart-lint-wrapper.sh\" || exit 0; \"\$HOME/.claude/hooks/smart-lint-wrapper.sh\""
jq -n --arg cmd "$OLD_CMD" \
    '{hooks: {Stop: [{hooks: [{type: "command", command: $cmd, timeout: 180000}]}]}}' \
    > "$HOME/.claude/settings.json"
"$SMARTLINT_DIR/install.sh" --scope user > "$TMP/install.out" 2>&1
INSTALLED=$(jq '[.hooks.Stop[].hooks[] | select(.command | test("smart-lint-wrapper"))]' "$HOME/.claude/settings.json")
if [[ "$(jq 'length' <<< "$INSTALLED")" == "1" && "$(jq '.[0].timeout' <<< "$INSTALLED")" == "180" ]]; then
    pass "installer re-run sets an installed hook's timeout to 180 seconds"
else
    fail "installer re-run left: $INSTALLED"
fi

echo
if [[ $FAILS -gt 0 ]]; then
    echo "$FAILS check(s) failed" >&2
    exit 1
fi
echo "all checks passed"
