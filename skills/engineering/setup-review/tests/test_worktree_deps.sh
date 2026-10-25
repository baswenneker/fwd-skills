#!/usr/bin/env bash
# worktree-deps.sh: installs from the lockfile on a new checkout without node_modules,
# and does nothing on a branch switch, with node_modules present, or without
# package.json. Always exits 0. Uses stub package managers, so it needs no network.
source "$(dirname "$0")/lib.sh"

HOOK="$SCRIPTS/precommit/payload/worktree-deps.sh"
NULL=0000000000000000000000000000000000000000
stub="$WORK/stub"
mkdir -p "$stub"
for pm in npm pnpm yarn; do
    printf '#!/usr/bin/env bash\necho "%s $*" >> "%s/calls"\n[[ ! -f "%s/fail" ]]\n' "$pm" "$WORK" "$WORK" > "$stub/$pm"
    chmod +x "$stub/$pm"
done

# run <dir> [from-ref] [checkout-type] → the hook's output; exit code in $code.
run() {
    : > "$WORK/calls"
    out="$(cd "$1" && PATH="$stub:$PATH" PRE_COMMIT_FROM_REF="${2:-$NULL}" PRE_COMMIT_CHECKOUT_TYPE="${3:-1}" bash "$HOOK")"
    code=$?
}

dir="$WORK/npm"; mkdir -p "$dir"
echo '{}' > "$dir/package.json"; echo '{}' > "$dir/package-lock.json"
run "$dir"
assert_eq "$code" 0 "npm: exits 0"
assert_eq "$(cat "$WORK/calls")" "npm ci" "npm: installs with npm ci"
assert_contains "$out" "npm ci" "npm: says what it runs"

run "$dir" 1234567890abcdef1234567890abcdef12345678
assert_eq "$(cat "$WORK/calls")" "" "branch switch: nothing installed"
run "$dir" "$NULL" 0
assert_eq "$(cat "$WORK/calls")" "" "file checkout: nothing installed"
mkdir "$dir/node_modules"; run "$dir"
assert_eq "$(cat "$WORK/calls")" "" "node_modules present: nothing installed"

dir="$WORK/pnpm"; mkdir -p "$dir"
echo '{}' > "$dir/package.json"; : > "$dir/pnpm-lock.yaml"
run "$dir"
assert_eq "$(cat "$WORK/calls")" "pnpm install --frozen-lockfile" "pnpm lockfile"

dir="$WORK/berry"; mkdir -p "$dir"
echo '{}' > "$dir/package.json"; : > "$dir/yarn.lock"; : > "$dir/.yarnrc.yml"
run "$dir"
assert_eq "$(cat "$WORK/calls")" "yarn install --immutable" "Yarn 2+"
: > "$dir/.pnp.cjs"; run "$dir"
assert_eq "$(cat "$WORK/calls")" "" "Yarn PnP installed: nothing installed"

dir="$WORK/classic"; mkdir -p "$dir"
echo '{}' > "$dir/package.json"; : > "$dir/yarn.lock"
run "$dir"
assert_eq "$(cat "$WORK/calls")" "yarn install --frozen-lockfile" "Yarn 1"

dir="$WORK/nolock"; mkdir -p "$dir"
echo '{}' > "$dir/package.json"
run "$dir"
assert_eq "$code" 0 "no lockfile: exits 0"
assert_eq "$(cat "$WORK/calls")" "" "no lockfile: nothing installed"
assert_contains "$out" "no lockfile" "no lockfile: says so"

dir="$WORK/nopkg"; mkdir -p "$dir"
run "$dir"
assert_eq "$(cat "$WORK/calls")$out" "" "no package.json: silent"

dir="$WORK/fails"; mkdir -p "$dir"
echo '{}' > "$dir/package.json"; echo '{}' > "$dir/package-lock.json"
touch "$WORK/fail"; run "$dir"; rm "$WORK/fail"
assert_eq "$code" 0 "failed install: exits 0"
assert_contains "$out" "failed" "failed install: says so"

# No package manager on PATH: says which one is missing.
bare="$WORK/bare-bin"; mkdir -p "$bare"
ln -sf "$(command -v bash)" "$bare/bash"
out="$(cd "$dir" && PATH="$bare" PRE_COMMIT_FROM_REF="$NULL" PRE_COMMIT_CHECKOUT_TYPE=1 bash "$HOOK")"; code=$?
assert_eq "$code" 0 "no npm: exits 0"
assert_contains "$out" "npm is not installed" "no npm: says so"

finish
