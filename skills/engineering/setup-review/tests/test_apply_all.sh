#!/usr/bin/env bash
# apply-all: one report block per feature in a fixed order, exit 0 even on a
# collision, and a second run on a fresh repo changes nothing. Also: fwd:setup names
# fwd:setup-review in its follow-up block only while the repo has no pre-commit config.
source "$(dirname "$0")/lib.sh"

stub="$WORK/stub"
mkdir -p "$stub"
printf '#!/usr/bin/env bash\nexit 0\n' > "$stub/pre-commit"
chmod +x "$stub/pre-commit"
export PATH="$stub:$PATH"

repo="$(make_repo apply)"
cd "$repo"
echo '{"devDependencies": {"prettier": "^3"}}' > package.json
echo '{}' > package-lock.json

out="$(bash "$SCRIPTS/apply-all.sh")"; code=$?
assert_eq "$code" 0 "apply-all exits 0"
order="$(printf '%s\n' "$out" | sed -n 's/^### //p' | tr '\n' ' ')"
assert_eq "$order" "precommit workflow review-flag baseline tracked " "feature blocks in order"
assert_eq "$(printf '%s\n' "$out" | grep -c '^exit=0$')" 4 "every feature exit 0"

before="$(snapshot "$repo")"
bash "$SCRIPTS/apply-all.sh" >/dev/null
assert_eq "$(snapshot "$repo")" "$before" "second run changes nothing"

git add -A && git commit -q -m setup
out="$(bash "$SCRIPTS/apply-all.sh")"
tracked="$(printf '%s\n' "$out" | sed -n '/^### tracked/,$p')"
assert_contains "$tracked" ".pre-commit-config.yaml" "tracked block lists the config"
assert_contains "$tracked" ".claude/fwd/plugin.json" "tracked block lists the flag file"

# A collision does not stop the batch and does not change apply-all's exit code.
echo '{"review": false}' > .claude/fwd/plugin.json
out="$(bash "$SCRIPTS/apply-all.sh")"; code=$?
assert_eq "$code" 0 "apply-all exits 0 on a collision"
assert_contains "$out" "exit=2" "collision reported"

# ── fwd:setup follow-up ───────────────────────────────────────────────────────
home="$WORK/home"
mkdir -p "$home"
fresh="$(make_repo followup)"
cd "$fresh"
follow="$(CLAUDE_PROJECT_DIR="$fresh" HOME="$home" CLAUDE_CONFIG_DIR="$home/.claude" bash "$SETUP_SCRIPTS/apply-all.sh" | sed -n '/^### followup/,$p')"
assert_contains "$follow" "setup-review" "fwd:setup names setup-review without a pre-commit config"

follow="$(cd "$repo" && CLAUDE_PROJECT_DIR="$repo" HOME="$home" CLAUDE_CONFIG_DIR="$home/.claude" bash "$SETUP_SCRIPTS/apply-all.sh" | sed -n '/^### followup/,$p')"
assert_not_contains "$follow" "setup-review" "fwd:setup stays quiet once the config exists"

finish
