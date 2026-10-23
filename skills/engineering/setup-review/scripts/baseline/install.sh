#!/usr/bin/env bash
# install.sh - Clear the debt the new checks would trip over. Runs the project's own
# formatters and lint autofixes over every tracked file the hooks check, commits what
# they changed as one separate commit, and lists what still fails.
#
# Usage:
#   install.sh --scope project
#
# Behavior:
#   - .pre-commit-config.yaml not written by /fwd:setup-review → ↷, nothing touched:
#     it is unknown what that config checks
#   - uncommitted changes in tracked files (other than this skill's own files) → ↷,
#     nothing touched: the fix commit would otherwise take those changes along
#   - otherwise runs, per hook in the config: eslint --fix, prettier --write,
#     ruff format, gofmt -w, cargo fmt. A tool that is not installed is a note,
#     the others still run.
#   - commits the changed files only, with --no-verify: the hooks would refuse the
#     commit over the errors that are left, and those are reported instead
#   - checks again and prints what is left as "!" lines
#
# Re-running is safe: with nothing left to fix it makes no commit. Exit 2 only when
# the commit itself fails; the fixes then stay in the working tree.

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
PROJECT_ROOT="${CLAUDE_PROJECT_DIR:-$(pwd)}"
CONFIG="$PROJECT_ROOT/.pre-commit-config.yaml"
MARKER="# Written by /fwd:setup-review."
# The files this skill writes itself: they go into the setup commit, not this one.
OWN='^(\.pre-commit-config\.yaml|\.claude/fwd/.*|\.github/workflows/fwd-(review|osv-weekly)\.yml)$'
SUBJECT="style: apply the project's formatters and lint autofixes"
MAX_LEFT=30

if ! git -C "$PROJECT_ROOT" rev-parse --git-dir >/dev/null 2>&1; then
    echo "↷ not a git repository, nothing fixed"
    exit 0
fi

if [[ ! -f "$CONFIG" || "$(head -n 1 "$CONFIG")" != "$MARKER"* ]]; then
    echo "↷ .pre-commit-config.yaml was not written by /fwd:setup-review, nothing fixed → run \`pre-commit run --all-files\` to see what fails"
    exit 0
fi

dirty="$(git -C "$PROJECT_ROOT" status --porcelain --untracked-files=no | cut -c4- | grep -vE "$OWN" || true)"
if [[ -n "$dirty" ]]; then
    echo "↷ uncommitted changes in tracked files, nothing fixed → commit or stash them, then re-run /fwd:setup-review"
    exit 0
fi

# shellcheck source=../lib/stack.sh
source "$SCRIPT_DIR/../lib/stack.sh"
JS_RUNNER="$(js_runner)"

ESLINT_RE='\.(js|jsx|mjs|cjs|ts|tsx|mts|cts)$'
PRETTIER_RE='\.(js|jsx|mjs|cjs|ts|tsx|mts|cts|css|scss)$'
PYTHON_RE='\.(py|pyi)$'
GO_RE='\.go$'

has_hook() { grep -qE "^ *- id: $1\$" "$CONFIG"; }

# tracked <regex> → true when git tracks a file that matches.
tracked() { git -C "$PROJECT_ROOT" ls-files | grep -qE "$1"; }

# on_tracked <regex> <command>... → runs the command over every tracked file that
# matches, in batches. Never fails: what is left is found by the check afterwards.
on_tracked() {
    local re="$1"; shift
    (cd "$PROJECT_ROOT" && git ls-files -z | grep -zE "$re" | xargs -0 "$@") || true
}

NOTES=()
LEFT="$(mktemp)"
trap 'rm -f "$LEFT"' EXIT

# left <tool> <command>... → runs a check over the repo and adds each non-empty line
# it prints to the leftovers, prefixed with the tool, paths relative to the repo.
left() {
    local tool="$1" line; shift
    (cd "$PROJECT_ROOT" && "$@" 2>&1 || true) | while IFS= read -r line; do
        [[ -n "${line//[[:space:]]/}" ]] && printf '%s: %s\n' "$tool" "${line//"$PROJECT_ROOT/"/}"
    done >>"$LEFT" || true
}

js_tool_ok() { (cd "$PROJECT_ROOT" && $JS_RUNNER "$1" --version) >/dev/null 2>&1; }

# ── Fix ───────────────────────────────────────────────────────────────────────

# ESLint before Prettier, so Prettier has the last word on layout.
ESLINT_OK=false; PRETTIER_OK=false
if has_hook eslint && tracked "$ESLINT_RE"; then
    if js_tool_ok eslint; then
        ESLINT_OK=true
        on_tracked "$ESLINT_RE" $JS_RUNNER eslint --fix >/dev/null 2>&1
    else
        NOTES+=("ESLint is not installed in this checkout; run the package manager's install, then re-run /fwd:setup-review")
    fi
fi
if has_hook prettier && tracked "$PRETTIER_RE"; then
    if js_tool_ok prettier; then
        PRETTIER_OK=true
        on_tracked "$PRETTIER_RE" $JS_RUNNER prettier --write --ignore-unknown >/dev/null 2>&1
    else
        NOTES+=("Prettier is not installed in this checkout; run the package manager's install, then re-run /fwd:setup-review")
    fi
fi

RUFF=""
if has_hook ruff-format && tracked "$PYTHON_RE"; then
    if command -v ruff >/dev/null 2>&1; then
        RUFF="ruff"
    elif command -v uvx >/dev/null 2>&1; then
        RUFF="uvx ruff@${RUFF_REV#v}"
    else
        NOTES+=("ruff and uv are both missing, Python was not formatted")
    fi
    [[ -z "$RUFF" ]] || on_tracked "$PYTHON_RE" $RUFF format >/dev/null 2>&1
fi

GOFMT=false
if has_hook gofmt && tracked "$GO_RE"; then
    if command -v gofmt >/dev/null 2>&1; then
        GOFMT=true
        on_tracked "$GO_RE" gofmt -w >/dev/null 2>&1
    else
        NOTES+=("gofmt is not installed, Go was not formatted")
    fi
fi

CARGO=false
if has_hook cargo-fmt; then
    if command -v cargo >/dev/null 2>&1; then
        CARGO=true
        (cd "$PROJECT_ROOT" && cargo fmt --all) >/dev/null 2>&1 || true
    else
        NOTES+=("cargo is not installed, Rust was not formatted")
    fi
fi

# ── Commit what changed ───────────────────────────────────────────────────────

changed="$(git -C "$PROJECT_ROOT" diff --name-only | grep -cvE "$OWN" || true)"
if [[ "$changed" -eq 0 ]]; then
    echo "↷ nothing to fix: the formatters and autofixes changed no file"
else
    # Only the fixed files: the setup files are not committed here, and anything
    # staged earlier stays staged.
    if ! err="$(git -C "$PROJECT_ROOT" diff -z --name-only | grep -zvE "$OWN" |
        git -C "$PROJECT_ROOT" commit -q --no-verify \
            -m "$SUBJECT" \
            -m "Written by /fwd:setup-review before its checks go live, so the first pull request is not red over code it did not touch." \
            --pathspec-from-file=- --pathspec-file-nul 2>&1)"; then
        echo "⚠  The fixes are in the working tree, but committing them failed:" >&2
        printf '%s\n' "$err" | sed 's/^/   /' >&2
        echo "   Commit them by hand as a separate commit, then push them with the setup files." >&2
        exit 2
    fi
    echo "✔ $changed files fixed by the project's formatters and autofixes, committed separately → $(git -C "$PROJECT_ROOT" rev-parse --short HEAD) $SUBJECT"
fi

for n in ${NOTES[@]+"${NOTES[@]}"}; do
    echo "  ($n)"
done

# ── Check what is left ────────────────────────────────────────────────────────

$ESLINT_OK && left eslint on_tracked "$ESLINT_RE" $JS_RUNNER eslint --quiet
$PRETTIER_OK && left prettier on_tracked "$PRETTIER_RE" $JS_RUNNER prettier --list-different --ignore-unknown
[[ -z "$RUFF" ]] || left ruff on_tracked "$PYTHON_RE" $RUFF format --check
$GOFMT && left gofmt on_tracked "$GO_RE" gofmt -l
$CARGO && left cargo-fmt cargo fmt --all -- --check -l

total="$(wc -l <"$LEFT" | tr -d ' ')"
if [[ "$total" -gt 0 ]]; then
    echo "! still failing after the autofixes; fix these by hand, then commit:"
    head -n "$MAX_LEFT" "$LEFT" | sed 's/^/!   /'
    if [[ "$total" -gt "$MAX_LEFT" ]]; then
        echo "!   … $((total - MAX_LEFT)) more lines: run \`pre-commit run --all-files\` for all of them"
    fi
fi
