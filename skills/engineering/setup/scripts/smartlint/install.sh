#!/usr/bin/env bash
# install.sh - Install the smartlint Stop-hook into Claude Code settings.
#
# Usage:
#   install.sh --scope <user|project>
#
# Behavior:
#   user:    copies payload to ~/.claude/hooks/ and merges hook into ~/.claude/settings.json
#   project: copies payload to <CLAUDE_PROJECT_DIR-or-cwd>/.claude/hooks/ and merges
#            hook into <project>/.claude/settings.local.json
#
# Idempotent: re-running detects an already-installed Stop-hook with the same
# command string and skips the merge. Payload files are overwritten with the
# bundled versions on every run (so updates land cleanly).

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

if [[ "$SCOPE" != "user" && "$SCOPE" != "project" ]]; then
    echo "install: --scope must be 'user' or 'project'" >&2
    exit 64
fi

# ── Resolve paths ─────────────────────────────────────────────────────────────

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PAYLOAD_DIR="$SCRIPT_DIR/payload"
LIB_MERGE="$SCRIPT_DIR/../lib/merge-json.sh"

if [[ ! -d "$PAYLOAD_DIR" ]]; then
    echo "install: payload not found at $PAYLOAD_DIR" >&2
    exit 1
fi
if [[ ! -x "$LIB_MERGE" ]]; then
    echo "install: merge helper not found or not executable at $LIB_MERGE" >&2
    exit 1
fi

if [[ "$SCOPE" == "user" ]]; then
    CLAUDE_DIR="$HOME/.claude"
    SETTINGS_FILE="$CLAUDE_DIR/settings.json"
    HOOK_DIR_LITERAL='$HOME/.claude/hooks'
else
    PROJECT_ROOT="${CLAUDE_PROJECT_DIR:-$(pwd)}"
    CLAUDE_DIR="$PROJECT_ROOT/.claude"
    SETTINGS_FILE="$CLAUDE_DIR/settings.local.json"
    HOOK_DIR_LITERAL='$CLAUDE_PROJECT_DIR/.claude/hooks'
fi

HOOK_DIR_REAL="$CLAUDE_DIR/hooks"
EXPECTED_CMD="test -f \"$HOOK_DIR_LITERAL/smart-lint-wrapper.sh\" || exit 0; \"$HOOK_DIR_LITERAL/smart-lint-wrapper.sh\""

# ── Pre-flight: detect existing installs before touching anything ─────────────
#
# Three cases:
#   1. Exact same command already present → already installed. Skip everything.
#   2. Some OTHER smart-lint-wrapper.sh reference present (older install,
#      different path, manual variant) → exit 2 without copying payload or
#      merging. User must remove the existing entry first to avoid running
#      smart-lint twice.
#   3. No smart-lint reference → proceed with copy + merge.

ACTION="install"  # "install" or "skip-already-present"

if [[ -f "$SETTINGS_FILE" ]] && command -v jq >/dev/null 2>&1; then
    EXACT_MATCH=$(jq --arg cmd "$EXPECTED_CMD" \
        '[.hooks.Stop[]?.hooks[]?.command // empty] | any(. == $cmd)' \
        "$SETTINGS_FILE" 2>/dev/null || echo "false")

    if [[ "$EXACT_MATCH" == "true" ]]; then
        ACTION="skip-already-present"
    else
        OTHER_VARIANTS=$(jq -r \
            '[.hooks.Stop[]?.hooks[]?.command // empty | select(test("smart-lint-wrapper\\.sh"))] | .[]' \
            "$SETTINGS_FILE" 2>/dev/null || true)

        if [[ -n "$OTHER_VARIANTS" ]]; then
            printf '⚠  An existing smart-lint Stop-hook was found in %s:\n' "$SETTINGS_FILE" >&2
            printf '%s\n' "$OTHER_VARIANTS" | sed 's/^/    /' >&2
            printf '\n' >&2
            printf 'Skipping install to avoid running smart-lint twice.\n' >&2
            printf 'To replace it with the bundled version:\n' >&2
            printf '  1. Remove the entry above from %s\n' "$SETTINGS_FILE" >&2
            printf '  2. Re-run /fwd:setup\n' >&2
            exit 2
        fi
    fi
fi

if [[ "$ACTION" == "skip-already-present" ]]; then
    echo "✔ Smartlint Stop-hook already installed in $SETTINGS_FILE — refreshing payload only"
fi

# ── Copy payload (always — keeps bundled scripts up to date on re-runs) ───────

mkdir -p "$HOOK_DIR_REAL"
cp "$PAYLOAD_DIR/smart-lint.sh" "$HOOK_DIR_REAL/smart-lint.sh"
cp "$PAYLOAD_DIR/smart-lint-wrapper.sh" "$HOOK_DIR_REAL/smart-lint-wrapper.sh"
chmod +x "$HOOK_DIR_REAL/smart-lint.sh" "$HOOK_DIR_REAL/smart-lint-wrapper.sh"
echo "✔ Payload → $HOOK_DIR_REAL/{smart-lint.sh,smart-lint-wrapper.sh}"

# ── Merge settings (only when not already installed) ──────────────────────────

if [[ "$ACTION" == "install" ]]; then
    HOOK_JSON=$(sed "s|__HOOK_DIR__|$HOOK_DIR_LITERAL|g" "$PAYLOAD_DIR/hooks.json")
    bash "$LIB_MERGE" "$SETTINGS_FILE" "$HOOK_JSON"
    echo "✔ Hook merged → $SETTINGS_FILE"
fi
