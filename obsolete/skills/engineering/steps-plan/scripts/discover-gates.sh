#!/usr/bin/env bash
# Discover resolvable project gates (test / typecheck / lint / build) for Layer A
# of the validation contract. Only emits commands that actually resolve — a repo
# with no test script gets no test gate (rather than a gate that always fails).
# Stdout: JSON array of {id, name, command, expected_exit}. Empty array if none found.
set -euo pipefail

command -v jq >/dev/null 2>&1 || { echo "missing-jq — install jq (brew install jq)" >&2; exit 1; }
REPO_ROOT="$(rtk git rev-parse --show-toplevel)"
cd "$REPO_ROOT"

gates='[]'
add_gate() { # <name> <command>
  gates="$(jq --arg n "$1" --arg c "$2" \
    '. + [{id: ("G" + ((length + 1) | tostring)), name: $n, command: $c, expected_exit: 0}]' \
    <<<"$gates")"
}

if [[ -f package.json ]]; then
  PM=npm
  [[ -f pnpm-lock.yaml ]] && PM=pnpm
  [[ -f yarn.lock ]]      && PM=yarn
  [[ -f bun.lockb ]]      && PM=bun
  has_script() { jq -e --arg k "$1" '(.scripts // {})[$k] // empty' package.json >/dev/null 2>&1; }

  has_script test && add_gate test "$PM run test"
  if   has_script typecheck;  then add_gate typecheck "$PM run typecheck"
  elif has_script type-check; then add_gate typecheck "$PM run type-check"
  elif [[ -f tsconfig.json ]] && jq -e '((.devDependencies // {}) + (.dependencies // {})).typescript // empty' package.json >/dev/null 2>&1; then
       add_gate typecheck "$PM exec tsc --noEmit"
  fi
  has_script lint  && add_gate lint  "$PM run lint"
  has_script build && add_gate build "$PM run build"

elif [[ -f Cargo.toml ]] && command -v cargo >/dev/null 2>&1; then
  add_gate test  "cargo test"
  add_gate lint  "cargo clippy -- -D warnings"
  add_gate build "cargo build"

elif [[ -f go.mod ]] && command -v go >/dev/null 2>&1; then
  add_gate test  "go test ./..."
  add_gate typecheck "go vet ./..."
  add_gate build "go build ./..."

elif [[ -f pyproject.toml || -f setup.py || -f pytest.ini || -d tests ]]; then
  if command -v pytest >/dev/null 2>&1; then add_gate test "pytest -q"
  elif command -v python3 >/dev/null 2>&1; then add_gate test "python3 -m pytest -q"; fi
  command -v ruff  >/dev/null 2>&1 && add_gate lint "ruff check ."
  command -v mypy  >/dev/null 2>&1 && add_gate typecheck "mypy ."

elif [[ -f Makefile ]]; then
  for tgt in test lint build; do
    grep -Eq "^${tgt}:" Makefile && add_gate "$tgt" "make $tgt"
  done
fi

echo "$gates"
