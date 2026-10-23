#!/usr/bin/env bash
# baseline: runs the project's formatters and lint autofixes over the code the hooks
# check (tests included, notes left alone), commits only what they changed, lists
# what is left, and touches nothing when the tree has uncommitted changes or the
# config is not its own. Uses a stub npx, so it needs no network.
source "$(dirname "$0")/lib.sh"

# Stub npx: "UGLY" is a layout problem Prettier fixes, "FIXABLE" a lint error
# eslint --fix fixes, "UNFIXABLE" one it cannot.
stub="$WORK/stub"
mkdir -p "$stub"
cat > "$stub/npx" <<'EOF'
#!/usr/bin/env bash
[[ "$1" == --no-install ]] && shift
tool="$1"; shift
[[ -n "${NO_JS_TOOLS:-}" ]] && exit 1
[[ "$1" == --version ]] && { echo 3.0.0; exit 0; }
files=(); for a in "$@"; do [[ "$a" == -* ]] || files+=("$a"); done
rc=0
for f in "${files[@]}"; do
    case "$tool $*" in
        "prettier --write"*) sed -i.bak 's/UGLY/pretty/' "$f" && rm -f "$f.bak" ;;
        "prettier --list-different"*) grep -q UGLY "$f" && { echo "$f"; rc=1; } ;;
        "eslint --fix"*) sed -i.bak 's/= FIXABLE/= fixed/' "$f" && rm -f "$f.bak" ;;
        "eslint --quiet"*) grep -q UNFIXABLE "$f" && { echo "$f  1:1  error  UNFIXABLE"; rc=1; } ;;
    esac
done
exit $rc
EOF
chmod +x "$stub/npx"
export PATH="$stub:$PATH"

# set_up <name> → a repo with Prettier and ESLint, the config this skill writes
# (uncommitted, as right after the precommit installer), and code that needs fixing.
set_up() {
    local repo
    repo="$(make_repo "$1")"
    cd "$repo"
    echo '{"devDependencies": {"prettier": "^3", "eslint": "^9"}}' > package.json
    mkdir -p src tests
    echo 'const a = UGLY' > src/a.ts
    echo 'const b = FIXABLE' > tests/b.test.ts
    echo 'const c = UNFIXABLE' > tests/c.test.ts
    echo 'UGLY notes' > notes.md
    git add -A && git commit -q -m code
    printf '%s Re-running it never overwrites this file.\nrepos:\n  - repo: local\n    hooks:\n      - id: prettier\n      - id: eslint\n' \
        "# Written by /fwd:setup-review." > .pre-commit-config.yaml
    mkdir -p .claude/fwd && echo '{"review": true}' > .claude/fwd/plugin.json
}

# ── Fixes, commits the fixes alone, reports what is left ──────────────────────
set_up fix
head_before="$(git rev-parse HEAD)"
out="$(bash "$SCRIPTS/baseline/install.sh" --scope project)"; code=$?
assert_eq "$code" 0 "baseline exits 0"
assert_eq "$(git rev-parse HEAD~1)" "$head_before" "one new commit"
assert_eq "$(git log -1 --format=%s)" "style: apply the project's formatters and lint autofixes" "commit subject"
committed="$(git show --name-only --format= HEAD | sort | tr '\n' ' ')"
assert_eq "$committed" "src/a.ts tests/b.test.ts " "commit holds the fixed code and tests only"
assert_eq "$(cat notes.md)" "UGLY notes" "notes are not formatted"
assert_contains "$(git status --porcelain)" "?? .pre-commit-config.yaml" "setup files stay out of the commit"
assert_contains "$out" "✔ 2 files fixed" "stdout counts the fixed files"
assert_contains "$out" "→ $(git rev-parse --short HEAD)" "stdout names the commit"
assert_contains "$out" "!   eslint: tests/c.test.ts  1:1  error  UNFIXABLE" "leftover reported"
assert_not_contains "$out" "prettier:" "nothing left for Prettier"

# Re-run: nothing to fix, no new commit, the leftover still reported.
head_before="$(git rev-parse HEAD)"
out="$(bash "$SCRIPTS/baseline/install.sh" --scope project)"; code=$?
assert_eq "$code" 0 "re-run exits 0"
assert_eq "$(git rev-parse HEAD)" "$head_before" "re-run makes no commit"
assert_contains "$out" "↷ nothing to fix" "re-run says there was nothing to fix"
assert_contains "$out" "UNFIXABLE" "re-run still reports the leftover"

# ── Uncommitted changes: nothing touched ──────────────────────────────────────
set_up dirty
echo 'const d = 1' >> src/a.ts
before="$(snapshot "$PWD")"; head_before="$(git rev-parse HEAD)"
out="$(bash "$SCRIPTS/baseline/install.sh" --scope project)"; code=$?
assert_eq "$code" 0 "dirty tree exits 0"
assert_contains "$out" "↷ uncommitted changes" "dirty tree reported as skipped"
assert_eq "$(snapshot "$PWD")" "$before" "dirty tree: no file changed"
assert_eq "$(git rev-parse HEAD)" "$head_before" "dirty tree: no commit"

# Untracked files do not count as uncommitted changes.
set_up untracked
echo scratch > scratch.txt
out="$(bash "$SCRIPTS/baseline/install.sh" --scope project)"
assert_contains "$out" "✔ 2 files fixed" "untracked files do not block the fixes"

# ── A config the repo wrote itself: nothing touched ───────────────────────────
set_up foreign
printf 'repos: []\n' > .pre-commit-config.yaml
before="$(snapshot "$PWD")"
out="$(bash "$SCRIPTS/baseline/install.sh" --scope project)"; code=$?
assert_eq "$code" 0 "foreign config exits 0"
assert_contains "$out" "↷ .pre-commit-config.yaml was not written" "foreign config reported as skipped"
assert_eq "$(snapshot "$PWD")" "$before" "foreign config: no file changed"

# ── Tools not installed: a note, no commit ────────────────────────────────────
set_up notools
head_before="$(git rev-parse HEAD)"
out="$(NO_JS_TOOLS=1 bash "$SCRIPTS/baseline/install.sh" --scope project)"; code=$?
assert_eq "$code" 0 "missing tools exit 0"
assert_contains "$out" "(Prettier is not installed" "note for Prettier"
assert_contains "$out" "(ESLint is not installed" "note for ESLint"
assert_eq "$(git rev-parse HEAD)" "$head_before" "missing tools: no commit"

finish
