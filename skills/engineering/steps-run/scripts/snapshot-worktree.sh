#!/usr/bin/env bash
# Capture the ENTIRE current worktree — tracked modifications plus untracked files, honouring
# .gitignore — as an off-branch commit, and echo its SHA. HEAD, the branch, the real index and
# the working tree are all left untouched; the commit is a dangling boundary marker that git
# garbage-collects on its own. The autonomous loop takes one snapshot before and one after each
# step; diffing the two isolates exactly that step's changes for the fresh reviewer, even though
# nothing has been committed to the branch yet.
# Usage: snapshot-worktree.sh <slug>
# Stdout: <commit-sha>
set -euo pipefail

SLUG="${1:?usage: snapshot-worktree.sh <slug>}"
REPO_ROOT="$(rtk git rev-parse --show-toplevel)"
[[ -d "$REPO_ROOT/.claude/steps/$SLUG" ]] || { echo "no steps plan '$SLUG' in $REPO_ROOT" >&2; exit 1; }

# Build the tree in a scratch index so the real index and working tree are never touched.
TMPIDX="$(mktemp -u)"
trap 'rm -f "$TMPIDX"' EXIT
GIT_INDEX_FILE="$TMPIDX" rtk git add -A >&2
TREE="$(GIT_INDEX_FILE="$TMPIDX" rtk git write-tree)"

rtk git commit-tree "$TREE" -p HEAD -m "steps-run worktree snapshot"
