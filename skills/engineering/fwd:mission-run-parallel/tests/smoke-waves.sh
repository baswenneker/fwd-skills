#!/usr/bin/env bash
# Hermetic smoke-test harness for the parallel wave-engine scripts.
# Covers: cap enforcement, integration order, conflict→pin, wave-gate
# culprit isolation, and v1 refusal. Everything runs in tmp dirs;
# cleaned up on exit. Exit 0 iff all assertions pass.
#
# Gate G3 runs this from the mission worktree root; the harness locates
# scripts via BASH_SOURCE, never via cwd.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PICK_WAVE="$SCRIPT_DIR/../scripts/pick-wave.sh"
SETUP_SLOT="$SCRIPT_DIR/../scripts/setup-slot.sh"
INTEGRATE="$SCRIPT_DIR/../scripts/integrate-feature.sh"
RECONCILE_WAVES="$SCRIPT_DIR/../scripts/reconcile-waves.sh"

command -v jq  >/dev/null 2>&1 || { echo "FATAL: jq not found"  >&2; exit 1; }
command -v git >/dev/null 2>&1 || { echo "FATAL: git not found" >&2; exit 1; }
command -v rtk >/dev/null 2>&1 || { echo "FATAL: rtk not found" >&2; exit 1; }

# ── Assertion helpers ────────────────────────────────────────────────────────
PASS_COUNT=0
FAIL_COUNT=0
ASSERTION_INDEX=0

assert_pass() {
  local label="$1"
  ASSERTION_INDEX=$((ASSERTION_INDEX + 1))
  PASS_COUNT=$((PASS_COUNT + 1))
  echo "  PASS $ASSERTION_INDEX: $label"
}

assert_fail() {
  local label="$1"
  local detail="${2:-}"
  ASSERTION_INDEX=$((ASSERTION_INDEX + 1))
  FAIL_COUNT=$((FAIL_COUNT + 1))
  echo "  FAIL $ASSERTION_INDEX: $label${detail:+ — $detail}" >&2
}

assert_eq() {
  local label="$1" got="$2" want="$3"
  if [[ "$got" == "$want" ]]; then
    assert_pass "$label"
  else
    assert_fail "$label" "got='$got' want='$want'"
  fi
}

assert_exit() {
  local label="$1" code="$2" expected="$3"
  if [[ "$code" -eq "$expected" ]]; then
    assert_pass "$label"
  else
    assert_fail "$label" "exit $code, expected $expected"
  fi
}

assert_contains() {
  local label="$1" haystack="$2" needle="$3"
  if echo "$haystack" | grep -qF "$needle"; then
    assert_pass "$label"
  else
    assert_fail "$label" "not found: '$needle'"
  fi
}

assert_empty() {
  local label="$1" val="$2"
  if [[ -z "$val" ]]; then
    assert_pass "$label"
  else
    assert_fail "$label" "expected empty, got: '$val'"
  fi
}

assert_not_empty() {
  local label="$1" val="$2"
  if [[ -n "$val" ]]; then
    assert_pass "$label"
  else
    assert_fail "$label" "expected non-empty but was empty"
  fi
}

assert_file_absent() {
  local label="$1" path="$2"
  if [[ ! -e "$path" ]]; then
    assert_pass "$label"
  else
    assert_fail "$label" "file unexpectedly exists: $path"
  fi
}

assert_file_present() {
  local label="$1" path="$2"
  if [[ -e "$path" ]]; then
    assert_pass "$label"
  else
    assert_fail "$label" "file expected but absent: $path"
  fi
}

# ── Cleanup on exit ───────────────────────────────────────────────────────────
WORK_DIRS=()
cleanup() {
  for d in "${WORK_DIRS[@]:-}"; do
    [[ -n "$d" && -d "$d" ]] && rm -rf "$d"
  done
}
trap cleanup EXIT

# ── Fixture builder ───────────────────────────────────────────────────────────
# build_fixture <work_dir> [<slug>]
#   Creates:
#     $work_dir/repo          — bare-ish git repo (initial commit on main)
#     $work_dir/trees/mission/<slug>  — mission worktree on mission/<slug>
#   Sets module-level globals:
#     FIXTURE_REPO, FIXTURE_WT, FIXTURE_STATE, FIXTURE_SLUG
#   Exports FWD_MISSION_WORKTREE_DIR so all scripts resolve trees correctly.
#   IMPORTANT: git ops without -C target the CURRENT DIRECTORY. The helper
#   functions below all cd into FIXTURE_REPO before calling the scripts.

build_fixture() {
  local work_dir="$1"
  local slug="${2:-test-mission}"

  local repo="$work_dir/repo"
  local trees="$work_dir/trees"
  local mission_wt="$trees/mission/$slug"

  mkdir -p "$repo" "$trees/mission"

  # Init main repo
  git -C "$repo" init -b main -q
  git -C "$repo" config user.email "smoke@test.local"
  git -C "$repo" config user.name  "Smoke Test"

  # Seed files for a real initial commit
  mkdir -p "$repo/src"
  echo "# fixture" > "$repo/README.md"
  echo "v=1"        > "$repo/src/app.sh"
  git -C "$repo" add -A
  git -C "$repo" commit -q -m "chore: initial commit"

  # Create mission branch + worktree
  git -C "$repo" branch "mission/$slug"
  git -C "$repo" worktree add "$mission_wt" "mission/$slug" -q

  git -C "$mission_wt" config user.email "smoke@test.local"
  git -C "$mission_wt" config user.name  "Smoke Test"

  # Fixture gate helper (runs from within the mission worktree via run-gates.sh)
  cat > "$mission_wt/gate-check.sh" <<'GATEEOF'
#!/usr/bin/env bash
# Pass unless GATE_FAIL_SENTINEL is present in the worktree.
if [ -f "GATE_FAIL_SENTINEL" ]; then
  echo "gate: GATE_FAIL_SENTINEL present — failing" >&2
  exit 1
fi
exit 0
GATEEOF
  chmod +x "$mission_wt/gate-check.sh"

  # Build state.json
  mkdir -p "$mission_wt/.claude/missions/$slug"
  local state_file="$mission_wt/.claude/missions/$slug/state.json"
  jq -n \
    --arg slug "$slug" \
    --arg now  "$(date -u +%FT%TZ)" \
    '{
      version: 2,
      slug: $slug,
      title: "Smoke-test fixture mission",
      status: "in_progress",
      branch: ("mission/" + $slug),
      base_branch: "main",
      created_at: $now,
      started_at: $now,
      started_at_epoch: 0,
      completed_at: null,
      gates: [
        {id:"G-pass",  name:"always-pass", command:"true",               expected_exit: 0},
        {id:"G-check", name:"gate-check",  command:"bash gate-check.sh", expected_exit: 0}
      ],
      user_testing: {
        boot_command: null, ready_probe: null, smoke_commands: [],
        playwright_present: false, teardown_command: null
      },
      features: [
        {id:"FA", title:"Feature A", milestone:"M1", vc_ids:["VC-A"],
         depends_on:[], status:"pending", attempts:0,
         commit_sha:null, started_at:null, completed_at:null, error:null, handoff:null},
        {id:"FB", title:"Feature B", milestone:"M1", vc_ids:["VC-B"],
         depends_on:[], status:"pending", attempts:0,
         commit_sha:null, started_at:null, completed_at:null, error:null, handoff:null},
        {id:"FC", title:"Feature C", milestone:"M1", vc_ids:["VC-C"],
         depends_on:[], status:"pending", attempts:0,
         commit_sha:null, started_at:null, completed_at:null, error:null, handoff:null},
        {id:"FD", title:"Feature D", milestone:"M1", vc_ids:["VC-D"],
         depends_on:["FA"], status:"pending", attempts:0,
         commit_sha:null, started_at:null, completed_at:null, error:null, handoff:null}
      ],
      milestones: [
        {id:"M1", title:"Milestone 1", feature_ids:["FA","FB","FC","FD"],
         validation_status:"pending", validated_at:null, gate_results:[], vc_results:[]}
      ],
      circuit_breaker: {consecutive_failures: 0},
      decisions: []
    }' > "$state_file"

  # Commit the initial state
  git -C "$mission_wt" add -- ".claude/missions/$slug" gate-check.sh
  git -C "$mission_wt" commit -q -m "chore(mission): initial state"

  # Expose globals
  FIXTURE_REPO="$repo"
  FIXTURE_WT="$mission_wt"
  FIXTURE_STATE="$state_file"
  FIXTURE_SLUG="$slug"

  # Scripts resolve trees via this env var
  export FWD_MISSION_WORKTREE_DIR="$trees"
}

# ── state query helper ────────────────────────────────────────────────────────
state_get() {
  jq -r "$1" "$FIXTURE_STATE"
}

# ── Script callers (always cd into FIXTURE_REPO first) ───────────────────────
# setup-slot.sh and pick-wave.sh use bare `rtk git show-ref` / `rtk git branch`
# without -C — they operate on the CWD's git context, so we must cd into the
# fixture repo.  integrate-feature.sh uses -C exclusively after computing REPO_ROOT
# (via --git-common-dir from the mission worktree), so it also needs the CWD to be
# inside a git repo.  The mission worktree is a valid git context — use it.

# pick_wave <slug> [max_parallel] → echoes JSON, returns exit code in WAVE_RC
pick_wave() {
  local slug="$1"
  local cap="${2:-3}"
  WAVE_RC=0
  WAVE_OUT="$(cd "$FIXTURE_REPO" && FWD_MISSION_MAX_PARALLEL="$cap" \
    bash "$PICK_WAVE" "$slug" 2>/dev/null)" || WAVE_RC=$?
}

pick_wave_with_stderr() {
  local slug="$1"
  WAVE_RC=0
  WAVE_OUT="$(cd "$FIXTURE_REPO" && bash "$PICK_WAVE" "$slug" 2>&1)" || WAVE_RC=$?
}

# provision_slot <slug> <slot_n> <feature_id> → sets SLOT_PATH
provision_slot() {
  local slug="$1" slot_n="$2" fid="$3"
  SLOT_PATH="$(cd "$FIXTURE_REPO" && bash "$SETUP_SLOT" "$slug" "$slot_n" "$fid" 2>/dev/null)"
}

# run_integrate <slug> <feature_id> → sets INTEGRATE_RC
run_integrate() {
  local slug="$1" fid="$2"
  INTEGRATE_RC=0
  (cd "$FIXTURE_WT" && bash "$INTEGRATE" "$slug" "$fid" 2>/dev/null < /dev/null) \
    || INTEGRATE_RC=$?
}

# ── Stub coder helpers ────────────────────────────────────────────────────────
_git_slot() {
  git -C "$1" config user.email "coder@test.local" 2>/dev/null || true
  git -C "$1" config user.name  "Stub Coder"       2>/dev/null || true
}

stub_coder_clean() {
  local slot="$1" fid="$2" fname="${3:-feat-${2}.txt}"
  _git_slot "$slot"
  echo "implementation of $fid" > "$slot/$fname"
  git -C "$slot" add -- "$fname"
  git -C "$slot" commit -q -m "feat($fid): implement $fid"
}

stub_coder_gate_fail() {
  local slot="$1" fid="$2"
  _git_slot "$slot"
  echo "sentinel" > "$slot/GATE_FAIL_SENTINEL"
  git -C "$slot" add -- "GATE_FAIL_SENTINEL"
  git -C "$slot" commit -q -m "feat($fid): break gate (sentinel)"
}

# ══════════════════════════════════════════════════════════════════════════════
echo ""
echo "=== Scenario 1: Cap enforcement ==="
echo ""

WORK1="$(mktemp -d)"
WORK_DIRS+=("$WORK1")
build_fixture "$WORK1"

# 3 ready features (FA, FB, FC all have depends_on:[]) but cap=2
pick_wave "$FIXTURE_SLUG" 2

assert_exit  "pick-wave exits 0" "$WAVE_RC" 0
assert_not_empty "wave output non-empty" "$WAVE_OUT"

WAVE_COUNT="$(echo "$WAVE_OUT" | jq '.wave | length')"
assert_eq "wave has exactly 2 features (cap=2)" "$WAVE_COUNT" "2"

WAVE_ID0="$(echo "$WAVE_OUT" | jq -r '.wave[0].id')"
WAVE_ID1="$(echo "$WAVE_OUT" | jq -r '.wave[1].id')"
assert_eq "first wave member is FA (plan order)"  "$WAVE_ID0" "FA"
assert_eq "second wave member is FB (plan order)" "$WAVE_ID1" "FB"

WAVE_MID="$(echo "$WAVE_OUT" | jq -r '.milestone')"
assert_eq "milestone is M1" "$WAVE_MID" "M1"

# ══════════════════════════════════════════════════════════════════════════════
echo ""
echo "=== Scenario 2: Integration order + commit_sha advancement ==="
echo ""

WORK2="$(mktemp -d)"
WORK_DIRS+=("$WORK2")
build_fixture "$WORK2"

provision_slot "$FIXTURE_SLUG" "1" "FA"
SLOT_A="$SLOT_PATH"
stub_coder_clean "$SLOT_A" "FA" "feat-fa.txt"

provision_slot "$FIXTURE_SLUG" "2" "FB"
SLOT_B="$SLOT_PATH"
stub_coder_clean "$SLOT_B" "FB" "feat-fb.txt"

PRE_FA_HEAD="$(git -C "$FIXTURE_WT" rev-parse HEAD)"

run_integrate "$FIXTURE_SLUG" "FA"
assert_exit "integrate FA exits 0" "$INTEGRATE_RC" 0

POST_FA_HEAD="$(git -C "$FIXTURE_WT" rev-parse HEAD)"
assert_not_empty "HEAD advanced after FA" \
  "$([ "$POST_FA_HEAD" != "$PRE_FA_HEAD" ] && echo yes || echo '')"

FA_SHA="$(state_get '.features[] | select(.id=="FA") | .commit_sha')"
assert_not_empty "FA commit_sha is set" "$FA_SHA"
# commit_sha = the code commit; mission HEAD = code commit + checkpoint commit
ANCS_FA=0
git -C "$FIXTURE_WT" merge-base --is-ancestor "$FA_SHA" "$POST_FA_HEAD" || ANCS_FA=$?
assert_exit "FA commit_sha is ancestor-or-equal of mission HEAD" "$ANCS_FA" 0
assert_eq "FA status done" "$(state_get '.features[] | select(.id=="FA") | .status')" "done"

run_integrate "$FIXTURE_SLUG" "FB"
assert_exit "integrate FB exits 0" "$INTEGRATE_RC" 0

POST_FB_HEAD="$(git -C "$FIXTURE_WT" rev-parse HEAD)"
assert_not_empty "HEAD advanced after FB" \
  "$([ "$POST_FB_HEAD" != "$POST_FA_HEAD" ] && echo yes || echo '')"

FB_SHA="$(state_get '.features[] | select(.id=="FB") | .commit_sha')"
assert_not_empty "FB commit_sha is set" "$FB_SHA"
ANCS_FB=0
git -C "$FIXTURE_WT" merge-base --is-ancestor "$FB_SHA" "$POST_FB_HEAD" || ANCS_FB=$?
assert_exit "FB commit_sha is ancestor-or-equal of mission HEAD" "$ANCS_FB" 0
assert_eq "FB status done" "$(state_get '.features[] | select(.id=="FB") | .status')" "done"

# FA code commit is an ancestor of FB code commit (plan order preserved in the history)
ANCS=0
git -C "$FIXTURE_WT" merge-base --is-ancestor "$FA_SHA" "$FB_SHA" || ANCS=$?
assert_exit "FA commit is ancestor of FB (integration order)" "$ANCS" 0

# ══════════════════════════════════════════════════════════════════════════════
echo ""
echo "=== Scenario 3: Conflict -> pin ==="
echo ""

WORK3="$(mktemp -d)"
WORK_DIRS+=("$WORK3")
build_fixture "$WORK3"

# Integrate FA with a file that FB will also edit (using FA's slot)
provision_slot "$FIXTURE_SLUG" "1" "FA"
SLOT_A3="$SLOT_PATH"
_git_slot "$SLOT_A3"
echo "FA content" > "$SLOT_A3/shared-conflict.txt"
git -C "$SLOT_A3" add -- "shared-conflict.txt"
git -C "$SLOT_A3" commit -q -m "feat(FA): write shared file"

run_integrate "$FIXTURE_SLUG" "FA"
assert_exit "FA integrates cleanly (conflict setup)" "$INTEGRATE_RC" 0

POST_FA3_HEAD="$(git -C "$FIXTURE_WT" rev-parse HEAD)"

# Create FB's slot branch manually, rooted at the PRE-FA base so its commit
# diverges from FA's work on the mission branch.  find the commit just before
# FA's integration: the initial-state commit is the last common ancestor.
INIT_SHA="$(git -C "$FIXTURE_WT" rev-list HEAD | tail -1)"

FID_LOWER_B="fb"
SLOT_BRANCH_B="mission/$FIXTURE_SLUG--$FID_LOWER_B"
SLOT_PATH_B="$FWD_MISSION_WORKTREE_DIR/mission/$FIXTURE_SLUG--slot-2"

# Branch the slot from the initial commit (before FA was integrated)
git -C "$FIXTURE_REPO" branch "$SLOT_BRANCH_B" "$INIT_SHA"
git -C "$FIXTURE_REPO" worktree add "$SLOT_PATH_B" "$SLOT_BRANCH_B" -q
git -C "$SLOT_PATH_B" config user.email "coder@test.local"
git -C "$SLOT_PATH_B" config user.name  "Stub Coder"

# FB writes the same file with different content → cherry-pick onto post-FA HEAD will conflict
echo "FB conflicting content" > "$SLOT_PATH_B/shared-conflict.txt"
git -C "$SLOT_PATH_B" add -- "shared-conflict.txt"
git -C "$SLOT_PATH_B" commit -q -m "feat(FB): conflicting content"

PRE_CONFLICT_HEAD="$(git -C "$FIXTURE_WT" rev-parse HEAD)"

run_integrate "$FIXTURE_SLUG" "FB"
assert_exit "integrate FB exits 3 (conflict)" "$INTEGRATE_RC" 3

# Tree must be clean (abort + reset took care of it)
DIRTY3="$(git -C "$FIXTURE_WT" status --porcelain | grep -vx 'ok' || true)"
assert_empty "mission tree clean after conflict" "$DIRTY3"

# Exactly 1 new commit: the pin commit
PIN_DELTA="$(git -C "$FIXTURE_WT" rev-list "${PRE_CONFLICT_HEAD}..HEAD" --count)"
assert_eq "exactly 1 pin commit added" "$PIN_DELTA" "1"

assert_eq "FB still pending" \
  "$(state_get '.features[] | select(.id=="FB") | .status')" "pending"
assert_eq "FB pinned serial_only=true" \
  "$(state_get '.features[] | select(.id=="FB") | .serial_only')" "true"
assert_eq "FB discards=1" \
  "$(state_get '.features[] | select(.id=="FB") | .discards')" "1"
assert_eq "FB attempts unchanged (0) — conflict does not consume attempt" \
  "$(state_get '.features[] | select(.id=="FB") | .attempts')" "0"

DECISION_COUNT="$(state_get '.decisions | length')"
assert_not_empty "at least one decision entry" \
  "$([ "$DECISION_COUNT" -gt 0 ] && echo yes || echo '')"
assert_eq "decision references FB" \
  "$(state_get '.decisions[-1].feature')" "FB"

# ══════════════════════════════════════════════════════════════════════════════
echo ""
echo "=== Scenario 4: Wave-gate culprit isolation ==="
echo ""

WORK4="$(mktemp -d)"
WORK_DIRS+=("$WORK4")
build_fixture "$WORK4"

# Integrate FA cleanly
provision_slot "$FIXTURE_SLUG" "1" "FA"
SLOT_A4="$SLOT_PATH"
stub_coder_clean "$SLOT_A4" "FA" "feat-fa4.txt"

run_integrate "$FIXTURE_SLUG" "FA"
assert_exit "FA integrates cleanly (gate isolation)" "$INTEGRATE_RC" 0

assert_file_present "FA work present on mission branch" "$FIXTURE_WT/feat-fa4.txt"

PRE_FB4_HEAD="$(git -C "$FIXTURE_WT" rev-parse HEAD)"

# Provision FB slot and add the gate-breaking sentinel commit
provision_slot "$FIXTURE_SLUG" "2" "FB"
SLOT_B4="$SLOT_PATH"
stub_coder_gate_fail "$SLOT_B4" "FB"

run_integrate "$FIXTURE_SLUG" "FB"
assert_exit "integrate FB exits 4 (gate failure)" "$INTEGRATE_RC" 4

# Sentinel must have been reset out of mission branch
assert_file_absent "GATE_FAIL_SENTINEL absent after reset" "$FIXTURE_WT/GATE_FAIL_SENTINEL"

# FA's work must still be intact
assert_file_present "FA work intact after FB gate-fail" "$FIXTURE_WT/feat-fa4.txt"

DIRTY4="$(git -C "$FIXTURE_WT" status --porcelain | grep -vx 'ok' || true)"
assert_empty "mission tree clean after gate-fail" "$DIRTY4"

assert_eq "FB still pending after gate-fail" \
  "$(state_get '.features[] | select(.id=="FB") | .status')" "pending"
assert_eq "FB pinned serial_only=true" \
  "$(state_get '.features[] | select(.id=="FB") | .serial_only')" "true"
assert_eq "FB attempts incremented (gate-fail consumes attempt)" \
  "$(state_get '.features[] | select(.id=="FB") | .attempts')" "1"

# ══════════════════════════════════════════════════════════════════════════════
echo ""
echo "=== Scenario 5: v1 refusal ==="
echo ""

WORK5="$(mktemp -d)"
WORK_DIRS+=("$WORK5")
build_fixture "$WORK5"

# Rewrite state.json without any depends_on key (v1 plan)
TMP5="$FIXTURE_STATE.tmp.$$"
jq 'del(.features[].depends_on)' "$FIXTURE_STATE" > "$TMP5" && mv "$TMP5" "$FIXTURE_STATE"
git -C "$FIXTURE_WT" add -- ".claude/missions/$FIXTURE_SLUG"
git -C "$FIXTURE_WT" commit -q -m "test: rewrite state to v1 (no depends_on)"

pick_wave_with_stderr "$FIXTURE_SLUG"
assert_exit "pick-wave exits 2 for v1 mission" "$WAVE_RC" 2
assert_contains "stderr mentions /fwd:mission-run" "$WAVE_OUT" "/fwd:mission-run"

# ══════════════════════════════════════════════════════════════════════════════
echo ""
echo "=== Scenario 6: serial_only solo wave ==="
echo ""

WORK6="$(mktemp -d)"
WORK_DIRS+=("$WORK6")
build_fixture "$WORK6"

# Pin FA as serial_only
TMP6="$FIXTURE_STATE.tmp.$$"
jq '(.features[] | select(.id=="FA")) |= (.serial_only = true)' \
  "$FIXTURE_STATE" > "$TMP6" && mv "$TMP6" "$FIXTURE_STATE"
git -C "$FIXTURE_WT" add -- ".claude/missions/$FIXTURE_SLUG"
git -C "$FIXTURE_WT" commit -q -m "test: pin FA serial_only"

pick_wave "$FIXTURE_SLUG" 3
assert_exit "pick-wave exits 0 with serial_only feature" "$WAVE_RC" 0
WAVE6_COUNT="$(echo "$WAVE_OUT" | jq '.wave | length')"
assert_eq "serial_only FA forms solo wave (size=1)" "$WAVE6_COUNT" "1"
assert_eq "solo wave member is FA" \
  "$(echo "$WAVE_OUT" | jq -r '.wave[0].id')" "FA"

# ══════════════════════════════════════════════════════════════════════════════
echo ""
echo "=== Scenario 7: closes_milestone flag ==="
echo ""

WORK7="$(mktemp -d)"
WORK_DIRS+=("$WORK7")
build_fixture "$WORK7"

# Mark FA, FB, FC done; only FD (depends_on FA) remains — wave should close M1
TMP7="$FIXTURE_STATE.tmp.$$"
jq '
  (.features[] | select(.id=="FA")) |= (.status="done" | .commit_sha="aaa" | .attempts=1)
  | (.features[] | select(.id=="FB")) |= (.status="done" | .commit_sha="bbb" | .attempts=1)
  | (.features[] | select(.id=="FC")) |= (.status="done" | .commit_sha="ccc" | .attempts=1)
' "$FIXTURE_STATE" > "$TMP7" && mv "$TMP7" "$FIXTURE_STATE"
git -C "$FIXTURE_WT" add -- ".claude/missions/$FIXTURE_SLUG"
git -C "$FIXTURE_WT" commit -q -m "test: FA/FB/FC done"

pick_wave "$FIXTURE_SLUG" 3
assert_exit "pick-wave exits 0 (only FD remains)" "$WAVE_RC" 0
CLOSES="$(echo "$WAVE_OUT" | jq -r '.closes_milestone')"
assert_eq "closes_milestone=M1 when last feature in wave" "$CLOSES" "M1"

# ══════════════════════════════════════════════════════════════════════════════
echo ""
echo "=== Scenario 8: Crash -> reconcile-waves cleans slot leftovers (VC-9) ==="
echo ""

WORK8="$(mktemp -d)"
WORK_DIRS+=("$WORK8")
build_fixture "$WORK8"

# Build a wave of 2: FA in slot-1, FB in slot-2.
provision_slot "$FIXTURE_SLUG" "1" "FA"
SLOT_A8="$SLOT_PATH"
stub_coder_clean "$SLOT_A8" "FA" "feat-fa8.txt"

provision_slot "$FIXTURE_SLUG" "2" "FB"
SLOT_B8="$SLOT_PATH"
stub_coder_clean "$SLOT_B8" "FB" "feat-fb8.txt"

# Integrate FA fully (recorded done).
run_integrate "$FIXTURE_SLUG" "FA"
assert_exit "S8: integrate FA exits 0" "$INTEGRATE_RC" 0

FA8_SHA="$(state_get '.features[] | select(.id=="FA") | .commit_sha')"
assert_not_empty "S8: FA commit_sha recorded" "$FA8_SHA"
assert_eq "S8: FA status done" "$(state_get '.features[] | select(.id=="FA") | .status')" "done"

# Now simulate a crash for FB: its slot worktree and slot branch remain dangling.
# We do NOT call integrate for FB — it's still pending.
assert_eq "S8: FB still pending before crash-sim" \
  "$(state_get '.features[] | select(.id=="FB") | .status')" "pending"

# Slot-2 dir and branch should exist at this point.
SLOT_B_PATH="$FWD_MISSION_WORKTREE_DIR/mission/$FIXTURE_SLUG--slot-2"
SLOT_B_BRANCH="mission/$FIXTURE_SLUG--fb"
assert_file_present "S8: slot-2 dir exists before reconcile" "$SLOT_B_PATH"
BRANCH_BEFORE="$(git -C "$FIXTURE_REPO" branch --list "$SLOT_B_BRANCH")"
assert_not_empty "S8: slot branch exists before reconcile" "$BRANCH_BEFORE"

# Run reconcile-waves.sh.
RECONCILE8_RC=0
RECONCILE8_OUT="$(cd "$FIXTURE_REPO" && bash "$RECONCILE_WAVES" "$FIXTURE_SLUG" 2>&1)" \
  || RECONCILE8_RC=$?
assert_exit "S8: reconcile-waves exits 0" "$RECONCILE8_RC" 0

# FB's slot worktree must be gone.
assert_file_absent "S8: slot-2 dir removed by reconcile" "$SLOT_B_PATH"

# FB's slot branch must be gone.
BRANCH_AFTER="$(git -C "$FIXTURE_REPO" branch --list "$SLOT_B_BRANCH")"
assert_empty "S8: slot branch removed by reconcile" "$BRANCH_AFTER"

# FA's integrated commit still on mission branch (file present, state records done).
assert_file_present "S8: FA work intact on mission branch" "$FIXTURE_WT/feat-fa8.txt"
assert_eq "S8: FA still done after reconcile" \
  "$(state_get '.features[] | select(.id=="FA") | .status')" "done"
assert_not_empty "S8: FA commit_sha still recorded" \
  "$(state_get '.features[] | select(.id=="FA") | .commit_sha')"

# Mission worktree clean.
DIRTY8="$(git -C "$FIXTURE_WT" status --porcelain | grep -vx 'ok' || true)"
assert_empty "S8: mission tree clean after reconcile" "$DIRTY8"

# Serial reconcile.sh was invoked: its terminal output line must appear.
# It outputs "clean", "cleaned", or "adopted <fid>" — all three are valid here.
assert_contains "S8: serial reconcile output present" "$RECONCILE8_OUT" "clean"

# FB still pending (re-runnable next wave).
assert_eq "S8: FB still pending after reconcile" \
  "$(state_get '.features[] | select(.id=="FB") | .status')" "pending"

# ══════════════════════════════════════════════════════════════════════════════
echo ""
echo "=== Scenario 9: Second discard -> blocked (circuit breaker) ==="
echo ""

WORK9="$(mktemp -d)"
WORK_DIRS+=("$WORK9")
build_fixture "$WORK9"

# First attempt: create a conflicting solo wave for FB.
# Integrate FA first to advance the mission HEAD.
provision_slot "$FIXTURE_SLUG" "1" "FA"
SLOT_A9="$SLOT_PATH"
_git_slot "$SLOT_A9"
echo "FA owns shared.txt" > "$SLOT_A9/shared9.txt"
git -C "$SLOT_A9" add -- "shared9.txt"
git -C "$SLOT_A9" commit -q -m "feat(FA): write shared9.txt"
run_integrate "$FIXTURE_SLUG" "FA"
assert_exit "S9: FA integrates cleanly (baseline)" "$INTEGRATE_RC" 0

POST_FA9_HEAD="$(git -C "$FIXTURE_WT" rev-parse HEAD)"
# The commit just before FA's integration (initial-state HEAD)
INIT9_SHA="$(git -C "$FIXTURE_WT" rev-list HEAD | tail -1)"

# First conflict attempt for FB: branch from INIT_SHA (before FA) so cherry-pick conflicts.
FID_LOWER_B9="fb"
SLOT_BRANCH_B9="mission/$FIXTURE_SLUG--$FID_LOWER_B9"
SLOT_PATH_B9="$FWD_MISSION_WORKTREE_DIR/mission/$FIXTURE_SLUG--slot-2"
git -C "$FIXTURE_REPO" branch "$SLOT_BRANCH_B9" "$INIT9_SHA"
git -C "$FIXTURE_REPO" worktree add "$SLOT_PATH_B9" "$SLOT_BRANCH_B9" -q
git -C "$SLOT_PATH_B9" config user.email "coder@test.local"
git -C "$SLOT_PATH_B9" config user.name  "Stub Coder"
echo "FB conflicting content" > "$SLOT_PATH_B9/shared9.txt"
git -C "$SLOT_PATH_B9" add -- "shared9.txt"
git -C "$SLOT_PATH_B9" commit -q -m "feat(FB): conflict with FA on shared9.txt"

PRE_CONFLICT9="$(git -C "$FIXTURE_WT" rev-parse HEAD)"
run_integrate "$FIXTURE_SLUG" "FB"
assert_exit "S9: first integrate FB exits 3 (conflict)" "$INTEGRATE_RC" 3

assert_eq "S9: FB pinned serial_only=true after first conflict" \
  "$(state_get '.features[] | select(.id=="FB") | .serial_only')" "true"
assert_eq "S9: FB discards=1 after first conflict" \
  "$(state_get '.features[] | select(.id=="FB") | .discards')" "1"
assert_eq "S9: FB still pending after first conflict" \
  "$(state_get '.features[] | select(.id=="FB") | .status')" "pending"
assert_eq "S9: FB attempts unchanged (0) after conflict (no attempt consumed)" \
  "$(state_get '.features[] | select(.id=="FB") | .attempts')" "0"

# Mission tree must be clean after first discard.
DIRTY9A="$(git -C "$FIXTURE_WT" status --porcelain | grep -vx 'ok' || true)"
assert_empty "S9: mission tree clean after first conflict" "$DIRTY9A"

# Second attempt: re-create FB's slot, still conflicting (branching from before FA again).
# Remove old slot worktree / branch first (simulating reconcile-waves cleanup between waves).
git -C "$FIXTURE_REPO" worktree remove --force "$SLOT_PATH_B9" >/dev/null 2>&1 || \
  { rm -rf "$SLOT_PATH_B9"; git -C "$FIXTURE_REPO" worktree prune >/dev/null 2>&1 || true; }
git -C "$FIXTURE_REPO" branch -D "$SLOT_BRANCH_B9" >/dev/null 2>&1 || true

MISSION9_HEAD="$(git -C "$FIXTURE_WT" rev-parse HEAD)"
git -C "$FIXTURE_REPO" branch "$SLOT_BRANCH_B9" "$INIT9_SHA"
git -C "$FIXTURE_REPO" worktree add "$SLOT_PATH_B9" "$SLOT_BRANCH_B9" -q
git -C "$SLOT_PATH_B9" config user.email "coder@test.local"
git -C "$SLOT_PATH_B9" config user.name  "Stub Coder"
echo "FB conflicting content again" > "$SLOT_PATH_B9/shared9.txt"
git -C "$SLOT_PATH_B9" add -- "shared9.txt"
git -C "$SLOT_PATH_B9" commit -q -m "feat(FB): conflict again on shared9.txt"

run_integrate "$FIXTURE_SLUG" "FB"
assert_exit "S9: second integrate FB exits 6 (blocked)" "$INTEGRATE_RC" 6

assert_eq "S9: FB status=blocked after second conflict" \
  "$(state_get '.features[] | select(.id=="FB") | .status')" "blocked"
assert_eq "S9: FB attempts incremented on block" \
  "$(state_get '.features[] | select(.id=="FB") | .attempts')" "1"
# discards was set to 1 on the first-discard pin commit; record-feature.sh (blocked
# path) does not write the discards field — so the value stays at 1.  The important
# invariant is that it is >= 1 (at least one discard was recorded).
assert_not_empty "S9: FB discards >= 1 recorded (second discard triggers blocked path)" \
  "$(state_get '.features[] | select(.id=="FB") | .discards | select(. >= 1)')"

# Circuit breaker must have been incremented.
CB9="$(state_get '.circuit_breaker.consecutive_failures')"
assert_not_empty "S9: circuit_breaker incremented (non-zero)" \
  "$([ "$CB9" -gt 0 ] && echo yes || echo '')"

# Mission tree must be clean after second discard.
DIRTY9B="$(git -C "$FIXTURE_WT" status --porcelain | grep -vx 'ok' || true)"
assert_empty "S9: mission tree clean after second conflict (blocked)" "$DIRTY9B"

# FA's integrated work must still be present (mission HEAD untouched).
assert_file_present "S9: FA work intact after FB blocked" "$FIXTURE_WT/shared9.txt"
assert_eq "S9: FA still done" \
  "$(state_get '.features[] | select(.id=="FA") | .status')" "done"

# ── Summary ───────────────────────────────────────────────────────────────────
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Summary: $PASS_COUNT passed, $FAIL_COUNT failed ($ASSERTION_INDEX total assertions)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

if [[ "$FAIL_COUNT" -gt 0 ]]; then
  exit 1
fi
exit 0
