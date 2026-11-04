#!/usr/bin/env bash
# shellcheck disable=SC2164 # make_repo just created the directory
# prettier: a JS/TS repo without Prettier gets .prettierrc.json, one formatting
# commit and a .git-blame-ignore-revs entry; a repo with Prettier, a dirty tree
# or a failing Prettier gets nothing. A stub stands in for Prettier, so no network.
source "$(dirname "$0")/lib.sh"

# Stub Prettier: adds a marker line to every file that lacks it, so a second
# pass changes nothing (fail on demand; STUB_SECOND adds a line on pass two,
# STUB_NEVER on every pass).
stub="$WORK/prettier-stub"
cat >"$stub" <<'EOF'
#!/usr/bin/env bash
[[ -n "${STUB_FAIL:-}" ]] && { echo "SyntaxError in broken.ts" >&2; exit 2; }
for a in "$@"; do
    [[ "$a" == -* || "$a" == warn ]] && continue
    [[ "$a" == *.json ]] && continue
    if ! grep -q "// formatted" "$a"; then echo "// formatted" >>"$a"
    elif [[ -n "${STUB_SECOND:-}" ]] && ! grep -q "// second" "$a"; then echo "// second" >>"$a"
    elif [[ -n "${STUB_NEVER:-}" ]]; then echo "// again" >>"$a"
    fi
done
EOF
chmod +x "$stub"
export FWD_PRETTIER_CMD="$stub"

install() { bash "$SCRIPTS/prettier/install.sh" --scope project; }

# ── A TS repo without Prettier gets the baseline ──────────────────────────────
repo="$(make_repo base)"
cd "$repo"
mkdir -p src
echo "import { a } from './a'" >src/b.ts
echo "export const a = 'x'" >src/a.ts
echo '{}' >package-lock.json
git add -A && git commit -q -m "feat: code"
start="$(git rev-parse HEAD)"
out="$(install 2>"$WORK/err")"; code=$?
assert_eq "$code" 0 "baseline exits 0"
assert_contains "$out" "✔ 2 files formatted" "stdout counts the formatted files"
assert_contains "$(cat "$WORK/err")" "merge conflicts" "stderr warns about older branches"
assert_eq "$(jq -c . .prettierrc.json)" '{"printWidth":120,"singleQuote":true}' "single quotes found, width 120"
assert_eq "$(git log --format=%s "$start"..HEAD | tr '\n' '|')" \
    "chore: skip the Prettier formatting commit in git blame|style: format with Prettier|" "two commits"
assert_eq "$(git status --porcelain)" "" "nothing left uncommitted"
fmt="$(git rev-parse HEAD~1)"
assert_contains "$(cat .git-blame-ignore-revs)" "$fmt" "blame skips the formatting commit"
assert_eq "$(git config blame.ignoreRevsFile)" ".git-blame-ignore-revs" "local blame reads the file"
assert_contains "$(cat src/a.ts)" "// formatted" "tracked code formatted"
assert_not_contains "$(cat package-lock.json)" "formatted" "lockfile left alone"

before="$(git rev-parse HEAD)"
out="$(install)"; code=$?
assert_eq "$code" 0 "re-run exits 0"
assert_contains "$out" "↷" "re-run skips: the config is there"
assert_eq "$(git rev-parse HEAD)" "$before" "re-run makes no commit"

# Double quotes stay double.
repo="$(make_repo double)"
cd "$repo"
echo 'import { a } from "./a"' >b.ts
git add -A && git commit -q -m "feat: code"
install >/dev/null 2>&1
assert_eq "$(jq .singleQuote .prettierrc.json)" "false" "double quotes found"

# ── Skips and refusals ────────────────────────────────────────────────────────
repo="$(make_repo noweb)"
cd "$repo"
out="$(install)"; code=$?
assert_eq "$code" 0 "no web files exits 0"
assert_contains "$out" "↷" "no web files skips"
[[ -f .prettierrc.json ]] && fail "no config without web files"

repo="$(make_repo pkg)"
cd "$repo"
echo '{"devDependencies": {"prettier": "^3"}}' >package.json
echo 'export const a = 1' >a.ts
git add -A && git commit -q -m "feat: code"
out="$(install)"
assert_contains "$out" "↷" "the project's own Prettier: skipped"
[[ -f .prettierrc.json ]] && fail "no config next to the project's Prettier"

repo="$(make_repo dirty)"
cd "$repo"
echo 'export const a = 1' >a.ts
git add -A && git commit -q -m "feat: code"
echo 'export const b = 2' >>a.ts
head_before="$(git rev-parse HEAD)"
err="$(install 2>&1 >/dev/null)"; code=$?
assert_eq "$code" 2 "uncommitted changes are a collision"
assert_contains "$err" "uncommitted" "stderr names the uncommitted changes"
assert_eq "$(git rev-parse HEAD)" "$head_before" "no commit on a dirty tree"
[[ -f .prettierrc.json ]] && fail "no config on a dirty tree"

repo="$(make_repo broken)"
cd "$repo"
echo 'export const a = 1' >a.ts
git add -A && git commit -q -m "feat: code"
err="$(STUB_FAIL=1 install 2>&1 >/dev/null)"; code=$?
assert_eq "$code" 2 "Prettier failure is a collision"
assert_contains "$err" "broken.ts" "stderr shows Prettier's error"
assert_eq "$(git status --porcelain)" "" "files restored after a failure"

# A file that settles only on Prettier's second pass is committed settled.
repo="$(make_repo twopass)"
cd "$repo"
echo 'export const a = 1' >a.ts
git add -A && git commit -q -m "feat: code"
STUB_SECOND=1 install >/dev/null 2>&1
assert_contains "$(cat a.ts)" "// second" "second pass is in the formatting commit"
assert_eq "$(git status --porcelain)" "" "nothing left after the second pass"

repo="$(make_repo unstable)"
cd "$repo"
echo 'export const a = 1' >a.ts
git add -A && git commit -q -m "feat: code"
head_before="$(git rev-parse HEAD)"
err="$(STUB_NEVER=1 install 2>&1 >/dev/null)"; code=$?
assert_eq "$code" 2 "Prettier that never settles is a collision"
assert_contains "$err" "4 passes" "stderr says it did not settle"
assert_eq "$(git rev-parse HEAD)" "$head_before" "no commit when Prettier never settles"
assert_eq "$(git status --porcelain)" "" "files restored when Prettier never settles"

repo="$(make_repo biome)"
cd "$repo"
echo '{}' >biome.json
echo 'export const a = 1' >a.ts
git add -A && git commit -q -m "feat: code"
out="$(install)"
assert_contains "$out" "Biome" "Biome repo: skipped"
[[ -f .prettierrc.json ]] && fail "no Prettier config next to Biome"

repo="$(make_repo biomelint)"
cd "$repo"
echo '{"formatter": {"enabled": false}}' >biome.json
echo 'export const a = 1' >a.ts
git add -A && git commit -q -m "feat: code"
install >/dev/null 2>&1
[[ -f .prettierrc.json ]] || fail "Biome as linter only: Prettier baseline written"

# ── With the precommit installer: the hook follows the config ────────────────
pcstub="$WORK/pc"
mkdir -p "$pcstub"
printf '#!/usr/bin/env bash\nexit 0\n' >"$pcstub/pre-commit"
chmod +x "$pcstub/pre-commit"
repo="$(make_repo chain)"
cd "$repo"
echo 'export const a = 1' >a.ts
git add -A && git commit -q -m "feat: code"
PATH="$pcstub:$PATH" bash "$SCRIPTS/apply-all.sh" >/dev/null
assert_contains "$(cat .pre-commit-config.yaml)" "mirrors-prettier" "Prettier hook added after the baseline"

finish
