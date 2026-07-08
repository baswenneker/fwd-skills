#!/usr/bin/env bash
# Shared test harness for the fwd:steps-run scripts: assert helpers plus a throwaway
# git-fixture builder (a minimal steps-plan). Sourced by every test_*.sh file. No test
# framework dependency — plain bash, matching the repo's "bash only" rule.

# Resolve the scripts under test from this file's own location, so tests run from any cwd.
LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPTS_DIR="$(cd "$LIB_DIR/.." && pwd)/scripts"

# --- assert helpers -----------------------------------------------------------
# Each prints a diagnostic and aborts the current test file (exit 1) on failure, so a
# test file is green only when every assertion in it held.

assert_eq() { # expected actual [label]
  if [[ "$1" != "$2" ]]; then
    printf '  ✗ %s: expected [%s] got [%s]\n' "${3:-assert_eq}" "$1" "$2" >&2
    exit 1
  fi
}

assert_contains() { # haystack needle [label]
  if [[ "$1" != *"$2"* ]]; then
    printf '  ✗ %s: [%s] does not contain [%s]\n' "${3:-assert_contains}" "$1" "$2" >&2
    exit 1
  fi
}

assert_exit() { # expected-code actual-code [label]
  if [[ "$1" != "$2" ]]; then
    printf '  ✗ %s: expected exit %s got %s\n' "${3:-assert_exit}" "$1" "$2" >&2
    exit 1
  fi
}

# --- throwaway git fixture ----------------------------------------------------
# Build a minimal steps-plan repo in a temp dir and echo its path. The checkout is left
# on the steps/<slug> branch with .claude/steps/<slug>/{state.json,plan.md} committed, so
# both record-step.sh (reads the working tree) and status.sh (reads the branch via
# git show) operate on it unchanged. Temp dirs are removed when the sourcing file exits.

# All fixtures live under one per-process root so cleanup survives the command-substitution
# subshell that make_fixture runs in (a per-fixture array would be lost there). The trap ends
# in return 0 so a stale rm never flips the test file's exit status.
_FIXTURE_ROOT="$(mktemp -d)"
_cleanup_fixtures() { [[ -n "${_FIXTURE_ROOT:-}" ]] && rm -rf "$_FIXTURE_ROOT"; return 0; }
trap _cleanup_fixtures EXIT

_fixture_git_config() { # run inside a repo: give it an identity and skip signing
  rtk git config user.email test@example.com
  rtk git config user.name  "steps-test"
  rtk git config commit.gpgsign false
}

_scaffold_plan() { # slug ; writes .claude/steps/<slug>/{state.json,plan.md} under cwd
  local slug="$1"
  mkdir -p ".claude/steps/$slug"
  cat > ".claude/steps/$slug/state.json" <<JSON
{
  "slug": "$slug",
  "title": "Demo plan",
  "status": "planned",
  "branch": "steps/$slug",
  "base_branch": "main",
  "gate_command": "true",
  "steps": [
    {"id":"S1","status":"todo","title":"Eerste stap","behavior":"doet het eerste","done_criterion":{"type":"command","value":"true","expected":"exit 0"},"rule_paths":[]},
    {"id":"S2","status":"todo","title":"Tweede stap","behavior":"doet het tweede","done_criterion":{"type":"test","value":"pytest -q","expected":null},"rule_paths":[]}
  ]
}
JSON
  cat > ".claude/steps/$slug/plan.md" <<MD
# Stappenplan: Demo plan

## Stappen
- [ ] S1 — Eerste stap: doet het eerste. Klaar als: true. Regels: geen
- [ ] S2 — Tweede stap: doet het tweede. Klaar als: pytest. Regels: geen
MD
}

make_fixture() { # slug  ->  echoes repo path (checkout on steps/<slug>, plan committed)
  local slug="${1:?make_fixture <slug>}"
  local dir; dir="$(mktemp -d "$_FIXTURE_ROOT/fixture.XXXXXX")"
  (
    cd "$dir"
    rtk git init -q -b main .
    _fixture_git_config
    printf '# base\n' > README.md
    rtk git add -A && rtk git commit -q -m "base"
    rtk git switch -q -c "steps/$slug"
    _scaffold_plan "$slug"
    rtk git add -A && rtk git commit -q -m "plan"
  ) >/dev/null
  echo "$dir"
}

# Worktree-shaped fixture for status.sh, which detects a dirty tree via the
# $FWD_STEPS_WORKTREE_DIR/steps/<slug> worktree rather than the current checkout. Echoes the
# worktree-root: set FWD_STEPS_WORKTREE_DIR to it and cd into <root>/steps/<slug>. The plan is
# committed clean; the caller mutates state.json / dirties the tree to drive the assertion.
make_wt_fixture() { # slug  ->  echoes worktree-root
  local slug="${1:?make_wt_fixture <slug>}"
  local wtroot; wtroot="$(mktemp -d "$_FIXTURE_ROOT/wt.XXXXXX")"
  local repo="$wtroot/steps/$slug"
  mkdir -p "$repo"
  (
    cd "$repo"
    rtk git init -q -b main .
    _fixture_git_config
    printf '# base\n' > README.md
    _scaffold_plan "$slug"
    rtk git add -A && rtk git commit -q -m "base"
  ) >/dev/null
  echo "$wtroot"
}
