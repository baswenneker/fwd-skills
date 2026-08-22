#!/usr/bin/env bash
# apply-all.sh - Run every fwd:setup installer at --scope project and print
# a per-feature report (exit code + stdout + stderr).
#
# Usage:
#   apply-all.sh
#
# Never aborts on a single installer's non-zero exit — that failure is part
# of the report, not a reason to stop. Always exits 0 itself so callers can
# safely chain `&& <next step>` after it.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FEATURES=(smartlint lessons gitignore clear-context-on-plan no-attribution)

for feature in "${FEATURES[@]}"; do
    stdout_file="$(mktemp)"
    stderr_file="$(mktemp)"

    bash "$SCRIPT_DIR/${feature}/install.sh" --scope project >"$stdout_file" 2>"$stderr_file"
    code=$?

    echo "### ${feature}"
    echo "exit=${code}"
    echo "stdout:"
    cat "$stdout_file"
    echo "stderr:"
    cat "$stderr_file"
    echo

    rm -f "$stdout_file" "$stderr_file"
done

# Which of the files we may have touched are under version control? Those changes
# land in someone else's merge request unless the user decides otherwise, so the
# report must name them. Silent on a repo where none are tracked.
echo "### tracked"
if rtk git rev-parse --git-dir >/dev/null 2>&1; then
    for f in CLAUDE.md .gitignore .claude/settings.local.json; do
        if rtk git ls-files --error-unmatch "$f" >/dev/null 2>&1; then
            echo "$f"
        fi
    done
fi
echo

exit 0
