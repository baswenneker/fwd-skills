#!/usr/bin/env bash
# Guard against inline-norm drift: a shared norm block that is hand-copied into several
# agent files must stay byte-identical. Given a heading, this extracts the block under
# '## <heading>' (every line up to the next '## ' or end of file) from each file and diffs
# every copy against the first; any difference is drift and fails with a unified diff.
#
# With no arguments it guards this repo's own shared block ('## Shared tool prohibitions')
# across the agents that carry it — run it before committing agent edits.
# With arguments it compares any block across any files (used by the fixtures):
#   check-agent-norms.sh "<heading>" <file> <file> [<file>...]
set -euo pipefail

extract() {  # extract "<heading>" <file>  → the block body under '## <heading>'
  awk -v h="## $1" '$0 == h {f=1; next} f && /^## / {f=0} f {print}' "$2"
}

check_block() {  # check_block "<heading>" <file> <file>...  → 0 if all identical, else 1
  local heading="$1"; shift
  local ref="$1" f d drift=0 n=$#
  for f in "${@:2}"; do
    d="$(diff -u --label "$ref" --label "$f" \
          <(extract "$heading" "$ref") <(extract "$heading" "$f") || true)"
    if [[ -n "$d" ]]; then
      echo "DRIFT — '$heading': $f ≠ $ref"
      echo "$d"
      drift=1
    fi
  done
  if [[ $drift -eq 0 ]]; then
    echo "ok — '$heading' identiek over $n bestanden"
  fi
  return $drift
}

if [[ $# -gt 0 ]]; then
  HEADING="$1"; shift
  [[ $# -ge 2 ]] || { echo "need at least two files to compare" >&2; exit 1; }
  check_block "$HEADING" "$@"
  exit $?
fi

# No arguments: the repo's own shared blocks. Run from the repo root (scripts/..).
cd "$(dirname "${BASH_SOURCE[0]}")/.."
check_block "Shared tool prohibitions" \
  agents/fwd-mission-coder.md \
  agents/fwd-mission-reviewer.md \
  agents/fwd-mission-user-tester.md \
  agents/fwd-steps-doubt.md \
  agents/fwd-steps-reviewer.md
