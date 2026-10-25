#!/usr/bin/env bash
# install.sh - Set the repo up with the pre-commit framework: file hygiene, gitleaks
# and autofixing formatters on every commit, a Conventional Commits check on the
# message, and osv-scanner on every push.
#
# Usage:
#   install.sh --scope project
#
# Behavior:
#   - no .pre-commit-config.yaml → writes one from the stacks it finds
#   - one this skill (or the old /fwd:setup-review) wrote, recognised by its first
#     line → rewritten from the stacks found now; same content → no change
#   - one the repo wrote itself → left alone, reported as skipped (↷)
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
    echo "install: --scope must be 'project' (the hooks belong to one repo)" >&2
    exit 64
fi

# ── Resolve paths ─────────────────────────────────────────────────────────────

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="${CLAUDE_PROJECT_DIR:-$(pwd)}"
CONFIG="$PROJECT_ROOT/.pre-commit-config.yaml"
MARKER="# Written by /fwd:setup-precommit."
OLD_MARKER="# Written by /fwd:setup-review."

if ! git -C "$PROJECT_ROOT" rev-parse --git-dir >/dev/null 2>&1; then
    echo "⚠  $PROJECT_ROOT is not a git repository; pre-commit hooks need one. Run git init and re-run /fwd:setup-precommit." >&2
    exit 2
fi

# shellcheck source=../lib/stack.sh
source "$SCRIPT_DIR/../lib/stack.sh"
require_jq

# ── Detect stacks ─────────────────────────────────────────────────────────────

PYTHON=false; SHELL_FILES=false; WEB=false; WORKFLOWS=false; DOCKER=false; LOCKFILE=false
PKG_PRETTIER=false; PKG_ESLINT=false
if has_file "$PYTHON_MARKERS"; then PYTHON=true; fi
if has_file "$SHELL_MARKERS"; then SHELL_FILES=true; fi
if has_file "$WEB_MARKERS" || root_has package.json; then WEB=true; fi
if has_file "$WORKFLOW_MARKERS"; then WORKFLOWS=true; fi
if has_file "$DOCKER_MARKERS"; then DOCKER=true; fi
if has_file "$LOCKFILE_MARKERS"; then LOCKFILE=true; fi
if root_has package.json; then
    if pkg_has_dep prettier; then PKG_PRETTIER=true; fi
    if pkg_has_dep eslint; then PKG_ESLINT=true; fi
fi
JS_RUNNER="$(js_runner)"
SHELL_INDENT="$(shell_indent)"

# Generated and vendored files the fixers must not rewrite.
FIXER_EXCLUDE='(^|/)(package-lock\.json|npm-shrinkwrap\.json|yarn\.lock|pnpm-lock\.yaml|bun\.lock|uv\.lock|poetry\.lock|Pipfile\.lock|Cargo\.lock|composer\.lock|vendor/.*|.*\.min\.(js|css))$'
PRETTIER_TYPES='[javascript, jsx, ts, tsx, css, scss, less, html, vue, json]'

# ── Write the config ──────────────────────────────────────────────────────────

write_config() {
    cat <<EOF
$MARKER A re-run rewrites this file; delete this line to keep your own edits.
# After a clone, \`pre-commit install\` installs all three hooks: commit, commit
# message and push.
default_install_hook_types: [pre-commit, commit-msg, pre-push]
# default_stages covers only hooks whose own definition names no stages; the
# ones that list pre-push get stages: [pre-commit] here, or they run on push too.
default_stages: [pre-commit]
repos:
  - repo: https://github.com/pre-commit/pre-commit-hooks
    rev: $PRE_COMMIT_HOOKS_REV
    hooks:
      - id: trailing-whitespace
        args: [--markdown-linebreak-ext=md]
        exclude: '$FIXER_EXCLUDE'
        stages: [pre-commit]
      - id: end-of-file-fixer
        exclude: '$FIXER_EXCLUDE'
        stages: [pre-commit]
      - id: check-merge-conflict
      - id: check-added-large-files
        stages: [pre-commit]
      - id: detect-private-key
      # Syntax only: custom tags (!Ref, !!python) and multi-document files pass.
      - id: check-yaml
        args: [--allow-multiple-documents, --unsafe]
      # tsconfig and editor settings are JSON with comments.
      - id: check-json
        exclude: '(^|/)(tsconfig[^/]*|jsconfig[^/]*)\.json$|(^|/)\.(vscode|devcontainer)/'
      - id: check-toml
  - repo: https://github.com/gitleaks/gitleaks
    rev: $GITLEAKS_REV
    hooks:
      - id: gitleaks
  - repo: https://github.com/compilerla/conventional-pre-commit
    rev: $CONVENTIONAL_REV
    hooks:
      - id: conventional-pre-commit
        stages: [commit-msg]
EOF
    if $PYTHON; then
        cat <<EOF
  - repo: https://github.com/astral-sh/ruff-pre-commit
    rev: $RUFF_REV
    hooks:
      - id: ruff-check
        args: [--fix]
      - id: ruff-format
        types_or: [python, pyi]
EOF
    fi
    if $SHELL_FILES; then
        cat <<EOF
  - repo: https://github.com/scop/pre-commit-shfmt
    rev: $SHFMT_REV
    hooks:
      # -i: the indent the scripts already use, so shfmt does not re-indent them.
      - id: shfmt
        args: [--write, -i, '$SHELL_INDENT']
        stages: [pre-commit]
  - repo: https://github.com/shellcheck-py/shellcheck-py
    rev: $SHELLCHECK_REV
    hooks:
      - id: shellcheck
EOF
    fi
    if $WORKFLOWS; then
        cat <<EOF
  - repo: https://github.com/rhysd/actionlint
    rev: $ACTIONLINT_REV
    hooks:
      - id: actionlint
EOF
    fi
    if $DOCKER; then
        cat <<EOF
  - repo: https://github.com/AleksaC/hadolint-py
    rev: $HADOLINT_REV
    hooks:
      - id: hadolint
EOF
    fi
    if $WEB && ! $PKG_PRETTIER; then
        cat <<EOF
  - repo: https://github.com/rbubley/mirrors-prettier
    rev: $PRETTIER_REV
    hooks:
      - id: prettier
        types_or: $PRETTIER_TYPES
        exclude: '$FIXER_EXCLUDE'
EOF
    fi
    if $PKG_ESLINT || $PKG_PRETTIER; then
        cat <<EOF
  # The project's own ESLint and Prettier ($JS_RUNNER), with its own version,
  # plugins and config. ESLint first: Prettier then formats what it fixed.
  - repo: local
    hooks:
EOF
    fi
    if $PKG_ESLINT; then
        cat <<EOF
      - id: eslint
        name: eslint --fix
        entry: $JS_RUNNER eslint --fix
        language: system
        types_or: [javascript, jsx, ts, tsx]
EOF
    fi
    if $PKG_PRETTIER; then
        cat <<EOF
      - id: prettier
        name: prettier --write
        entry: $JS_RUNNER prettier --write --ignore-unknown
        language: system
        types_or: $PRETTIER_TYPES
        exclude: '$FIXER_EXCLUDE'
EOF
    fi
    if $LOCKFILE; then
        cat <<EOF
  - repo: https://github.com/google/osv-scanner
    rev: $OSV_REV
    hooks:
      # Every push, all lockfiles: a dependency with a known CVE blocks the push.
      # Exit 128 is "no packages found" (a go.mod without dependencies): no
      # reason to block.
      - id: osv-scanner
        entry: bash -c 'osv-scanner "\$@"; rc=\$?; [ "\$rc" -eq 128 ] && exit 0; exit "\$rc"' --
        stages: [pre-push]
EOF
    fi
}

describe() {
    local parts="gitleaks, file checks, Conventional Commits"
    $PYTHON && parts+=", ruff"
    $SHELL_FILES && parts+=", shfmt, shellcheck"
    $WORKFLOWS && parts+=", actionlint"
    $DOCKER && parts+=", hadolint"
    $WEB && parts+=", prettier"
    $PKG_ESLINT && parts+=", eslint"
    $LOCKFILE && parts+=", osv-scanner on push"
    echo "$parts"
}

NEW="$(write_config)"
if [[ ! -f "$CONFIG" ]]; then
    printf '%s\n' "$NEW" > "$CONFIG"
    echo "✔ $(describe) → $CONFIG"
elif first="$(head -n 1 "$CONFIG")"; [[ "$first" == "$MARKER"* || "$first" == "$OLD_MARKER"* ]]; then
    if [[ "$(cat "$CONFIG")" == "$NEW" ]]; then
        echo "✔ already up to date, no change → $CONFIG"
    else
        printf '%s\n' "$NEW" > "$CONFIG"
        echo "✔ rewritten: $(describe) → $CONFIG"
    fi
else
    echo "↷ $CONFIG belongs to the repo, left alone: no hooks were added → add them by hand, or delete the file and re-run /fwd:setup-precommit"
fi

# ── Make sure pre-commit exists ───────────────────────────────────────────────

if ! command -v pre-commit >/dev/null 2>&1; then
    if ! command -v uv >/dev/null 2>&1; then
        echo "⚠  pre-commit is not installed and uv is not either, so it cannot be installed." >&2
        echo "   Install uv (https://docs.astral.sh/uv/), then re-run /fwd:setup-precommit." >&2
        exit 2
    fi
    if ! uv tool install pre-commit >/dev/null 2>&1; then
        echo "⚠  \`uv tool install pre-commit\` failed. Run it by hand to see why, then re-run /fwd:setup-precommit." >&2
        exit 2
    fi
    UV_BIN="$(uv tool dir --bin 2>/dev/null || echo "$HOME/.local/bin")"
    export PATH="$UV_BIN:$PATH"
    echo "✔ pre-commit installed with uv tool install"
fi

# ── Install the git hooks ─────────────────────────────────────────────────────

if [[ -n "$(git -C "$PROJECT_ROOT" config --get core.hooksPath 2>/dev/null || true)" ]]; then
    echo "⚠  core.hooksPath is set ($(git -C "$PROJECT_ROOT" config --get core.hooksPath)), probably by husky; pre-commit will not install its hooks next to it." >&2
    echo "   Remove it (git config --unset core.hooksPath) or call pre-commit from those hooks, then re-run /fwd:setup-precommit." >&2
    exit 2
fi

if ! out="$(cd "$PROJECT_ROOT" && pre-commit install 2>&1)"; then
    echo "⚠  pre-commit install failed:" >&2
    printf '%s\n' "$out" | sed 's/^/   /' >&2
    exit 2
fi
echo "✔ Git hooks installed with pre-commit install (pre-commit, commit-msg, pre-push)"
