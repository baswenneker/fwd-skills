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

# make_stub <path> [fails] [label]: an executable at <path> that appends each
# argument to $LINT_LOG (one per line) and "<label> <args>" to $LINT_LOG.calls,
# and exits 1 on its first <fails> calls (default 0). <label> defaults to the
# file name.
make_stub() {
    local path="$1" fails="${2:-0}" label="${3:-$(basename "$1")}"
    mkdir -p "$(dirname "$path")"
    cat > "$path" <<EOF
#!/usr/bin/env bash
printf '%s\n' "\$@" >> "\$LINT_LOG"
echo "$label \$*" >> "\$LINT_LOG.calls"
count_file="\$LINT_LOG.$label.count"
n=\$(cat "\$count_file" 2>/dev/null || echo 0)
echo \$((n + 1)) > "\$count_file"
[ "\$n" -lt $fails ] && { echo "$label failed (call \$((n + 1)))"; exit 1; }
exit 0
EOF
    chmod +x "$path"
}

STUBS="$TMP/stubs"
for tool in ruff black pyright mypy flake8 shellcheck pre-commit npm npx tsc uv; do
    make_stub "$STUBS/$tool"
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

# called <log> <line>: a stub recorded exactly "<label> <args>"
called() { grep -qxF -- "$2" "$1.calls" 2>/dev/null; }

# not_called <log> <label>: no call of the stub labelled <label>
not_called() { ! grep -qE "^$2( |\$)" "$1.calls" 2>/dev/null; }

# call_count <log> <label>: number of calls of the stub labelled <label>
call_count() { grep -cE "^$2( |\$)" "$1.calls" 2>/dev/null; }

# calls <log>: the recorded calls on one line, for failure messages
calls() { tr '\n' '|' < "$1.calls" 2>/dev/null; }

# run_lint <dir> <log> <path> <smart-lint args...>: run smart-lint.sh in <dir>
# with PATH=<path> (empty: the current PATH). Output goes to <log>.out, the
# exit code to RC.
run_lint() {
    local dir="$1" log="$2" path="${3:-$PATH}"
    shift 3
    : > "$log"
    : > "$log.calls"
    (cd "$dir" && PATH="$path" LINT_LOG="$log" "$PAYLOAD/smart-lint.sh" "$@") > "$log.out" 2>&1
    RC=$?
}

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

# A monorepo package: the session's own folder holds its config, so the hook
# lints that folder's changes, with paths relative to it.
new_repo "$TMP/sub"
mkdir -p "$TMP/sub/pkg"
echo 'w = 1' > "$TMP/sub/pkg/m.py"
echo 'x = 3' > "$TMP/sub/a.py"
run_wrapper "$TMP/sub/pkg" "$TMP/sub.log"
if linted "$TMP/sub.log" m.py && ! grep -q 'a\.py' "$TMP/sub.log"; then
    pass "wrapper started in a subfolder lints that folder's changes, relative to it"
else
    fail "wrapper in a subfolder got: $(tr '\n' '|' < "$TMP/sub.log")"
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
# A second Stop entry without a hooks array must not break the update.
jq -n --arg cmd "$OLD_CMD" \
    '{hooks: {Stop: [{matcher: "x"}, {hooks: [{type: "command", command: $cmd, timeout: 180000}]}]}}' \
    > "$HOME/.claude/settings.json"
rm -f "$HOME/.claude/hooks/smart-lint.sh"
"$SMARTLINT_DIR/install.sh" --scope user > "$TMP/install.out" 2>&1
INSTALLED=$(jq '[.hooks.Stop[].hooks[]? | select(.command | test("smart-lint-wrapper"))]' "$HOME/.claude/settings.json")
if [[ "$(jq 'length' <<< "$INSTALLED")" == "1" && "$(jq '.[0].timeout' <<< "$INSTALLED")" == "180" ]] \
    && [[ -f "$HOME/.claude/hooks/smart-lint.sh" ]]; then
    pass "installer re-run sets an installed hook's timeout to 180 seconds and refreshes the payload"
else
    fail "installer re-run left: $INSTALLED; output: $(cat "$TMP/install.out")"
fi

# ── A. A pre-commit config hands lint and format to pre-commit ───────────────

# new_pc_repo <dir>: new_repo plus a pre-commit config, a.py changed and s.sh
new_pc_repo() {
    new_repo "$1"
    echo 'repos: []' > "$1/.pre-commit-config.yaml"
    echo 'x = 2' > "$1/a.py"
    echo 'echo hi' > "$1/s.sh"
}

new_pc_repo "$TMP/pcA"
run_lint "$TMP/pcA" "$TMP/pcA.log" "" --files a.py s.sh
if [[ $RC -eq 0 ]] && [[ "$(call_count "$TMP/pcA.log" pre-commit)" == "1" ]] \
    && called "$TMP/pcA.log" "pre-commit run --config .pre-commit-config.yaml --files a.py s.sh" \
    && not_called "$TMP/pcA.log" ruff && not_called "$TMP/pcA.log" black \
    && not_called "$TMP/pcA.log" shellcheck && called "$TMP/pcA.log" "pyright ."; then
    pass "a pre-commit config runs pre-commit on the changed files instead of own linters"
else
    fail "pre-commit mode (rc $RC) got: $(calls "$TMP/pcA.log")"
fi

# Config at the git root, session in a subfolder: pre-commit gets the root config.
mkdir -p "$TMP/pcA/pkg"
echo 'w = 1' > "$TMP/pcA/pkg/m.py"
run_lint "$TMP/pcA/pkg" "$TMP/pcAsub.log" "" --files m.py
if called "$TMP/pcAsub.log" "pre-commit run --config $(cd "$TMP/pcA" && pwd -P)/.pre-commit-config.yaml --files m.py" \
    || called "$TMP/pcAsub.log" "pre-commit run --config $TMP/pcA/.pre-commit-config.yaml --files m.py"; then
    pass "a pre-commit config at the git root is used from a subfolder"
else
    fail "pre-commit from a subfolder got: $(calls "$TMP/pcAsub.log")"
fi

# ── B. pre-commit gets a second run when the first one fails ─────────────────

new_pc_repo "$TMP/pcB1"
make_stub "$TMP/pcB1-bin/pre-commit" 1
run_lint "$TMP/pcB1" "$TMP/pcB1.log" "$TMP/pcB1-bin:$PATH" --files a.py
if [[ $RC -eq 0 ]] && [[ "$(call_count "$TMP/pcB1.log" pre-commit)" == "2" ]] \
    && grep -q "(auto-fixed)" "$TMP/pcB1.log.out"; then
    pass "pre-commit failing once (a fixer changed files) passes on the second run"
else
    fail "pre-commit failing once: rc $RC, calls $(calls "$TMP/pcB1.log")"
fi

new_pc_repo "$TMP/pcB2"
make_stub "$TMP/pcB2-bin/pre-commit" 2
run_lint "$TMP/pcB2" "$TMP/pcB2.log" "$TMP/pcB2-bin:$PATH" --files a.py
if [[ $RC -eq 2 ]] && [[ "$(call_count "$TMP/pcB2.log" pre-commit)" == "2" ]] \
    && grep -q "pre-commit hooks failed" "$TMP/pcB2.log.out" \
    && grep -q "pre-commit failed (call 2)" "$TMP/pcB2.log.out"; then
    pass "pre-commit failing twice is an error that shows the hook output"
else
    fail "pre-commit failing twice: rc $RC, calls $(calls "$TMP/pcB2.log")"
fi

# ── C. pre-commit config but no pre-commit: info line, no own linters ────────

# A PATH with the stubs except pre-commit, plus the system tools the script uses
NOPC="$TMP/nopc-bin"
mkdir -p "$NOPC"
for tool in "$STUBS"/*; do
    [[ "$(basename "$tool")" == pre-commit ]] || ln -s "$tool" "$NOPC/"
done
for cmd in bash env git find grep head cat date dirname basename tr sort mkdir rm sed cut; do
    p="$(command -v "$cmd")" && [[ -n "$p" ]] && ln -sf "$p" "$NOPC/$cmd"
done
new_pc_repo "$TMP/pcC"
run_lint "$TMP/pcC" "$TMP/pcC.log" "$NOPC" --files a.py s.sh
if [[ $RC -eq 0 ]] && grep -q "pre-commit not found" "$TMP/pcC.log.out" \
    && not_called "$TMP/pcC.log" ruff && not_called "$TMP/pcC.log" shellcheck \
    && called "$TMP/pcC.log" "pyright ."; then
    pass "missing pre-commit skips lint and format, keeps the typecheck"
else
    fail "missing pre-commit: rc $RC, calls $(calls "$TMP/pcC.log"), out $(tail -5 "$TMP/pcC.log.out")"
fi

# ── D. No pre-commit: ruff formats, not black ────────────────────────────────

new_repo "$TMP/pyD"
echo 'x = 2' > "$TMP/pyD/a.py"
run_lint "$TMP/pyD" "$TMP/pyD.log" "" --files a.py
if called "$TMP/pyD.log" "ruff format --check --quiet a.py" && not_called "$TMP/pyD.log" black \
    && called "$TMP/pyD.log" "ruff check --fix a.py"; then
    pass "without pre-commit, Python is formatted with ruff format, not black"
else
    fail "Python formatter got: $(calls "$TMP/pyD.log")"
fi

# ── F. A tool in .venv/bin wins over the global one ──────────────────────────

new_repo "$TMP/pyF"
echo 'x = 2' > "$TMP/pyF/a.py"
make_stub "$TMP/pyF/.venv/bin/ruff" 0 venv-ruff
run_lint "$TMP/pyF" "$TMP/pyF.log" "" --files a.py
if called "$TMP/pyF.log" "venv-ruff check --fix a.py" && not_called "$TMP/pyF.log" ruff; then
    pass "the project's .venv/bin/ruff is used instead of the global ruff"
else
    fail "tool resolution got: $(calls "$TMP/pyF.log")"
fi

# ── G. A tool in uv.lock runs through uv run --frozen ────────────────────────

new_repo "$TMP/pyG"
echo 'x = 2' > "$TMP/pyG/a.py"
printf '[[package]]\nname = "pyright"\nversion = "1.1.400"\n' > "$TMP/pyG/uv.lock"
run_lint "$TMP/pyG" "$TMP/pyG.log" "" --files a.py
if called "$TMP/pyG.log" "uv run --frozen pyright ." && not_called "$TMP/pyG.log" pyright; then
    pass "a tool listed in uv.lock runs through uv run --frozen"
else
    fail "uv resolution got: $(calls "$TMP/pyG.log")"
fi

# ── H. Python typecheck covers the whole project, only after a .py change ─────

new_repo "$TMP/pyH"
echo 'x = 2' > "$TMP/pyH/a.py"
echo 'echo hi' > "$TMP/pyH/s.sh"
run_lint "$TMP/pyH" "$TMP/pyH.log" "" --files a.py
run_lint "$TMP/pyH" "$TMP/pyHsh.log" "" --files s.sh
if called "$TMP/pyH.log" "pyright ." && ! called "$TMP/pyH.log" "pyright a.py" \
    && not_called "$TMP/pyHsh.log" pyright; then
    pass "Python typecheck runs on the whole project, only when a .py file changed"
else
    fail "Python typecheck got: $(calls "$TMP/pyH.log") / $(calls "$TMP/pyHsh.log")"
fi

# ── I-L. TypeScript typecheck ────────────────────────────────────────────────

# new_ts_repo <dir> <package.json>: git repo with tsconfig.json, a changed a.ts
new_ts_repo() {
    new_repo "$1"
    echo '{}' > "$1/tsconfig.json"
    echo "$2" > "$1/package.json"
    echo 'export const a = 1;' > "$1/a.ts"
    echo 'module.exports = 1;' > "$1/b.js"
}

new_ts_repo "$TMP/tsI" '{"scripts": {"typecheck": "tsc -b"}}'
run_lint "$TMP/tsI" "$TMP/tsI.log" "" --files a.ts
if called "$TMP/tsI.log" "npm run typecheck" && not_called "$TMP/tsI.log" tsc; then
    pass "TS typecheck runs the package.json typecheck script"
else
    fail "TS typecheck with script got: $(calls "$TMP/tsI.log")"
fi

new_ts_repo "$TMP/tsJ" '{}'
make_stub "$TMP/tsJ/node_modules/.bin/tsc" 0 local-tsc
run_lint "$TMP/tsJ" "$TMP/tsJ.log" "" --files a.ts
if called "$TMP/tsJ.log" "local-tsc --noEmit" && not_called "$TMP/tsJ.log" npx; then
    pass "TS typecheck uses node_modules/.bin/tsc without a script"
else
    fail "TS typecheck with local tsc got: $(calls "$TMP/tsJ.log")"
fi

new_ts_repo "$TMP/tsK" '{}'
run_lint "$TMP/tsK" "$TMP/tsK.log" "" --files a.ts
if called "$TMP/tsK.log" "npx --no-install tsc --noEmit"; then
    pass "TS typecheck falls back to npx --no-install tsc"
else
    fail "TS typecheck fallback got: $(calls "$TMP/tsK.log")"
fi

new_ts_repo "$TMP/tsL" '{"scripts": {"typecheck": "tsc -b"}}'
run_lint "$TMP/tsL" "$TMP/tsLjs.log" "" --files b.js
export CLAUDE_HOOKS_TS_TYPECHECK_ENABLED=false
run_lint "$TMP/tsL" "$TMP/tsLoff.log" "" --files a.ts
unset CLAUDE_HOOKS_TS_TYPECHECK_ENABLED
if not_called "$TMP/tsLjs.log" npm && not_called "$TMP/tsLjs.log" npx \
    && not_called "$TMP/tsLoff.log" npm && not_called "$TMP/tsLoff.log" npx; then
    pass "no TS typecheck for a .js-only change or with the switch off"
else
    fail "TS typecheck ran: $(calls "$TMP/tsLjs.log") / $(calls "$TMP/tsLoff.log")"
fi

# ── M. Without pre-commit, the project's own prettier is used ────────────────

new_ts_repo "$TMP/tsM" '{}'
echo '{}' > "$TMP/tsM/.prettierrc"
make_stub "$TMP/tsM/node_modules/.bin/prettier" 0 local-prettier
run_lint "$TMP/tsM" "$TMP/tsM.log" "" --files a.ts
if called "$TMP/tsM.log" "local-prettier --check a.ts"; then
    pass "the project's node_modules/.bin/prettier is used"
else
    fail "prettier resolution got: $(calls "$TMP/tsM.log")"
fi

# ── O. A change that only deletes a source file still runs the typecheck ────

new_ts_repo "$TMP/delO" '{"scripts": {"typecheck": "tsc -b"}}'
echo 'y = 1' > "$TMP/delO/b.py"
git_t -C "$TMP/delO" add -A
git_t -C "$TMP/delO" commit -q -m files
rm "$TMP/delO/a.ts" "$TMP/delO/b.py"
run_lint "$TMP/delO" "$TMP/delO.log" "" --files a.ts b.py
if called "$TMP/delO.log" "pyright ." && called "$TMP/delO.log" "npm run typecheck" \
    && not_called "$TMP/delO.log" ruff; then
    pass "deleting a .py or .ts file still type-checks the project, without per-file tools"
else
    fail "delete-only change got: $(calls "$TMP/delO.log")"
fi

# ── P. npx without a local TypeScript is an info line, not a type error ──────

new_ts_repo "$TMP/tsP" '{}'
make_stub "$TMP/tsP-bin/npx" 99
run_lint "$TMP/tsP" "$TMP/tsP.log" "$TMP/tsP-bin:$PATH" --files a.ts
if [[ $RC -eq 0 ]] && grep -q "tsc not found" "$TMP/tsP.log.out" \
    && ! called "$TMP/tsP.log" "npx --no-install tsc --noEmit"; then
    pass "no TypeScript install gives an info line instead of a type error"
else
    fail "npx without TypeScript: rc $RC, calls $(calls "$TMP/tsP.log")"
fi

# ── Q. Fail fast never skips the typecheck after a pre-commit failure ────────

# Python is checked before TypeScript, so the TS typecheck is the one a
# fail-fast break after the first language would skip.
new_pc_repo "$TMP/pcQ"
echo '{}' > "$TMP/pcQ/tsconfig.json"
echo '{"scripts": {"typecheck": "tsc -b"}}' > "$TMP/pcQ/package.json"
echo 'export const a = 1;' > "$TMP/pcQ/a.ts"
make_stub "$TMP/pcQ-bin/pre-commit" 2
export CLAUDE_HOOKS_FAIL_FAST=true
run_lint "$TMP/pcQ" "$TMP/pcQ.log" "$TMP/pcQ-bin:$PATH" --files a.py a.ts
unset CLAUDE_HOOKS_FAIL_FAST
if [[ $RC -eq 2 ]] && called "$TMP/pcQ.log" "pyright ." \
    && called "$TMP/pcQ.log" "npm run typecheck"; then
    pass "fail fast still type-checks after pre-commit fails"
else
    fail "fail fast after pre-commit: rc $RC, calls $(calls "$TMP/pcQ.log")"
fi

# ── N. The repo's own hook copy matches the payload ──────────────────────────

REPO_ROOT="$(cd "$SMARTLINT_DIR/../../../../.." && pwd)"
if cmp -s "$PAYLOAD/smart-lint.sh" "$REPO_ROOT/.claude/hooks/smart-lint.sh" \
    && cmp -s "$PAYLOAD/smart-lint-wrapper.sh" "$REPO_ROOT/.claude/hooks/smart-lint-wrapper.sh"; then
    pass ".claude/hooks/ holds the same smart-lint scripts as the payload"
else
    fail ".claude/hooks/ differs from the payload: copy the payload over"
fi

echo
if [[ $FAILS -gt 0 ]]; then
    echo "$FAILS check(s) failed" >&2
    exit 1
fi
echo "all checks passed"
