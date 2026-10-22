#!/usr/bin/env bash
# workflow: writes the pull-request workflow (pre-commit, gitleaks over the PR's commits,
# osv-scanner, lint + tests per stack) and the weekly osv-scanner workflow; osv-scanner
# only with a lockfile; never overwrites an existing file.
source "$(dirname "$0")/lib.sh"

PR=.github/workflows/fwd-review.yml
WEEKLY=.github/workflows/fwd-osv-weekly.yml

valid_yaml() {
    if python3 -c 'import yaml' 2>/dev/null; then
        python3 -c 'import sys, yaml; yaml.safe_load(open(sys.argv[1]))' "$1" || fail "$1 is not valid YAML"
    fi
}

# ── Repo without a lockfile ────────────────────────────────────────────────────
repo="$(make_repo nolock)"
cd "$repo"
out="$(bash "$SCRIPTS/workflow/install.sh" --scope project)"; code=$?
assert_eq "$code" 0 "exits 0"
wf="$(cat "$PR")"
assert_contains "$wf" "pull_request" "runs on pull requests"
assert_contains "$wf" "pre-commit run --all-files" "pre-commit over all files"
assert_contains "$wf" "gitleaks git" "gitleaks over the commit range"
assert_contains "$wf" "sha256sum -c" "gitleaks binary checksum checked"
assert_contains "$wf" "fetch-depth: 0" "full history for the range"
assert_not_contains "$wf" "osv-scanner" "no osv-scanner without a lockfile"
[[ ! -e "$WEEKLY" ]] || fail "no weekly scan without a lockfile"
assert_contains "$out" "osv-scanner" "stdout says why osv-scanner was left out"
valid_yaml "$PR"

before="$(snapshot "$repo")"
bash "$SCRIPTS/workflow/install.sh" --scope project >/dev/null; code=$?
assert_eq "$code" 0 "re-run exits 0"
assert_eq "$(snapshot "$repo")" "$before" "re-run changes no file"

# ── Node repo with a lockfile and lint/test scripts ───────────────────────────
repo="$(make_repo node)"
cd "$repo"
echo '{"scripts": {"lint": "eslint .", "test": "vitest"}, "devDependencies": {"prettier": "^3"}}' > package.json
echo '{}' > package-lock.json
bash "$SCRIPTS/workflow/install.sh" --scope project >/dev/null; code=$?
assert_eq "$code" 0 "node exits 0"
wf="$(cat "$PR")"
assert_contains "$wf" "osv-scanner-reusable-pr.yml" "osv-scanner on the PR"
assert_contains "$wf" "upload-sarif: false" "works without code scanning"
assert_contains "$wf" "npm ci" "dependencies installed"
assert_contains "$wf" "npm run lint" "lint"
assert_contains "$wf" "npm test" "tests"
weekly="$(cat "$WEEKLY")"
assert_contains "$weekly" "schedule" "weekly on a schedule"
assert_contains "$weekly" "osv-scanner-reusable.yml" "weekly osv-scanner"
valid_yaml "$PR"
valid_yaml "$WEEKLY"

# ── Python (uv), Go, Rust ─────────────────────────────────────────────────────
repo="$(make_repo polyglot)"
cd "$repo"
printf '[project]\nname = "w"\n[dependency-groups]\ndev = ["pytest", "ruff"]\n' > pyproject.toml
echo 'version = 1' > uv.lock
echo 'module example.com/w' > go.mod
echo '[package]' > Cargo.toml
echo '' > Cargo.lock
bash "$SCRIPTS/workflow/install.sh" --scope project >/dev/null
wf="$(cat "$PR")"
assert_contains "$wf" "uv sync --frozen" "uv dependencies"
assert_contains "$wf" "uv run pytest" "pytest"
assert_contains "$wf" "uv run ruff check" "ruff lint"
assert_contains "$wf" "go test ./..." "go tests"
assert_contains "$wf" "go vet ./..." "go lint"
assert_contains "$wf" "cargo test" "rust tests"
assert_contains "$wf" "cargo clippy" "rust lint"
valid_yaml "$PR"

# ── Existing workflow file is left alone ──────────────────────────────────────
repo="$(make_repo existing)"
cd "$repo"
mkdir -p .github/workflows
echo 'name: mine' > "$PR"
out="$(bash "$SCRIPTS/workflow/install.sh" --scope project)"; code=$?
assert_eq "$code" 0 "existing file exits 0"
assert_eq "$(cat "$PR")" "name: mine" "existing workflow untouched"
assert_contains "$out" "↷" "existing workflow reported as skipped"

finish
