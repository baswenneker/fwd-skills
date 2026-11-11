#!/usr/bin/env bash
# apply-all.sh - Run every fwd:setup-precommit installer at --scope project and print
# a per-feature report (exit code + stdout + stderr), then the touched files git tracks.
#
# Usage:
#   apply-all.sh
#
# Never aborts on a single installer's non-zero exit — that failure is part
# of the report, not a reason to stop. Always exits 0 itself so callers can
# safely chain `&& <next step>` after it.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# prettier before precommit: the config adds the Prettier hook only once a
# Prettier config exists.
FEATURES=(prettier precommit readme legacy)

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

# These files reach the repo's other clones only once committed, so the report
# names the tracked ones that now differ from HEAD. A tracked file an idempotent
# re-run left byte-identical is not listed: the report would claim a change the
# working tree does not show.
echo "### tracked"
ROOT="${CLAUDE_PROJECT_DIR:-$(pwd)}"
if git -C "$ROOT" rev-parse --git-dir >/dev/null 2>&1; then
    for f in .pre-commit-config.yaml README.md; do
        if git -C "$ROOT" ls-files --error-unmatch "$f" >/dev/null 2>&1 &&
            ! git -C "$ROOT" diff --quiet HEAD -- "$f" 2>/dev/null; then
            echo "$f"
        fi
    done
fi
echo

exit 0
