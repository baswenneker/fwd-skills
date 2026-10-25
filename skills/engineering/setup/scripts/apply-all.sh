#!/usr/bin/env bash
# apply-all.sh - Run every fwd:setup installer and print a per-feature report
# (exit code + stdout + stderr). Most installers run at --scope project. The
# ones in USER_SCOPE run at --scope user: they shape how Claude works in every
# repo, so they belong in ~/.claude (CLAUDE.md rules, the RTK hook).
#
# Usage:
#   apply-all.sh
#
# Never aborts on a single installer's non-zero exit — that failure is part
# of the report, not a reason to stop. Always exits 0 itself so callers can
# safely chain `&& <next step>` after it.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FEATURES=(smartlint lessons gitignore clear-context-on-plan no-attribution grilling wait-loops codex-review next-steps rtk)
USER_SCOPE=" grilling wait-loops codex-review next-steps rtk "

for feature in "${FEATURES[@]}"; do
    stdout_file="$(mktemp)"
    stderr_file="$(mktemp)"

    scope=project
    [[ "$USER_SCOPE" == *" $feature "* ]] && scope=user

    bash "$SCRIPT_DIR/${feature}/install.sh" --scope "$scope" >"$stdout_file" 2>"$stderr_file"
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

# A follow-up the user may want to run by hand afterwards. Matt Pocock's engineering
# skills need their own per-repo configuration (issue tracker, triage labels, domain
# docs), and their setup skill is interactive — it cannot be chained into this
# unattended run, so the report only points at it. Silent unless that plugin is
# actually installed; an unmatched glob leaves the literal pattern, which is not a
# directory, so the loop prints nothing.
echo "### followup"
CONFIG_DIR="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
for candidate in "$CONFIG_DIR"/plugins/cache/*/mattpocock-skills/*/skills/*/setup-matt-pocock-skills; do
    if [[ -d "$candidate" ]]; then
        echo "mattpocock-setup"
        break
    fi
done
# fwd:setup-review (pre-commit, gitleaks, CI, the Workcenter reviewer hook) is a
# separate skill so it can run on its own; point at it while the repo has no
# pre-commit config yet.
if [[ ! -f "${CLAUDE_PROJECT_DIR:-$(pwd)}/.pre-commit-config.yaml" ]]; then
    echo "setup-review"
fi
echo

exit 0
