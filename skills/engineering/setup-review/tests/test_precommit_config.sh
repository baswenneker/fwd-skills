#!/usr/bin/env bash
# precommit: writes .pre-commit-config.yaml from the stacks it finds, copies the
# pre-push script, runs `pre-commit install`, and never overwrites a config it did
# not write. Uses a stub pre-commit, so it needs no network.
source "$(dirname "$0")/lib.sh"

stub="$WORK/stub"
mkdir -p "$stub"
cat > "$stub/pre-commit" <<EOF
#!/usr/bin/env bash
echo "\$*" >> "$WORK/pre-commit-calls"
EOF
chmod +x "$stub/pre-commit"
export PATH="$stub:$PATH"

# ── Plain repo: gitleaks + push hook only ─────────────────────────────────────
repo="$(make_repo plain)"
cd "$repo"
out="$(bash "$SCRIPTS/precommit/install.sh" --scope project)"; code=$?
assert_eq "$code" 0 "plain repo exits 0"
cfg="$(cat .pre-commit-config.yaml)"
assert_contains "$cfg" "https://github.com/gitleaks/gitleaks" "gitleaks hook"
assert_contains "$cfg" "id: fwd-review-push" "push hook"
assert_contains "$cfg" "stages: [pre-push]" "push hook on pre-push stage"
assert_contains "$cfg" "default_install_hook_types: [pre-commit, pre-push]" "plain pre-commit install gets both hooks"
assert_not_contains "$cfg" "ruff" "no Python hook without Python"
assert_not_contains "$cfg" "prettier" "no Prettier without package.json"
assert_not_contains "$cfg" "fwd-worktree-deps" "no worktree install without Prettier or ESLint"
[[ ! -e .claude/fwd/worktree-deps.sh ]] || fail "no worktree install script without Prettier or ESLint"
[[ -x .claude/fwd/review-push.sh ]] || fail "review-push.sh copied and executable"
assert_contains "$(cat "$WORK/pre-commit-calls")" "install" "pre-commit install ran"
assert_contains "$out" "→" "stdout names what changed"

before="$(snapshot "$repo")"
bash "$SCRIPTS/precommit/install.sh" --scope project >/dev/null; code=$?
assert_eq "$code" 0 "re-run exits 0"
assert_eq "$(snapshot "$repo")" "$before" "re-run changes no file"

# A config written before the push hook had verbose: it gets it, once.
assert_contains "$cfg" "verbose: true" "push hook shows its output"
grep -v 'verbose: true' .pre-commit-config.yaml > old.yaml && mv old.yaml .pre-commit-config.yaml
out="$(bash "$SCRIPTS/precommit/install.sh" --scope project)"; code=$?
assert_eq "$code" 0 "upgrade exits 0"
assert_eq "$(grep -c 'verbose: true' .pre-commit-config.yaml)" 1 "verbose added once"
assert_contains "$out" "verbose: true" "upgrade says what changed"
python3 -c 'import sys,yaml; c=yaml.safe_load(open(".pre-commit-config.yaml")); h=[h for r in c["repos"] for h in r["hooks"] if h["id"]=="fwd-review-push"][0]; sys.exit(0 if h.get("verbose") is True else 1)' 2>/dev/null ||
    { python3 -c 'import yaml' 2>/dev/null && fail "upgraded config is valid YAML with verbose on the push hook"; }
before="$(snapshot "$repo")"
bash "$SCRIPTS/precommit/install.sh" --scope project >/dev/null
assert_eq "$(snapshot "$repo")" "$before" "re-run after the upgrade changes no file"

# ── Every stack ────────────────────────────────────────────────────────────────
repo="$(make_repo stacks)"
cd "$repo"
echo '[project]' > pyproject.toml
echo 'module example.com/w' > go.mod
echo '[package]' > Cargo.toml
echo '{"devDependencies": {"prettier": "^3", "eslint": "^9"}}' > package.json
bash "$SCRIPTS/precommit/install.sh" --scope project >/dev/null; code=$?
assert_eq "$code" 0 "all stacks exit 0"
cfg="$(cat .pre-commit-config.yaml)"
assert_contains "$cfg" "id: ruff-format" "Python format check"
assert_contains "$cfg" "npx --no-install prettier --check" "Prettier through the project's npx"
assert_contains "$cfg" "npx --no-install eslint" "ESLint through the project's npx"
assert_contains "$cfg" "types_or: [javascript, jsx, ts, tsx, css, scss]" "Prettier checks code only, not notes"
assert_contains "$cfg" "gofmt -l" "Go format check"
assert_contains "$cfg" "cargo fmt" "Rust format check"
assert_contains "$cfg" "id: fwd-worktree-deps" "worktree install with Prettier or ESLint"
assert_contains "$cfg" "stages: [post-checkout]" "worktree install on post-checkout"
assert_contains "$cfg" "default_install_hook_types: [pre-commit, pre-push, post-checkout]" "plain pre-commit install gets the post-checkout hook too"
[[ -x .claude/fwd/worktree-deps.sh ]] || fail "worktree-deps.sh copied and executable"
assert_contains "$(tail -n 1 "$WORK/pre-commit-calls")" "install" "pre-commit install ran"

# A config written before the worktree install: it gets the hook, once, inside the
# local repo, and the scripts stay in sync.
python3 - <<'EOF'
import re
s = open(".pre-commit-config.yaml").read()
s = s.replace("[pre-commit, pre-push, post-checkout]", "[pre-commit, pre-push]")
s = s[:s.index("      # Installs node_modules")]
open(".pre-commit-config.yaml", "w").write(s)
EOF
rm .claude/fwd/worktree-deps.sh
out="$(bash "$SCRIPTS/precommit/install.sh" --scope project)"; code=$?
assert_eq "$code" 0 "worktree upgrade exits 0"
assert_contains "$out" "post-checkout" "worktree upgrade says what changed"
assert_eq "$(grep -c 'id: fwd-worktree-deps' .pre-commit-config.yaml)" 1 "worktree hook added once"
assert_contains "$(cat .pre-commit-config.yaml)" "[pre-commit, pre-push, post-checkout]" "upgrade adds the hook type"
[[ -x .claude/fwd/worktree-deps.sh ]] || fail "upgrade copies worktree-deps.sh"
python3 -c 'import sys,yaml; c=yaml.safe_load(open(".pre-commit-config.yaml")); r=[r for r in c["repos"] if any(h["id"]=="fwd-worktree-deps" for h in r["hooks"])]; sys.exit(0 if r and r[0]["repo"]=="local" else 1)' 2>/dev/null ||
    { python3 -c 'import yaml' 2>/dev/null && fail "upgraded config is valid YAML with the worktree hook in the local repo"; }
before="$(snapshot "$repo")"
bash "$SCRIPTS/precommit/install.sh" --scope project >/dev/null
assert_eq "$(snapshot "$repo")" "$before" "re-run after the worktree upgrade changes no file"

# The gofmt hook fails when gofmt itself fails (missing, or a syntax error), not only
# when it lists files.
entry="$(sed -n 's/^ *entry: \(bash -c .*gofmt.*\)$/\1/p' .pre-commit-config.yaml)"
[[ -n "$entry" ]] || fail "gofmt entry found"
nogo="$WORK/nogo-bin"
mkdir -p "$nogo"
ln -sf "$(command -v bash)" "$nogo/bash"
echo 'package w' > w.go
PATH="$nogo" eval "$entry w.go" >/dev/null 2>&1 && fail "gofmt hook fails when gofmt is missing"
printf '#!/usr/bin/env bash\necho "w.go:1: syntax error" >&2\nexit 2\n' > "$nogo/gofmt"
chmod +x "$nogo/gofmt"
ln -sf "$(command -v env)" "$nogo/env"
PATH="$nogo" eval "$entry w.go" >/dev/null 2>&1 && fail "gofmt hook fails when gofmt exits non-zero"
printf '#!/usr/bin/env bash\nexit 0\n' > "$nogo/gofmt"
PATH="$nogo" eval "$entry w.go" >/dev/null 2>&1 || fail "gofmt hook passes on formatted files"
rm -f w.go

# Python detected from a tracked .py file alone; Node without Prettier gets no Prettier hook.
repo="$(make_repo pyfile)"
cd "$repo"
echo 'print(1)' > tool.py
echo '{"dependencies": {"left-pad": "1"}}' > package.json
bash "$SCRIPTS/precommit/install.sh" --scope project >/dev/null
cfg="$(cat .pre-commit-config.yaml)"
assert_contains "$cfg" "id: ruff-format" "Python from a .py file"
assert_not_contains "$cfg" "prettier" "no Prettier when package.json lacks it"
assert_not_contains "$cfg" "eslint" "no ESLint when package.json lacks it"

# Yarn Plug'n'Play has no node_modules for npx: the hooks go through yarn.
repo="$(make_repo pnp)"
cd "$repo"
echo '{"devDependencies": {"prettier": "^3"}}' > package.json
echo 'yarnPath: .yarn/releases/yarn.cjs' > .yarnrc.yml
bash "$SCRIPTS/precommit/install.sh" --scope project >/dev/null
assert_contains "$(cat .pre-commit-config.yaml)" "entry: yarn prettier --check" "PnP runs Prettier through yarn"

# A large repo: stack detection must not depend on how far grep reads the file list.
repo="$(make_repo large)"
cd "$repo"
mkdir -p gen
for i in $(seq 1 4000); do : > "gen/file-with-a-fairly-long-name-$i.txt"; done
echo 'print(1)' > zz.py
bash "$SCRIPTS/precommit/install.sh" --scope project >/dev/null
assert_contains "$(cat .pre-commit-config.yaml)" "id: ruff-format" "Python found in a large file list"

# ── A config the repo wrote itself is left alone ──────────────────────────────
repo="$(make_repo foreign)"
cd "$repo"
printf 'repos: []\n' > .pre-commit-config.yaml
: > "$WORK/pre-commit-calls"
out="$(bash "$SCRIPTS/precommit/install.sh" --scope project)"; code=$?
assert_eq "$code" 0 "foreign config exits 0"
assert_eq "$(cat .pre-commit-config.yaml)" "repos: []" "foreign config untouched"
assert_contains "$out" "↷" "foreign config reported as skipped"
assert_contains "$out" "gitleaks" "skip line says gitleaks was not added"
[[ ! -e .claude/fwd/review-push.sh ]] || fail "no push script next to a foreign config"
assert_contains "$(cat "$WORK/pre-commit-calls")" "install" "pre-commit install still ran"

# ── No pre-commit and no uv: collision, config still written ──────────────────
repo="$(make_repo notools)"
cd "$repo"
bare="$WORK/bare-bin"
mkdir -p "$bare"
for t in bash git jq sed grep cat mkdir cp chmod dirname head tr basename find sort mktemp rm cmp; do
    ln -sf "$(command -v "$t")" "$bare/$t"
done
err="$(PATH="$bare" bash "$SCRIPTS/precommit/install.sh" --scope project 2>&1 >/dev/null)"; code=$?
assert_eq "$code" 2 "missing pre-commit and uv is a collision"
assert_contains "$err" "uv" "stderr names uv"
[[ -f .pre-commit-config.yaml ]] || fail "config written even without the binary"

finish
