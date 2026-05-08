#!/usr/bin/env bash
# fwd:skill-eval cleanup — invoked when user replies x/undo after a report.
# Removes tmp/eval/ and surfaces any other diffs the eval may have caused.
set -euo pipefail

if [ -d "tmp/eval/" ]; then
  rm -rf tmp/eval/
  echo "✅ Removed tmp/eval/"
else
  echo "ℹ️  No tmp/eval/ to remove."
fi

diff_output="$(rtk git status --porcelain 2>/dev/null || true)"
if [ -n "$diff_output" ]; then
  echo ""
  echo "⚠️  Other changes still present (not cleaned by fwd:skill-eval):"
  echo "$diff_output"
  echo ""
  echo "Inspect with: rtk git diff"
  echo "Revert with:  rtk git checkout -- <path>   (or restore your stash)"
fi

exit 0
