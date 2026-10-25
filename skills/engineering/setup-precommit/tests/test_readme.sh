#!/usr/bin/env bash
# readme: a marker-bracketed "Git hooks" section that tells the next clone to run
# `pre-commit install`; idempotent, osv-scanner line only when that hook is there,
# and nothing at all next to a config the repo wrote itself.
source "$(dirname "$0")/lib.sh"

our_config() {
    printf '# Written by /fwd:setup-precommit. A re-run rewrites this file.\nrepos: []\n%s' "${1:-}" > .pre-commit-config.yaml
}

repo="$(make_repo readme)"
cd "$repo"
our_config
out="$(bash "$SCRIPTS/readme/install.sh" --scope project)"; code=$?
assert_eq "$code" 0 "readme exits 0"
readme="$(cat README.md)"
assert_contains "$readme" "# widget" "existing README content kept"
assert_contains "$readme" "<!-- fwd:setup-precommit:start -->" "section is marker-bracketed"
assert_contains "$readme" "pre-commit install" "section says how to turn the hooks on"
assert_not_contains "$readme" "osv-scanner" "no push line without the osv-scanner hook"
assert_contains "$out" "→" "stdout names the file"

before="$(snapshot "$repo")"
out="$(bash "$SCRIPTS/readme/install.sh" --scope project)"
assert_eq "$(snapshot "$repo")" "$before" "re-run changes no file"
assert_contains "$out" "no change" "re-run says nothing changed"

our_config '      - id: osv-scanner\n'
bash "$SCRIPTS/readme/install.sh" --scope project >/dev/null
readme="$(cat README.md)"
assert_contains "$readme" "osv-scanner blocks the push" "push line once osv-scanner is configured"
assert_eq "$(grep -c 'fwd:setup-precommit:start' README.md)" 1 "section refreshed, not added twice"

# No README yet: one is created.
repo="$(make_repo noreadme)"
cd "$repo"
git rm -q README.md
our_config
bash "$SCRIPTS/readme/install.sh" --scope project >/dev/null
assert_contains "$(cat README.md)" "pre-commit install" "README created with the section"

# A config the repo wrote: the section would describe hooks that are not there.
repo="$(make_repo foreign)"
cd "$repo"
printf 'repos: []\n' > .pre-commit-config.yaml
out="$(bash "$SCRIPTS/readme/install.sh" --scope project)"; code=$?
assert_eq "$code" 0 "foreign config exits 0"
assert_contains "$out" "↷" "foreign config skipped"
assert_eq "$(cat README.md)" "# widget" "README untouched next to a foreign config"

finish
