#!/usr/bin/env bash
# precommit: writes .pre-commit-config.yaml from the stacks it finds, rewrites a
# config it (or the old setup-review) wrote, never touches one the repo wrote, and
# runs `pre-commit install`. Uses a stub pre-commit, so it needs no network.
source "$(dirname "$0")/lib.sh"

stub="$WORK/stub"
mkdir -p "$stub"
cat > "$stub/pre-commit" <<EOF
#!/usr/bin/env bash
echo "\$*" >> "$WORK/pre-commit-calls"
EOF
chmod +x "$stub/pre-commit"
export PATH="$stub:$PATH"

install() { bash "$SCRIPTS/precommit/install.sh" --scope project; }

# ── Plain repo: the hooks every repo gets, nothing per language ────────────────
repo="$(make_repo plain)"
cd "$repo"
out="$(install)"; code=$?
assert_eq "$code" 0 "plain repo exits 0"
cfg="$(cat .pre-commit-config.yaml)"
for id in trailing-whitespace end-of-file-fixer check-merge-conflict check-added-large-files \
          detect-private-key check-yaml check-json check-toml gitleaks conventional-pre-commit; do
    assert_contains "$cfg" "id: $id" "plain repo gets $id"
done
assert_contains "$cfg" "default_install_hook_types: [pre-commit, commit-msg, pre-push]" "pre-commit install gets all three hooks"
assert_contains "$cfg" "stages: [commit-msg]" "Conventional Commits checks the message"
for id in ruff shfmt shellcheck actionlint hadolint prettier eslint osv-scanner; do
    assert_not_contains "$cfg" "id: $id" "plain repo has no $id"
done
assert_contains "$(cat "$WORK/pre-commit-calls")" "install" "pre-commit install ran"
assert_contains "$out" "→" "stdout names what changed"

before="$(snapshot "$repo")"
out="$(install)"; code=$?
assert_eq "$code" 0 "re-run exits 0"
assert_eq "$(snapshot "$repo")" "$before" "re-run changes no file"
assert_contains "$out" "no change" "re-run says nothing changed"

# ── Every stack ────────────────────────────────────────────────────────────────
repo="$(make_repo stacks)"
cd "$repo"
echo 'print(1)' > tool.py
printf '#!/usr/bin/env bash\nf() {\n    echo hi\n}\n' > run.sh
mkdir -p .github/workflows web
echo 'on: push' > .github/workflows/ci.yml
echo 'FROM alpine' > Dockerfile
echo '<p>hi</p>' > web/index.html
echo 'requests==2.32.3' > requirements.txt
install >/dev/null; code=$?
assert_eq "$code" 0 "all stacks exit 0"
cfg="$(cat .pre-commit-config.yaml)"
for id in ruff-check ruff-format shfmt shellcheck actionlint hadolint prettier osv-scanner; do
    assert_contains "$cfg" "id: $id" "stack hook $id"
done
assert_contains "$cfg" "args: [--fix]" "ruff fixes what it can"
assert_contains "$cfg" "args: [--write, -i, '4']" "shfmt keeps the 4-space indent"
assert_contains "$cfg" "https://github.com/rbubley/mirrors-prettier" "Prettier from the mirror without a package.json"
assert_contains "$cfg" "stages: [pre-push]" "osv-scanner on push"
assert_not_contains "$cfg" "eslint" "no ESLint without package.json"
python3 -c 'import yaml' 2>/dev/null && {
    python3 -c 'import yaml; yaml.safe_load(open(".pre-commit-config.yaml"))' || fail "config is valid YAML"
}

# The osv-scanner entry passes on exit 128 (no packages), fails on 1 (a CVE).
entry="$(sed -n "s/^ *entry: \(bash -c 'osv-scanner.*\)$/\1/p" .pre-commit-config.yaml)"
[[ -n "$entry" ]] || fail "osv-scanner entry found"
fake="$WORK/fake-osv"
mkdir -p "$fake"
printf '#!/usr/bin/env bash\nexit 128\n' > "$fake/osv-scanner"; chmod +x "$fake/osv-scanner"
PATH="$fake:$PATH" eval "$entry scan" >/dev/null 2>&1 || fail "osv-scanner hook passes on 'no packages found'"
printf '#!/usr/bin/env bash\nexit 1\n' > "$fake/osv-scanner"
PATH="$fake:$PATH" eval "$entry scan" >/dev/null 2>&1 && fail "osv-scanner hook fails on a vulnerability"

# Shell scripts indented with tabs, or with 2 spaces, keep that indent.
repo="$(make_repo tabs)"
cd "$repo"
printf 'f() {\n\techo hi\n}\n' > a.sh
install >/dev/null
assert_contains "$(cat .pre-commit-config.yaml)" "args: [--write, -i, '0']" "tab-indented scripts get -i 0"
repo="$(make_repo two)"
cd "$repo"
printf 'f() {\n  if true; then\n    echo hi\n  fi\n}\n' > a.sh
install >/dev/null
assert_contains "$(cat .pre-commit-config.yaml)" "args: [--write, -i, '2']" "2-space scripts get -i 2"

# The project's own Prettier and ESLint, through npx; Yarn Plug'n'Play through yarn.
repo="$(make_repo pkg)"
cd "$repo"
echo '{"devDependencies": {"prettier": "^3", "eslint": "^9"}}' > package.json
install >/dev/null
cfg="$(cat .pre-commit-config.yaml)"
assert_contains "$cfg" "entry: npx --no-install eslint --fix" "ESLint fixes through the project's npx"
assert_contains "$cfg" "entry: npx --no-install prettier --write --ignore-unknown" "Prettier writes through the project's npx"
assert_not_contains "$cfg" "mirrors-prettier" "no second Prettier next to the project's"
repo="$(make_repo pnp)"
cd "$repo"
echo '{"devDependencies": {"prettier": "^3"}}' > package.json
echo 'yarnPath: .yarn/releases/yarn.cjs' > .yarnrc.yml
install >/dev/null
assert_contains "$(cat .pre-commit-config.yaml)" "entry: yarn prettier --write" "PnP runs Prettier through yarn"

# A large repo: stack detection must not depend on how far grep reads the file list.
repo="$(make_repo large)"
cd "$repo"
mkdir -p gen
for i in $(seq 1 4000); do : > "gen/file-with-a-fairly-long-name-$i.txt"; done
echo 'print(1)' > zz.py
install >/dev/null
assert_contains "$(cat .pre-commit-config.yaml)" "id: ruff-check" "Python found in a large file list"

# ── A config this skill wrote is rewritten when the repo changes ───────────────
repo="$(make_repo grows)"
cd "$repo"
install >/dev/null
echo 'print(1)' > tool.py
out="$(install)"
assert_contains "$(cat .pre-commit-config.yaml)" "id: ruff-check" "rewrite picks up a new stack"
assert_contains "$out" "rewritten" "rewrite is reported"

# ── The old setup-review config is replaced ───────────────────────────────────
repo="$(make_repo old)"
cd "$repo"
printf '# Written by /fwd:setup-review. Re-running it never overwrites this file.\nrepos: []\n' > .pre-commit-config.yaml
install >/dev/null
cfg="$(cat .pre-commit-config.yaml)"
assert_contains "$(head -n 1 .pre-commit-config.yaml)" "# Written by /fwd:setup-precommit." "old config gets the new marker"
assert_contains "$cfg" "id: gitleaks" "old config gets the new hooks"

# ── A config the repo wrote itself is left alone ──────────────────────────────
repo="$(make_repo foreign)"
cd "$repo"
printf 'repos: []\n' > .pre-commit-config.yaml
: > "$WORK/pre-commit-calls"
out="$(install)"; code=$?
assert_eq "$code" 0 "foreign config exits 0"
assert_eq "$(cat .pre-commit-config.yaml)" "repos: []" "foreign config untouched"
assert_contains "$out" "↷" "foreign config reported as skipped"
assert_contains "$(cat "$WORK/pre-commit-calls")" "install" "pre-commit install still ran"

# ── No pre-commit and no uv: collision, config still written ──────────────────
repo="$(make_repo notools)"
cd "$repo"
bare="$WORK/bare-bin"
mkdir -p "$bare"
for t in bash git jq sed grep cat mkdir cp chmod dirname head tr basename find sort mktemp rm cmp awk; do
    ln -sf "$(command -v "$t")" "$bare/$t"
done
err="$(PATH="$bare" bash "$SCRIPTS/precommit/install.sh" --scope project 2>&1 >/dev/null)"; code=$?
assert_eq "$code" 2 "missing pre-commit and uv is a collision"
assert_contains "$err" "uv" "stderr names uv"
[[ -f .pre-commit-config.yaml ]] || fail "config written even without the binary"

finish
