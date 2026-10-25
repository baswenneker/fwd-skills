#!/usr/bin/env bash
# install.sh - Remove what the retired /fwd:setup-review left in the repo: its two
# GitHub Actions workflows, the push hook that called the Workcenter reviewer, and
# "review": true in .claude/fwd/plugin.json.
#
# Usage:
#   install.sh --scope project
#
# Only removes files that carry setup-review's own first lines, so a workflow the
# repo wrote under the same name stays. Other keys in plugin.json stay; the file
# goes only when "review" was its last key. Idempotent: nothing left → no change.

set -euo pipefail

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
    echo "install: --scope must be 'project' (the leftovers belong to one repo)" >&2
    exit 64
fi

PROJECT_ROOT="${CLAUDE_PROJECT_DIR:-$(pwd)}"
OLD_MARKER="# Written by /fwd:setup-review."
removed=0

for wf in fwd-review.yml fwd-osv-weekly.yml; do
    f="$PROJECT_ROOT/.github/workflows/$wf"
    if [[ -f "$f" && "$(head -n 1 "$f")" == "$OLD_MARKER"* ]]; then
        rm -f "$f"
        echo "✔ removed → $f"
        removed=$((removed + 1))
    fi
done
rmdir "$PROJECT_ROOT/.github/workflows" "$PROJECT_ROOT/.github" 2>/dev/null || true

push="$PROJECT_ROOT/.claude/fwd/review-push.sh"
if [[ -f "$push" ]] && sed -n 2p "$push" | grep -q 'installed by /fwd:setup-review'; then
    rm -f "$push"
    echo "✔ removed → $push"
    removed=$((removed + 1))
fi

flag="$PROJECT_ROOT/.claude/fwd/plugin.json"
if [[ -f "$flag" ]] && command -v jq >/dev/null 2>&1 &&
    jq -e 'type == "object" and has("review")' "$flag" >/dev/null 2>&1; then
    if jq -e 'del(.review) == {}' "$flag" >/dev/null; then
        rm -f "$flag"
        echo "✔ removed (review was its only key) → $flag"
    else
        tmp="$(mktemp "$flag.XXXXXX")"
        jq 'del(.review)' "$flag" > "$tmp" && mv "$tmp" "$flag"
        echo "✔ review key removed → $flag"
    fi
    removed=$((removed + 1))
fi
rmdir "$PROJECT_ROOT/.claude/fwd" 2>/dev/null || true

if [[ $removed -eq 0 ]]; then
    echo "✔ nothing left from /fwd:setup-review, no change"
fi
