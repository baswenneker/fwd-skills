#!/usr/bin/env bash
# stack.sh - Pinned hook versions and what the repo is made of. Source it after
# setting PROJECT_ROOT.
#
# Sets FILES (every path git would see: tracked plus untracked-but-not-ignored) and
# defines has_file, root_has, pkg_has_dep and js_runner.
#
# Plain git, not `rtk git` (this skill's deliberate exception to the repo rule, see
# CLAUDE.md): these scripts run in other people's repos, where rtk may be missing, and
# a missing rtk would read as "not a git repository". No git output reaches Claude.

# Pinned hook versions. Raise them here; a re-run of /fwd:setup-precommit rewrites
# the config it owns with the new ones.
PRE_COMMIT_HOOKS_REV="v6.0.0"
GITLEAKS_REV="v8.30.1"
OSV_REV="v2.6.0"
CONVENTIONAL_REV="v4.4.0"
RUFF_REV="v0.16.10"
SHFMT_REV="v3.14.1-1"
SHELLCHECK_REV="v0.11.0.1"
ACTIONLINT_REV="v1.7.12"
HADOLINT_REV="v2.15.1"
PRETTIER_REV="v3.9.10"

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
SHELL_MARKERS='\.(sh|bash)$'
WEB_MARKERS='\.(js|jsx|mjs|cjs|ts|tsx|mts|cts|css|scss|html|vue|svelte)$'
WORKFLOW_MARKERS='^\.github/workflows/[^/]+\.ya?ml$'
DOCKER_MARKERS='(^|/)(Dockerfile|Containerfile)[^/]*$|\.[Dd]ockerfile$'
# The files osv-scanner reads. Without one it exits 128 ("no packages found"),
# which would block every push.
LOCKFILE_MARKERS='(^|/)(package-lock\.json|npm-shrinkwrap\.json|yarn\.lock|pnpm-lock\.yaml|bun\.lock|uv\.lock|poetry\.lock|Pipfile\.lock|pdm\.lock|pylock\.toml|requirements[^/]*\.txt|go\.mod|Cargo\.lock|Gemfile\.lock|composer\.lock|pom\.xml|gradle\.lockfile|packages\.lock\.json|pubspec\.lock|mix\.lock)$'

pkg_has_dep() {
    jq -e --arg d "$1" '[.dependencies, .devDependencies] | map(. // {} | has($d)) | any' \
        "$PROJECT_ROOT/package.json" >/dev/null 2>&1
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

# The indent the repo's shell scripts already use, as a shfmt -i value: 0 for tabs,
# else the smallest space indent found. Without it shfmt would re-indent every
# script it touches to tabs.
shell_indent() {
    local files
    files="$(grep -E "$SHELL_MARKERS" <<<"$FILES" || true)"
    [[ -n "$files" ]] || { echo 4; return; }
    (cd "$PROJECT_ROOT" && while IFS= read -r f; do [[ -f "$f" ]] && cat -- "$f"; done <<<"$files") |
        awk '/^\t/ { tabs++; next }
             /^ +[^ ]/ { match($0, /^ +/); n = RLENGTH; if (n > 1 && (min == 0 || n < min)) min = n; spaces++ }
             END { if (tabs > spaces) print 0; else if (min == 2 || min == 4) print min; else print 4 }'
}

require_jq() {
    if ! command -v jq >/dev/null 2>&1; then
        echo "⚠  jq is not installed; it is needed to read package.json and .claude/fwd/plugin.json. Install jq and re-run /fwd:setup-precommit." >&2
        exit 2
    fi
}
