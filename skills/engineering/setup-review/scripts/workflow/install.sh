#!/usr/bin/env bash
# install.sh - Write the GitHub Actions workflows that repeat the local checks on
# every pull request, so they also hold after `git commit --no-verify`.
#
# Usage:
#   install.sh --scope project
#
# Writes, each only when absent (an existing file is never overwritten, ↷):
#   .github/workflows/fwd-review.yml      on pull_request:
#       pre-commit   `pre-commit run --all-files`, with the toolchains its hooks need
#       gitleaks     the PR's commits (base..head) with a pinned, checksum-checked
#                    gitleaks: the pre-commit hook scans only staged changes, so
#                    `pre-commit run --all-files` alone never sees a committed key
#       osv-scanner  new dependency CVEs (npm, pip, Go, Cargo, ...), only with a lockfile
#       lint-test-*  lint and tests per stack found (Node, Python with uv, Go, Rust)
#   .github/workflows/fwd-osv-weekly.yml  weekly osv-scanner run, only with a lockfile
#
# Stacks are read once, at install time: a lockfile added later needs the file
# deleted and /fwd:setup-review re-run.

set -euo pipefail

# ── Parse args ────────────────────────────────────────────────────────────────

SCOPE=""
while [[ $# -gt 0 ]]; do
    case "$1" in
        --scope)
            [[ $# -ge 2 ]] || { echo "install: --scope needs an argument" >&2; exit 64; }
            SCOPE="$2"
            shift 2
            ;;
        *)
            echo "install: unknown argument: $1" >&2
            exit 64
            ;;
    esac
done

if [[ "$SCOPE" != "project" ]]; then
    echo "install: --scope must be 'project' (the review setup belongs to one repo)" >&2
    exit 64
fi

PROJECT_ROOT="${CLAUDE_PROJECT_DIR:-$(pwd)}"
WF_DIR="$PROJECT_ROOT/.github/workflows"
PR_WF="$WF_DIR/fwd-review.yml"
WEEKLY_WF="$WF_DIR/fwd-osv-weekly.yml"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../lib/stack.sh
source "$SCRIPT_DIR/../lib/stack.sh"
require_jq

# ── Detect stacks ─────────────────────────────────────────────────────────────

NODE=false; NODE_HOOKS=false; NODE_LINT=false; NODE_TEST=false
if root_has package.json; then
    NODE=true
    if pkg_has_dep prettier || pkg_has_dep eslint; then NODE_HOOKS=true; fi
    if pkg_has_script lint; then NODE_LINT=true; fi
    if pkg_has_script test; then NODE_TEST=true; fi
fi
if root_has pnpm-lock.yaml; then
    PM=pnpm; PM_INSTALL="pnpm install --frozen-lockfile"
elif root_has yarn.lock; then
    PM=yarn
    if root_has .yarnrc.yml; then PM_INSTALL="yarn install --immutable"; else PM_INSTALL="yarn install --frozen-lockfile"; fi
elif root_has package-lock.json; then
    PM=npm; PM_INSTALL="npm ci"
else
    PM=npm; PM_INSTALL="npm install"
fi

UV=false; PY_LINT=false; PY_TEST=false
if root_has uv.lock && root_has pyproject.toml; then
    UV=true
    if grep -q 'ruff' "$PROJECT_ROOT/pyproject.toml"; then PY_LINT=true; fi
    if grep -q 'pytest' "$PROJECT_ROOT/pyproject.toml"; then PY_TEST=true; fi
fi
PYTHON_NO_UV=false
if ! $UV && has_file "$PYTHON_MARKERS"; then PYTHON_NO_UV=true; fi
GO=false; if root_has go.mod; then GO=true; fi
RUST=false; if root_has Cargo.toml; then RUST=true; fi

# Files osv-scanner reads. Without one it finds no packages and fails the job.
OSV=false
if has_file '(^|/)(package-lock\.json|pnpm-lock\.yaml|yarn\.lock|uv\.lock|poetry\.lock|Pipfile\.lock|requirements[^/]*\.txt|go\.mod|Cargo\.lock|composer\.lock|Gemfile\.lock|pom\.xml|gradle\.lockfile)$'; then
    OSV=true
fi

# ── Pieces ────────────────────────────────────────────────────────────────────

node_setup() {
    cat <<'EOF'
      - uses: actions/setup-node@v7
        with:
          node-version: lts/*
EOF
    if [[ "$PM" != npm ]]; then
        # Node 25 and later no longer bundle corepack; install it first.
        cat <<'EOF'
      - run: npm install -g corepack && corepack enable
EOF
    fi
    cat <<EOF
      - run: $PM_INSTALL
EOF
}

go_setup() {
    cat <<'EOF'
      - uses: actions/setup-go@v7
        with:
          go-version-file: go.mod
EOF
}

uv_setup() {
    cat <<EOF
      - uses: astral-sh/setup-uv@$SETUP_UV_REF
      - run: uv sync --frozen
EOF
}

pr_workflow() {
    cat <<EOF
# Written by /fwd:setup-review. Re-running it never overwrites this file.
name: fwd-review

on:
  pull_request:

permissions:
  contents: read

jobs:
  pre-commit:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v7
      - uses: actions/setup-python@v7
        with:
          python-version: "3.x"
EOF
    $NODE_HOOKS && node_setup
    $GO && go_setup
    cat <<EOF
      - run: pip install pre-commit==$PRE_COMMIT_VERSION
      - run: pre-commit run --all-files --show-diff-on-failure

  # The pre-commit gitleaks hook scans staged changes only, so the job above cannot
  # see a key committed with --no-verify. This one scans every commit in the PR.
  gitleaks:
    runs-on: ubuntu-latest
    env:
      GITLEAKS_VERSION: $GITLEAKS_VERSION
      GITLEAKS_SHA256: $GITLEAKS_SHA256
    steps:
      - uses: actions/checkout@v7
        with:
          fetch-depth: 0
      - name: Install gitleaks
        run: |
          curl -sSfL -o gitleaks.tar.gz "https://github.com/gitleaks/gitleaks/releases/download/v\${GITLEAKS_VERSION}/gitleaks_\${GITLEAKS_VERSION}_linux_x64.tar.gz"
          echo "\${GITLEAKS_SHA256}  gitleaks.tar.gz" | sha256sum -c -
          tar -xzf gitleaks.tar.gz gitleaks
          sudo mv gitleaks /usr/local/bin/gitleaks
          rm gitleaks.tar.gz
      - name: Scan the pull request's commits
        env:
          BASE_SHA: \${{ github.event.pull_request.base.sha }}
          HEAD_SHA: \${{ github.event.pull_request.head.sha }}
        # --diff-merges=first-parent: plain git log -p shows no patch for a merge
        # commit, so a key added while resolving a merge would go unseen.
        run: gitleaks git --redact --verbose --log-opts="--diff-merges=first-parent \${BASE_SHA}..\${HEAD_SHA}" .
EOF
    if $OSV; then
        cat <<EOF

  osv-scanner:
    permissions:
      actions: read
      contents: read
      security-events: write
    uses: google/osv-scanner-action/.github/workflows/osv-scanner-reusable-pr.yml@$OSV_REF
    with:
      upload-sarif: false
EOF
    fi
    if $NODE && { $NODE_LINT || $NODE_TEST; }; then
        cat <<'EOF'

  lint-test-node:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v7
EOF
        node_setup
        $NODE_LINT && echo "      - run: $PM run lint"
        $NODE_TEST && echo "      - run: $PM test"
    fi
    if $UV && { $PY_LINT || $PY_TEST; }; then
        cat <<'EOF'

  lint-test-python:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v7
EOF
        uv_setup
        $PY_LINT && echo "      - run: uv run ruff check"
        $PY_TEST && echo "      - run: uv run pytest"
    fi
    if $GO; then
        cat <<'EOF'

  lint-test-go:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v7
EOF
        go_setup
        cat <<'EOF'
      - run: go vet ./...
      - run: go test ./...
EOF
    fi
    if $RUST; then
        cat <<'EOF'

  lint-test-rust:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v7
      - run: cargo clippy --all-targets -- -D warnings
      - run: cargo test
EOF
    fi
    return 0
}

weekly_workflow() {
    cat <<EOF
# Written by /fwd:setup-review. Re-running it never overwrites this file.
# New CVEs in dependencies that did not change, so no pull request would show them.
name: fwd-osv-weekly

on:
  schedule:
    - cron: "17 6 * * 1"
  workflow_dispatch:

permissions:
  contents: read

jobs:
  osv-scanner:
    permissions:
      actions: read
      contents: read
      security-events: write
    uses: google/osv-scanner-action/.github/workflows/osv-scanner-reusable.yml@$OSV_REF
    with:
      upload-sarif: false
EOF
}

# ── Write ─────────────────────────────────────────────────────────────────────

if [[ -e "$PR_WF" ]]; then
    echo "↷ $PR_WF already exists, left alone → delete it and re-run to regenerate"
else
    mkdir -p "$WF_DIR"
    pr_workflow > "$PR_WF"
    jobs="pre-commit, gitleaks"
    $OSV && jobs+=", osv-scanner"
    $NODE && { $NODE_LINT || $NODE_TEST; } && jobs+=", lint-test-node"
    $UV && { $PY_LINT || $PY_TEST; } && jobs+=", lint-test-python"
    $GO && jobs+=", lint-test-go"
    $RUST && jobs+=", lint-test-rust"
    echo "✔ Pull-request checks ($jobs) → $PR_WF"
    if ! $OSV; then echo "  (no osv-scanner: no lockfile or manifest it reads)"; fi
    if $PYTHON_NO_UV; then echo "  (no Python lint/test job: only written for uv projects with uv.lock)"; fi
fi

if $OSV; then
    if [[ -e "$WEEKLY_WF" ]]; then
        echo "↷ $WEEKLY_WF already exists, left alone → delete it and re-run to regenerate"
    else
        mkdir -p "$WF_DIR"
        weekly_workflow > "$WEEKLY_WF"
        echo "✔ Weekly osv-scanner run → $WEEKLY_WF"
    fi
fi
