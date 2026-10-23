#!/usr/bin/env bash
# install.sh - Set the repo up with the pre-commit framework: gitleaks on every commit,
# a format check per language found, ESLint/Prettier through the project's own npx,
# and a pre-push hook that asks the Workcenter reviewer to look at the branch.
#
# Usage:
#   install.sh --scope project
#
# Behavior:
#   - no .pre-commit-config.yaml → writes one from the stacks it finds, copies
#     review-push.sh to .claude/fwd/
#   - one this installer wrote (first line is the marker) → left as it is, push
#     script refreshed
#   - one the repo wrote itself → left alone, reported as skipped (↷): gitleaks and
#     the push hook are then not added
#   Then makes sure `pre-commit` exists (`uv tool install pre-commit`) and runs
#   `pre-commit install`, which reads default_install_hook_types from the config.
#
# Exit 2 when pre-commit is missing and uv is too, or when core.hooksPath is set
# (husky and friends), which makes `pre-commit install` refuse.

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

# ── Resolve paths ─────────────────────────────────────────────────────────────

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PAYLOAD_DIR="$SCRIPT_DIR/payload"
PROJECT_ROOT="${CLAUDE_PROJECT_DIR:-$(pwd)}"
CONFIG="$PROJECT_ROOT/.pre-commit-config.yaml"
PUSH_SCRIPT="$PROJECT_ROOT/.claude/fwd/review-push.sh"
MARKER="# Written by /fwd:setup-review."

if ! git -C "$PROJECT_ROOT" rev-parse --git-dir >/dev/null 2>&1; then
    echo "⚠  $PROJECT_ROOT is not a git repository; pre-commit hooks need one. Run git init and re-run /fwd:setup-review." >&2
    exit 2
fi

# shellcheck source=../lib/stack.sh
source "$SCRIPT_DIR/../lib/stack.sh"
require_jq

# ── Detect stacks ─────────────────────────────────────────────────────────────

PYTHON=false; GO=false; RUST=false; PRETTIER=false; ESLINT=false
if has_file "$PYTHON_MARKERS"; then PYTHON=true; fi
if root_has go.mod; then GO=true; fi
if root_has Cargo.toml; then RUST=true; fi
if root_has package.json; then
    if pkg_has_dep prettier; then PRETTIER=true; fi
    if pkg_has_dep eslint; then ESLINT=true; fi
fi
JS_RUNNER="$(js_runner)"

# ── Write the config ──────────────────────────────────────────────────────────

write_config() {
    cat <<EOF
$MARKER Re-running it never overwrites this file.
# \`pre-commit install\` installs both the commit and the push hook.
default_install_hook_types: [pre-commit, pre-push]
default_stages: [pre-commit]
repos:
  - repo: https://github.com/gitleaks/gitleaks
    rev: v$GITLEAKS_VERSION
    hooks:
      - id: gitleaks
EOF
    if $PYTHON; then
        cat <<EOF
  - repo: https://github.com/astral-sh/ruff-pre-commit
    rev: $RUFF_REV
    hooks:
      - id: ruff-format
        args: [--check]
        types_or: [python, pyi]
EOF
    fi
    cat <<'EOF'
  - repo: local
    hooks:
EOF
    if $PRETTIER; then
        cat <<EOF
      # The project's own Prettier and ESLint ($JS_RUNNER), not a second copy.
      - id: prettier
        name: prettier --check
        entry: $JS_RUNNER prettier --check --ignore-unknown
        language: system
        types: [text]
EOF
    fi
    if $ESLINT; then
        cat <<EOF
      - id: eslint
        name: eslint
        entry: $JS_RUNNER eslint
        language: system
        types_or: [javascript, jsx, ts, tsx]
EOF
    fi
    if $GO; then
        cat <<'EOF'
      # gofmt -l exits 0 even when files need formatting; fail on any output, and
      # when gofmt itself fails (missing, syntax error).
      - id: gofmt
        name: gofmt
        entry: bash -c 'out="$(gofmt -l "$@")" || exit 1; [ -z "$out" ] || { echo "$out"; exit 1; }' --
        language: system
        types: [go]
EOF
    fi
    if $RUST; then
        cat <<'EOF'
      - id: cargo-fmt
        name: cargo fmt --check
        entry: cargo fmt --all -- --check
        language: system
        types: [rust]
        pass_filenames: false
EOF
    fi
    cat <<'EOF'
      # Asks the Workcenter reviewer to look at the branch; returns at once.
      - id: fwd-review-push
        name: Workcenter reviewer (background)
        entry: .claude/fwd/review-push.sh
        language: script
        stages: [pre-push]
        pass_filenames: false
        always_run: true
        # pre-commit hides what a passing hook prints; the reviewer's warning
        # must show.
        verbose: true
EOF
}

OURS=false
if [[ ! -f "$CONFIG" ]]; then
    write_config > "$CONFIG"
    OURS=true
    stacks=""
    $PYTHON && stacks+=" Python"
    $PRETTIER && stacks+=" Prettier"
    $ESLINT && stacks+=" ESLint"
    $GO && stacks+=" Go"
    $RUST && stacks+=" Rust"
    echo "✔ gitleaks, push hook${stacks:+ and format checks for$stacks} → $CONFIG"
elif [[ "$(head -n 1 "$CONFIG")" == "$MARKER"* ]]; then
    OURS=true
    # Written before the push hook said anything: without verbose its warning
    # stays hidden.
    if grep -q 'id: fwd-review-push' "$CONFIG" &&
        ! awk '/id: fwd-review-push/ { in_hook = 1; next } in_hook && /- id:/ { exit } in_hook && /verbose: true/ { found = 1 } END { exit !found }' "$CONFIG"; then
        awk '{ print } /id: fwd-review-push/ { in_hook = 1 } in_hook && /always_run: true/ { sub(/always_run: true.*/, ""); print $0 "verbose: true"; in_hook = 0 }' \
            "$CONFIG" > "$CONFIG.tmp" && mv "$CONFIG.tmp" "$CONFIG"
        echo "✔ push hook now shows the reviewer's warnings (verbose: true) → $CONFIG"
    else
        echo "✔ already written by /fwd:setup-review, no change → $CONFIG"
    fi
else
    echo "↷ $CONFIG belongs to the repo, left alone: gitleaks and the push hook were not added → add them by hand (see /fwd:setup-review)"
fi

if $OURS; then
    mkdir -p "$(dirname "$PUSH_SCRIPT")"
    if ! cmp -s "$PAYLOAD_DIR/review-push.sh" "$PUSH_SCRIPT"; then
        cp "$PAYLOAD_DIR/review-push.sh" "$PUSH_SCRIPT"
        echo "✔ Push script → $PUSH_SCRIPT"
    fi
    [[ -x "$PUSH_SCRIPT" ]] || chmod +x "$PUSH_SCRIPT"
fi

# ── Make sure pre-commit exists ───────────────────────────────────────────────

if ! command -v pre-commit >/dev/null 2>&1; then
    if ! command -v uv >/dev/null 2>&1; then
        echo "⚠  pre-commit is not installed and uv is not either, so it cannot be installed." >&2
        echo "   Install uv (https://docs.astral.sh/uv/), then re-run /fwd:setup-review." >&2
        exit 2
    fi
    if ! uv tool install pre-commit >/dev/null 2>&1; then
        echo "⚠  \`uv tool install pre-commit\` failed. Run it by hand to see why, then re-run /fwd:setup-review." >&2
        exit 2
    fi
    UV_BIN="$(uv tool dir --bin 2>/dev/null || echo "$HOME/.local/bin")"
    export PATH="$UV_BIN:$PATH"
    echo "✔ pre-commit installed with uv tool install"
fi

# ── Install the git hooks ─────────────────────────────────────────────────────

if [[ -n "$(git -C "$PROJECT_ROOT" config --get core.hooksPath 2>/dev/null || true)" ]]; then
    echo "⚠  core.hooksPath is set ($(git -C "$PROJECT_ROOT" config --get core.hooksPath)), probably by husky; pre-commit will not install its hooks next to it." >&2
    echo "   Remove it (git config --unset core.hooksPath) or call pre-commit from those hooks, then re-run /fwd:setup-review." >&2
    exit 2
fi

if ! out="$(cd "$PROJECT_ROOT" && pre-commit install 2>&1)"; then
    echo "⚠  pre-commit install failed:" >&2
    printf '%s\n' "$out" | sed 's/^/   /' >&2
    exit 2
fi
echo "✔ Git hooks installed with pre-commit install (pre-commit, pre-push)"
