#!/usr/bin/env bash
# probe-meta.sh — emit GitHub repo metadata for fwd:issue-create draft.
#
# Stdout: JSON {"labels":[{"name":..,"description":..}, ...],"assignees":["login",...]}
# Exit non-zero on: not-a-git-repo, gh-not-authenticated, gh-call-failed.

set -euo pipefail

command -v jq >/dev/null 2>&1 || { echo "probe-meta: jq is required" >&2; exit 1; }

if ! rtk git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  echo "probe-meta: not a git repo" >&2
  exit 1
fi

if ! rtk git remote -v | grep -q .; then
  echo "probe-meta: no git remote configured (add one with: git remote add origin <url>)" >&2
  exit 1
fi

if ! rtk gh auth status >/dev/null 2>&1; then
  echo "probe-meta: gh not authenticated (run: gh auth login)" >&2
  exit 1
fi

LABELS=$(rtk gh label list --json name,description --limit 100 2>/dev/null) || {
  echo "probe-meta: gh label list failed" >&2
  exit 1
}

ASSIGNEES=$(rtk gh repo view --json assignableUsers --jq '[.assignableUsers[].login]' 2>/dev/null) || {
  echo "probe-meta: gh repo view failed" >&2
  exit 1
}

jq -n --argjson l "$LABELS" --argjson a "$ASSIGNEES" '{labels:$l, assignees:$a}'
