#!/usr/bin/env bash
# fwd:skill-eval pre-flight gate
# Args: $1 = path to target skill folder
# Exits: 0 (clean), 5 (dirty tree), 6 (target invalid)
set -euo pipefail

target="${1:-}"

if [ -z "$target" ]; then
  echo "🛑 No target skill path provided."
  echo "Usage: preflight.sh <path-to-skill-folder>"
  exit 6
fi

if [ ! -f "$target/SKILL.md" ]; then
  echo "🛑 No SKILL.md found at: $target"
  exit 6
fi

dirty="$(rtk git status --porcelain 2>/dev/null || true)"
if [ -n "$dirty" ]; then
  echo "🛑 Working tree is dirty — fwd:skill-eval refuses to run."
  echo ""
  echo "Pending changes:"
  echo "$dirty"
  echo ""
  echo "Commit or stash before running. Undo (Phase 6) only catches diffs inside tmp/eval/,"
  echo "so starting clean is the only way to keep cleanup unambiguous."
  exit 5
fi

rm -rf tmp/eval/
mkdir -p tmp/eval/

echo "✅ Pre-flight clean. Sandbox reset at tmp/eval/."
echo "Target: $target"
exit 0
