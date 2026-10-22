#!/usr/bin/env bash
# stack.sh - Shared by the precommit and workflow installers: pinned versions and
# what the repo is made of. Source it after setting PROJECT_ROOT.
#
# Sets FILES (every path git would see: tracked plus untracked-but-not-ignored) and
# defines has_file, root_has, pkg_has_dep, pkg_has_script and js_runner.
#
# Plain git, not `rtk git` (this skill's deliberate exception to the repo rule, see
# CLAUDE.md): these scripts run in other people's repos, where rtk may be missing, and
# a missing rtk would read as "not a git repository". No git output reaches Claude.

# Pinned versions. Raise them here; repos with a config already pick new hook
# versions up with `pre-commit autoupdate`. The gitleaks checksum is the linux_x64
# line of the release's gitleaks_<version>_checksums.txt.
GITLEAKS_VERSION="8.30.1"
GITLEAKS_SHA256="551f6fc83ea457d62a0d98237cbad105af8d557003051f41f3e7ca7b3f2470eb"
RUFF_REV="v0.16.10"
PRE_COMMIT_VERSION="4.6.2"
OSV_REF="v2.6.0"
SETUP_UV_REF="v10.2.0"

if git -C "$PROJECT_ROOT" rev-parse --git-dir >/dev/null 2>&1; then
    FILES="$(git -C "$PROJECT_ROOT" ls-files --cached --others --exclude-standard)"
else
    FILES="$(cd "$PROJECT_ROOT" && find . -type f ! -path './.git/*' | sed 's|^\./||')"
fi

# A here-string, not `printf | grep -q`: grep -q stops at the first match, and under
# pipefail the printf that then gets SIGPIPE would turn a match into a miss.
has_file() { grep -qE "$1" <<<"$FILES"; }
root_has() { [[ -f "$PROJECT_ROOT/$1" ]]; }

PYTHON_MARKERS='(^|/)(pyproject\.toml|setup\.py|requirements[^/]*\.txt)$|\.py$'

pkg_has_dep() {
    jq -e --arg d "$1" '[.dependencies, .devDependencies] | map(. // {} | has($d)) | any' \
        "$PROJECT_ROOT/package.json" >/dev/null 2>&1
}
pkg_has_script() {
    jq -e --arg s "$1" '.scripts[$s] // empty' "$PROJECT_ROOT/package.json" >/dev/null 2>&1
}

# How to run the project's own Prettier/ESLint. Yarn Plug'n'Play has no node_modules,
# so npx cannot find them there; `yarn` can.
js_runner() {
    if root_has .yarnrc.yml && ! grep -qE '^nodeLinker: *"?node-modules' "$PROJECT_ROOT/.yarnrc.yml"; then
        echo "yarn"
    else
        echo "npx --no-install"
    fi
}

require_jq() {
    if ! command -v jq >/dev/null 2>&1; then
        echo "⚠  jq is not installed; it is needed to read package.json and .claude/fwd/plugin.json. Install jq and re-run /fwd:setup-review." >&2
        exit 2
    fi
}
