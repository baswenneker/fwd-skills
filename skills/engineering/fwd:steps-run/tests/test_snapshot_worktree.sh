#!/usr/bin/env bash
# snapshot-worktree.sh captures the whole worktree (tracked + untracked) as an off-branch
# commit without touching HEAD, the index, or the working tree — so two snapshots taken
# around one step's edits diff to exactly that step, even with prior uncommitted work present.
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

SNAP="$SCRIPTS_DIR/snapshot-worktree.sh"

fix="$(make_fixture demo)"; cd "$fix"

# A prior step's accumulated, uncommitted work: a tracked change plus an untracked file.
printf 'prior\n' >> README.md
printf 'prior\n' > prior_new.txt
head_before="$(rtk git rev-parse HEAD)"
before="$(bash "$SNAP" demo)"

# THIS step's work: another tracked change plus a NEW untracked file.
printf 'step\n' >> README.md
printf 'step\n' > step_new.txt
after="$(bash "$SNAP" demo)"
head_after="$(rtk git rev-parse HEAD)"

# The two snapshots isolate exactly this step — the prior work is in both, so it cancels out.
names="$(rtk git diff --name-status "$before" "$after")"
assert_contains "$names" "step_new.txt" "diff includes the step's new untracked file"
assert_contains "$names" "README.md"    "diff includes the step's tracked change"
assert_eq "" "$(printf '%s\n' "$names" | grep 'prior_new.txt' || true)" "diff excludes the prior step's file"

# Nothing on the branch or in the working tree moved.
assert_eq "$head_before" "$head_after"  "HEAD is unchanged by snapshotting"
wt="$(rtk git status --porcelain | grep -vx 'ok' || true)"
assert_contains "$wt" "prior_new.txt"   "working tree still holds the prior work"
assert_contains "$wt" "step_new.txt"    "working tree still holds this step's work"
assert_eq "" "$(rtk git diff --cached --name-only | grep -vx 'ok' || true)" \
  "the real index is left clean (scratch-index isolation)"

echo "  snapshot-worktree verified"
