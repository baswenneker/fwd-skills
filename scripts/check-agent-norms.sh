#!/usr/bin/env bash
# Guard against inline-norm drift: a shared norm block that is hand-copied into several
# agent files must stay byte-identical. Given a heading, this extracts the block under
# '## <heading>' (every line up to the next '## ' or end of file) from each file and diffs
# every copy against the first; any difference is drift and fails with a unified diff.
# Usage: check-agent-norms.sh "<heading>" <file> <file> [<file>...]
set -euo pipefail

extract() {  # extract "<heading>" <file>  → the block body under '## <heading>'
  awk -v h="## $1" '$0 == h {f=1; next} f && /^## / {f=0} f {print}' "$2"
}

HEADING="${1:?usage: check-agent-norms.sh \"<heading>\" <file> <file>...}"
shift
[[ $# -ge 2 ]] || { echo "need at least two files to compare" >&2; exit 1; }

N=$#
REF="$1"
DRIFT=0
for f in "${@:2}"; do
  D="$(diff -u --label "$REF" --label "$f" \
        <(extract "$HEADING" "$REF") <(extract "$HEADING" "$f") || true)"
  if [[ -n "$D" ]]; then
    echo "DRIFT — '$HEADING': $f ≠ $REF"
    echo "$D"
    DRIFT=1
  fi
done

if [[ $DRIFT -eq 0 ]]; then
  echo "ok — '$HEADING' identiek over $N bestanden"
fi
exit $DRIFT
