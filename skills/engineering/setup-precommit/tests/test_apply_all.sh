#!/usr/bin/env bash
# apply-all: one report block per feature in a fixed order, exit 0, and a second run
# changes nothing. Also: fwd:setup names fwd:setup-precommit in its follow-up block
# while the repo has no pre-commit config, or has one whose hook is not installed.
source "$(dirname "$0")/lib.sh"

stub="$WORK/stub"
mkdir -p "$stub"
printf '#!/usr/bin/env bash\nexit 0\n' > "$stub/pre-commit"
chmod +x "$stub/pre-commit"
export PATH="$stub:$PATH"

repo="$(make_repo apply)"
cd "$repo"
out="$(bash "$SCRIPTS/apply-all.sh")"; code=$?
assert_eq "$code" 0 "apply-all exits 0"
order="$(printf '%s\n' "$out" | sed -n 's/^### //p' | tr '\n' ' ')"
assert_eq "$order" "precommit readme legacy tracked " "feature blocks in order"
assert_eq "$(printf '%s\n' "$out" | grep -c '^exit=0$')" 3 "every feature exit 0"

before="$(snapshot "$repo")"
bash "$SCRIPTS/apply-all.sh" >/dev/null
assert_eq "$(snapshot "$repo")" "$before" "second run changes nothing"

git add -A && git commit -q -m setup --no-verify
out="$(bash "$SCRIPTS/apply-all.sh")"
tracked="$(printf '%s\n' "$out" | sed -n '/^### tracked/,$p')"
assert_contains "$tracked" ".pre-commit-config.yaml" "tracked block lists the config"
assert_contains "$tracked" "README.md" "tracked block lists the README"

# ── fwd:setup follow-up ───────────────────────────────────────────────────────
home="$WORK/home"
mkdir -p "$home"
setup_followup() {
    CLAUDE_PROJECT_DIR="$1" HOME="$home" CLAUDE_CONFIG_DIR="$home/.claude" \
        bash "$SETUP_SCRIPTS/apply-all.sh" | sed -n '/^### followup/,$p'
}
fresh="$(make_repo followup)"
assert_contains "$(cd "$fresh" && setup_followup "$fresh")" "setup-precommit" "fwd:setup names setup-precommit without a config"

# A fresh clone: the config is there, the hook is not.
clone="$WORK/clone"
git clone -q "$repo" "$clone"
assert_contains "$(cd "$clone" && setup_followup "$clone")" "setup-precommit" "fwd:setup names setup-precommit when the hook is missing"

touch "$clone/.git/hooks/pre-commit"
assert_not_contains "$(cd "$clone" && setup_followup "$clone")" "setup-precommit" "fwd:setup stays quiet once the hook is installed"

finish
