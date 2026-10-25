#!/usr/bin/env bash
# apply-all.sh - Run every fwd:setup-review installer (baseline last: it fixes and
# commits what the new checks would fail on) at --scope project and print a
# per-feature report (exit code + stdout + stderr), then the touched files git tracks.
#
# Usage:
#   apply-all.sh
#
# Never aborts on a single installer's non-zero exit — that failure is part
# of the report, not a reason to stop. Always exits 0 itself so callers can
# safely chain `&& <next step>` after it.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FEATURES=(precommit workflow review-flag baseline)

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

# These files go to the repo's other machines and to CI only once committed, so the
# report names the ones git already tracks (changed in the working tree now).
echo "### tracked"
ROOT="${CLAUDE_PROJECT_DIR:-$(pwd)}"
if git -C "$ROOT" rev-parse --git-dir >/dev/null 2>&1; then
    for f in .pre-commit-config.yaml .claude/fwd/review-push.sh .claude/fwd/plugin.json \
             .github/workflows/fwd-review.yml .github/workflows/fwd-osv-weekly.yml; do
        if git -C "$ROOT" ls-files --error-unmatch "$f" >/dev/null 2>&1; then
            echo "$f"
        fi
    done
fi
echo

exit 0
