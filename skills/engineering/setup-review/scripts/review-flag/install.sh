#!/usr/bin/env bash
# install.sh - Opt the repo in to the Workcenter reviewer: "review": true in
# <project>/.claude/fwd/plugin.json (the file smart-lint already reads its switch from).
# bin/reviewer on the Workcenter reviews only repos with this flag.
#
# Usage:
#   install.sh --scope project
#
# Idempotent. Already true → no change. Explicitly false → exit 2: someone switched
# the reviewer off on purpose, so remove the line and re-run /fwd:setup-review. Other
# keys in the file are kept. A file jq cannot read is a collision too.

set -euo pipefail

# ── Parse args ────────────────────────────────────────────────────────────────

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
    echo "install: --scope must be 'project' (the review setup belongs to one repo)" >&2
    exit 64
fi

if ! command -v jq >/dev/null 2>&1; then
    echo "⚠  jq is not installed; it is needed to edit .claude/fwd/plugin.json. Install jq and re-run /fwd:setup-review." >&2
    exit 2
fi

PROJECT_ROOT="${CLAUDE_PROJECT_DIR:-$(pwd)}"
FLAG_FILE="$PROJECT_ROOT/.claude/fwd/plugin.json"

# ── Detect existing value ─────────────────────────────────────────────────────

CURRENT="missing"
if [[ -f "$FLAG_FILE" ]]; then
    if ! CURRENT=$(jq -r 'if type != "object" then error("not an object")
                          elif has("review") then .review | tojson
                          else "missing" end' "$FLAG_FILE" 2>/dev/null); then
        printf '⚠  %s is not a JSON object jq can read.\n' "$FLAG_FILE" >&2
        printf '   Repair the file (or delete it) and re-run /fwd:setup-review.\n' >&2
        exit 2
    fi
fi

case "$CURRENT" in
    true)
        echo "✔ review already true, no change → $FLAG_FILE"
        exit 0
        ;;
    missing) ;;
    *)
        printf '⚠  "review" is set to %s in %s\n' "$CURRENT" "$FLAG_FILE" >&2
        printf '   Refusing to overwrite an explicit choice.\n' >&2
        printf '   To opt in: remove the "review" line from %s and re-run /fwd:setup-review.\n' "$FLAG_FILE" >&2
        exit 2
        ;;
esac

# ── Write ─────────────────────────────────────────────────────────────────────

mkdir -p "$(dirname "$FLAG_FILE")"
TMP="$(mktemp "$FLAG_FILE.XXXXXX")"
trap 'rm -f "$TMP"' EXIT
if [[ -f "$FLAG_FILE" ]]; then
    jq '.review = true' "$FLAG_FILE" > "$TMP"
else
    jq -n '{review: true}' > "$TMP"
fi
mv "$TMP" "$FLAG_FILE"
echo "✔ review → true in $FLAG_FILE"
