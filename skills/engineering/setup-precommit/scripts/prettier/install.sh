#!/usr/bin/env bash
# install.sh - Give a JS/TS repo without Prettier a Prettier baseline, so the
# pre-commit Prettier hook formats only what a commit changes instead of
# rewriting every file it touches.
#
# Usage:
#   install.sh --scope project
#
# Behavior, only when the repo has web files and neither a Prettier config nor
# Prettier in package.json:
#   1. writes .prettierrc.json: printWidth 120, singleQuote when the code
#      mostly uses single quotes;
#   2. formats every tracked file the Prettier hook covers and commits that,
#      with the config, as "style: format with Prettier" (--no-verify: the
#      commit only formats);
#   3. when that commit changed code, adds its id to .git-blame-ignore-revs
#      (GitHub reads it; `blame.ignoreRevsFile` makes local git blame read it)
#      and commits that as a second commit.
#   Otherwise it prints a skip line (↷) and changes nothing.
#
# Exit 2, before it changes anything, when the tracked files have changes, when
# HEAD is not on a branch or has no commit, when a merge or rebase is under way,
# or when npx is missing. Exit 2 after a Prettier failure, with the files
# restored. The precommit installer runs next and adds the Prettier hook only
# when a Prettier config exists, so a refusal here leaves the hook out.

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
    echo "install: --scope must be 'project' (the formatting belongs to one repo)" >&2
    exit 64
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="${CLAUDE_PROJECT_DIR:-$(pwd)}"
RC=".prettierrc.json"
IGNORE_REVS=".git-blame-ignore-revs"

if ! git -C "$PROJECT_ROOT" rev-parse --git-dir >/dev/null 2>&1; then
    echo "↷ not a git repository, no Prettier baseline"
    exit 0
fi

# shellcheck source=../lib/stack.sh
source "$SCRIPT_DIR/../lib/stack.sh"
require_jq

if ! has_file "$WEB_MARKERS" && ! root_has package.json; then
    echo "↷ no JS, TS, CSS or HTML files, no Prettier needed"
    exit 0
fi
if has_biome; then
    echo "↷ the repo formats with Biome (biome.json), no Prettier next to it"
    exit 0
fi
if has_prettier_config; then
    echo "↷ the repo has a Prettier config already, left alone"
    exit 0
fi
if root_has package.json && pkg_has_dep prettier; then
    echo "↷ package.json lists Prettier, so the project's own Prettier formats; no baseline written"
    exit 0
fi

g() { git -C "$PROJECT_ROOT" "$@"; }

refuse() {
    echo "⚠  No Prettier baseline: $1" >&2
    echo "   Without it the pre-commit config leaves Prettier out. $2 Then re-run /fwd:setup-precommit." >&2
    exit 2
}

if [[ -n "$(g status --porcelain --untracked-files=no)" ]]; then
    refuse "tracked files have uncommitted changes, and the formatting commit must hold only formatting." "Commit or stash them first."
fi
if ! g rev-parse -q --verify HEAD >/dev/null; then
    refuse "the repo has no commit yet." "Make a first commit."
fi
if ! g symbolic-ref -q HEAD >/dev/null; then
    refuse "HEAD is not on a branch." "Switch to the branch that should get the formatting commit."
fi
for state in MERGE_HEAD rebase-merge rebase-apply CHERRY_PICK_HEAD; do
    if [[ -e "$(g rev-parse --git-path "$state")" ]]; then
        refuse "a merge, rebase or cherry-pick is under way." "Finish or abort it."
    fi
done

PRETTIER_CMD="${FWD_PRETTIER_CMD:-npx --yes prettier@${PRETTIER_REV#v}}"
if [[ -z "${FWD_PRETTIER_CMD:-}" ]] && ! command -v npx >/dev/null 2>&1; then
    refuse "npx is missing, so Prettier cannot run." "Install Node.js."
fi

# ── Write the config ──────────────────────────────────────────────────────────

# Single quotes when import lines mostly use them; Prettier's default is double.
quotes="$(cd "$PROJECT_ROOT" && { grep -E "$WEB_MARKERS" <<<"$FILES" || true; } | { grep -vE "$FIXER_EXCLUDE" || true; } |
    while IFS= read -r f; do if [[ -f "$f" ]]; then cat -- "$f"; fi; done |
    awk "/(from|import|require\\() *'/ { s++ } /(from|import|require\\() *\"/ { d++ }
         END { print (s > d) ? \"true\" : \"false\" }")"

jq -n --argjson w "$PRETTIER_PRINT_WIDTH" --argjson q "$quotes" \
    '{printWidth: $w, singleQuote: $q}' >"$PROJECT_ROOT/$RC"

# ── Format the tracked files ──────────────────────────────────────────────────

files=()
while IFS= read -r -d '' f; do
    if [[ "$f" =~ $PRETTIER_FILE_MARKERS && ! "$f" =~ $FIXER_EXCLUDE && -f "$PROJECT_ROOT/$f" ]]; then files+=("$f"); fi
done < <(g ls-files -z)
files+=("$RC")

restore() {
    g checkout -q -- .
    rm -f "$PROJECT_ROOT/$RC"
}

# Prettier is not always stable in one pass: some long expressions get their
# final layout only on the second run. Run it until nothing changes (at most 4
# passes), or the next commit of such a file would carry formatting again.
state() { { g diff; cat "$PROJECT_ROOT/$RC"; } | git hash-object --stdin; }
stable=false
for _ in 1 2 3 4; do
    before="$(state)"
    # Word splitting of PRETTIER_CMD is intended: it is a command with arguments.
    # shellcheck disable=SC2086
    if ! out="$(cd "$PROJECT_ROOT" && printf '%s\0' "${files[@]}" |
        xargs -0 $PRETTIER_CMD --write --ignore-unknown --log-level warn 2>&1)"; then
        restore
        echo "⚠  Prettier failed, every file is restored and no baseline was written:" >&2
        printf '%s\n' "$out" | head -n 20 | sed 's/^/   /' >&2
        echo "   Fix the file it names (often a syntax error), then re-run /fwd:setup-precommit." >&2
        exit 2
    fi
    if [[ "$(state)" == "$before" ]]; then stable=true; break; fi
done
if ! $stable; then
    restore
    echo "⚠  Prettier kept changing files after 4 passes; every file is restored and no baseline was written." >&2
    echo "   Run Prettier by hand to find the file, then re-run /fwd:setup-precommit." >&2
    exit 2
fi

changed="$(g diff --name-only | grep -c . || true)"
g add -A -- "$RC" "${files[@]}"
g commit -q --no-verify -m "style: format with Prettier" \
    -m "One-off baseline from /fwd:setup-precommit: $RC (printWidth $PRETTIER_PRINT_WIDTH) and every tracked file Prettier covers. Formatting only."

if [[ "$changed" -eq 0 ]]; then
    echo "✔ $RC written; the code already matched it, nothing else changed → $PROJECT_ROOT/$RC"
    exit 0
fi

sha="$(g rev-parse HEAD)"
header=""
[[ -s "$PROJECT_ROOT/$IGNORE_REVS" ]] || header="# Commits git blame skips (GitHub reads this file; locally: git config blame.ignoreRevsFile $IGNORE_REVS)."
{
    [[ -z "$header" ]] || echo "$header"
    echo "# style: format with Prettier (/fwd:setup-precommit)"
    echo "$sha"
} >>"$PROJECT_ROOT/$IGNORE_REVS"
g config blame.ignoreRevsFile "$IGNORE_REVS"
g add -- "$IGNORE_REVS"
g commit -q --no-verify -m "chore: skip the Prettier formatting commit in git blame"

echo "✔ $changed files formatted in commit ${sha:0:8}, $IGNORE_REVS updated → $PROJECT_ROOT/$RC"
echo "Branches that started before commit ${sha:0:8} get merge conflicts in the files it reformatted: merge them first, or run Prettier on them before merging." >&2
