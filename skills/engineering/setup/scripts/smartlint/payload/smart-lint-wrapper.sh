#!/usr/bin/env bash
# smart-lint-wrapper.sh - Wrapper for smart-lint.sh that filters for modified and untracked files
#
# This script is designed to be called by the Stop hook.
# It detects modified files via git and runs smart-lint.sh only on relevant code files.
# With a transcript_path in the hook input, only files this session touched
# count. Content-hash caching prevents redundant runs when nothing changed,
# and an unchanged failing state blocks only once.
#
# Disable auto-lint by setting "smart-lint": false in .claude/fwd/plugin.json

# Read JSON input from stdin (Claude Code provides context via stdin for Stop hooks)
INPUT=$(cat)

# Loop protection: if stop_hook_active is true, a previous Stop hook already
# blocked Claude and the lint-fixer has run. Exit cleanly to avoid infinite loops.
STOP_HOOK_ACTIVE=$(echo "$INPUT" | jq -r '.stop_hook_active // false' 2>/dev/null)
if [ "$STOP_HOOK_ACTIVE" = "true" ]; then
    exit 0
fi

# Exit gracefully if not in a git repo. In a worktree .git is a file, not a
# directory, so ask git instead of testing for .git.
if [ "$(git rev-parse --is-inside-work-tree 2>/dev/null)" != "true" ]; then
    exit 0
fi

# Check if smart-lint is disabled in plugin.json
PLUGIN_JSON="${CLAUDE_PROJECT_DIR:-.}/.claude/fwd/plugin.json"
if [ -f "$PLUGIN_JSON" ]; then
    SMART_LINT_ENABLED=$(jq -r 'if .["smart-lint"] == false then "false" else "true" end' "$PLUGIN_JSON" 2>/dev/null)
    if [ "$SMART_LINT_ENABLED" = "false" ]; then
        exit 0
    fi
fi

# Portable hashing command (macOS vs Linux) -- needed for content caching
if command -v md5 &>/dev/null; then
    hash_cmd() { md5 -q; }
elif command -v md5sum &>/dev/null; then
    hash_cmd() { md5sum | cut -d' ' -f1; }
else
    hash_cmd() { cat; } # fallback: no hashing, always runs
fi

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# File lists are NUL-separated and kept in bash arrays, so a path with spaces
# stays one argument all the way to the linter.
RELEVANT_RE='\.(ts|tsx|py|js|jsx|nix|ipynb|sh)$'

# With a pre-commit config (here or at the git root), smart-lint.sh hands
# every changed file to pre-commit, whose hooks also cover JSON, YAML,
# Dockerfiles and more. Then every changed file is relevant.
GIT_ROOT=$(git rev-parse --show-toplevel 2>/dev/null)
if [ -f ".pre-commit-config.yaml" ] || [ -f "$GIT_ROOT/.pre-commit-config.yaml" ]; then
    RELEVANT_RE='.'
fi

# Untracked, then modified files (staged + unstaged changes), filtered for
# relevant code file extensions (no mapfile: bash 3.2 compatible). All paths
# are relative to the current directory and limited to it (--relative, and
# ls-files' default), so a session in a monorepo package lints that package.
UNTRACKED_RELEVANT=()
while IFS= read -r -d '' f; do
    [[ "$f" =~ $RELEVANT_RE ]] && UNTRACKED_RELEVANT+=("$f")
done < <(git ls-files -z --others --exclude-standard 2>/dev/null)

RELEVANT_FILES=()
while IFS= read -r -d '' f; do
    [[ "$f" =~ $RELEVANT_RE ]] && RELEVANT_FILES+=("$f")
done < <(
    {
        git diff -z --name-only --relative HEAD
        git diff -z --name-only --relative --cached
        printf '%s\0' "${UNTRACKED_RELEVANT[@]}"
    } 2>/dev/null | sort -zu
)

# Session scope: keep only files this session touched, so a session is never
# blocked on changes another session or process made in the same checkout.
# A file counts as touched when its path (relative to here) appears in an
# Edit, MultiEdit, Write or NotebookEdit path or in a Bash command, in the
# session's transcript or in one of its subagents' transcripts. Without a
# readable transcript every changed file counts, as before.
TRANSCRIPT=$(echo "$INPUT" | jq -r '.transcript_path // empty' 2>/dev/null)
if [ -n "$TRANSCRIPT" ] && [ -f "$TRANSCRIPT" ] && [ ${#RELEVANT_FILES[@]} -gt 0 ]; then
    TOUCHED=$(
        for t in "$TRANSCRIPT" "${TRANSCRIPT%.jsonl}"/subagents/*.jsonl; do
            [ -f "$t" ] && cat "$t"
        done | jq -r 'select(.type == "assistant") | .message.content[]?
      | select(.type == "tool_use")
      | if (.name | test("^(Edit|MultiEdit|Write|NotebookEdit)$"))
          then (.input.file_path // .input.notebook_path // empty)
        elif .name == "Bash" then (.input.command // empty)
        else empty end' 2>/dev/null
    )
    SESSION_FILES=()
    for f in "${RELEVANT_FILES[@]}"; do
        case "$TOUCHED" in *"$f"*) SESSION_FILES+=("$f") ;; esac
    done
    UNTRACKED_SESSION=()
    for f in "${UNTRACKED_RELEVANT[@]}"; do
        case "$TOUCHED" in *"$f"*) UNTRACKED_SESSION+=("$f") ;; esac
    done
    RELEVANT_FILES=()
    UNTRACKED_RELEVANT=()
    [ ${#SESSION_FILES[@]} -gt 0 ] && RELEVANT_FILES=("${SESSION_FILES[@]}")
    [ ${#UNTRACKED_SESSION[@]} -gt 0 ] && UNTRACKED_RELEVANT=("${UNTRACKED_SESSION[@]}")
fi

if [ ${#RELEVANT_FILES[@]} -eq 0 ]; then
    exit 0
fi

# --- Content hash caching: skip lint if nothing changed since last successful run ---

PROJECT_HASH=$(echo "$PWD" | hash_cmd)

# Build content fingerprint from:
# 1. The sorted list of relevant files
# 2. git diff HEAD for those files (unstaged + staged changes)
# 3. git diff --cached for those files (staged-only changes)
# 4. Contents of untracked relevant files
# --literal-pathspecs: a file name containing * or ? matches only itself.
CONTENT_HASH=$(
    {
        printf '%s\n' "${RELEVANT_FILES[@]}"
        git --literal-pathspecs diff HEAD -- "${RELEVANT_FILES[@]}" 2>/dev/null
        git --literal-pathspecs diff --cached -- "${RELEVANT_FILES[@]}" 2>/dev/null
        for f in ${UNTRACKED_RELEVANT[@]+"${UNTRACKED_RELEVANT[@]}"}; do
            [ -f "$f" ] && cat "$f"
        done
    } | hash_cmd
)

# Cache location: /tmp/claude/lint-cache/lint-{hash,fail}-<project-key>
CACHE_DIR="${CLAUDE_HOOKS_CACHE_DIR:-/tmp/claude/lint-cache}"
CACHE_FILE="$CACHE_DIR/lint-hash-$PROJECT_HASH"
FAIL_FILE="$CACHE_DIR/lint-fail-$PROJECT_HASH"

if [ -f "$CACHE_FILE" ] && [ "$(cat "$CACHE_FILE")" = "$CONTENT_HASH" ]; then
    exit 0
fi

# The same files failed last time and nothing changed since: the issues were
# already reported. Blocking again would only cost a turn per prompt, so tell
# the user in one line and let Claude stop.
if [ -f "$FAIL_FILE" ] && [ "$(cat "$FAIL_FILE")" = "$CONTENT_HASH" ]; then
    echo '{"systemMessage": "smart-lint: same issues as the previous check, no file changed since; not blocking again."}'
    exit 0
fi

# --- End caching check ---

# Run smart-lint.sh with specific files; its output is collected so it can be
# cleaned (no ANSI colour codes: Claude reads this) and capped.
OUTPUT=$(
    echo ""
    echo "Running lint checks on modified and untracked files:"
    printf '  - %s\n' "${RELEVANT_FILES[@]}"
    echo ""
    "$SCRIPT_DIR/smart-lint.sh" --files "${RELEVANT_FILES[@]}" 2>&1
    echo "__SMART_LINT_EXIT=$?"
)
EXIT_CODE=$(printf '%s\n' "$OUTPUT" | sed -n 's/^__SMART_LINT_EXIT=//p' | tail -n 1)
OUTPUT=$(printf '%s\n' "$OUTPUT" | grep -v '^__SMART_LINT_EXIT=' | sed $'s/\x1b\\[[0-9;]*m//g')

# cap_output: at most MAX_LINES lines; the cut is in the middle, because the
# first errors and the summary at the end matter most.
MAX_LINES="${CLAUDE_HOOKS_MAX_OUTPUT_LINES:-80}"
cap_output() {
    local total
    total=$(printf '%s\n' "$OUTPUT" | wc -l | tr -d ' ')
    if [ "$total" -le "$MAX_LINES" ]; then
        printf '%s\n' "$OUTPUT"
        return
    fi
    local tail_n=20
    local head_n=$((MAX_LINES - tail_n - 1))
    printf '%s\n' "$OUTPUT" | head -n "$head_n"
    echo "... ($((total - head_n - tail_n)) lines cut; run the failing check yourself for all of them) ..."
    printf '%s\n' "$OUTPUT" | tail -n "$tail_n"
}

mkdir -p "$CACHE_DIR"
case "$EXIT_CODE" in
    0)
        # Cache the hash only after a successful run, so lint re-runs next time
        # after exit 1 (missing deps) or 2 (lint issues).
        echo "$CONTENT_HASH" >"$CACHE_FILE"
        rm -f "$FAIL_FILE"
        printf '%s\n' "$OUTPUT"
        exit 0
        ;;
    2)
        echo "$CONTENT_HASH" >"$FAIL_FILE"
        cap_output >&2
        exit 2
        ;;
    *)
        cap_output >&2
        exit "${EXIT_CODE:-1}"
        ;;
esac
