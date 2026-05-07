#!/usr/bin/env bash
# merge-json.sh - Deep-merge a JSON snippet into a target file.
#
# Usage:
#   merge-json.sh <target-file> <json-string>
#
# Behavior:
#   - If <target-file> does not exist: write <json-string> to it (creating parent dirs).
#   - If <target-file> exists and `jq` is available: deep-merge so that
#     objects merge recursively, arrays are concatenated (NOT replaced), and
#     scalars from the new snippet win on conflict.
#   - If <target-file> exists and `jq` is not available: back up to
#     <target-file>.bak and replace with <json-string>. Warns to stderr.
#
# Exit codes: 0 on success, non-zero on I/O failure.

set -euo pipefail

if [[ $# -ne 2 ]]; then
    echo "usage: $0 <target-file> <json-string>" >&2
    exit 64
fi

TARGET="$1"
NEW_JSON="$2"

mkdir -p "$(dirname "$TARGET")"

if [[ ! -f "$TARGET" ]]; then
    printf '%s\n' "$NEW_JSON" > "$TARGET"
    exit 0
fi

if ! command -v jq >/dev/null 2>&1; then
    printf '⚠  jq not found — backing up %s to %s.bak and replacing\n' "$TARGET" "$TARGET" >&2
    cp "$TARGET" "${TARGET}.bak"
    printf '%s\n' "$NEW_JSON" > "$TARGET"
    exit 0
fi

MERGED=$(jq -s '
  def deepmerge(a; b):
    a as $A | b as $B |
    if ($A|type) == "object" and ($B|type) == "object" then
      reduce (($A|keys_unsorted) + ($B|keys_unsorted) | unique)[] as $k
        ({};
          .[$k] = (
            if ($A|has($k)) and ($B|has($k)) then deepmerge($A[$k]; $B[$k])
            elif ($A|has($k)) then $A[$k]
            else $B[$k]
            end
          )
        )
    elif ($A|type) == "array" and ($B|type) == "array" then
      $A + $B
    else
      $B
    end;
  deepmerge(.[0]; .[1])
' "$TARGET" <(printf '%s' "$NEW_JSON")) || {
    echo "merge-json: jq failed to merge into $TARGET" >&2
    exit 1
}

printf '%s\n' "$MERGED" > "$TARGET"
