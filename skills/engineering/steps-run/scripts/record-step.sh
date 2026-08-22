#!/usr/bin/env bash
# Record the approval of ONE step: mark it done in state.json (merging any deferrals from
# stdin) and tick the plan.md checkbox. Without --no-commit it then commits code + state
# atomically (the tree was clean when the step started, so everything dirty now IS the step).
# With --no-commit it updates state + checkbox but commits nothing and leaves HEAD untouched
# — the accumulating path, taken when `auto` starts mid-run on top of uncommitted work and
# ends in one commit via finalize-autonomous.sh.
# The choice is recorded on the step as approved_mode, which names the COMMIT REGIME, not who
# approved: attended = its own commit (the per-step `ok`, and every step of a run that was
# autonomous from the start — same clean-tree assumption), autonomous = accumulated, still
# owed a commit. status.sh derives pending_autonomous_commit from exactly that.
# --state-only records a step that changes no code at all — a pure validation step whose
# done criterion is a command's output. The dirty-tree requirement is lifted (a clean tree
# is exactly the expected shape) and only .claude/steps/<slug>/ is committed. Any dirty path
# outside that directory means this is NOT a validation step: refused, use the normal form.
# Usage:
#   echo '{"deferrals":[{"note":"…","when":"…"}]}' | record-step.sh [--no-commit|--state-only] <slug> <step-id> "<commit message>"
#   (stdin is optional; --no-commit and --state-only are mutually exclusive)
# Stdout: recorded=<id> · progress=<done>/<total> · status=<plan status> · interim_review=due|not-due
set -euo pipefail

NO_COMMIT=0
STATE_ONLY=0
while true; do
  case "${1:-}" in
    --no-commit)  NO_COMMIT=1; shift ;;
    --state-only) STATE_ONLY=1; shift ;;
    *) break ;;
  esac
done
[[ "$NO_COMMIT" -eq 1 && "$STATE_ONLY" -eq 1 ]] \
  && { echo "--no-commit and --state-only are mutually exclusive" >&2; exit 1; }
SLUG="${1:?usage: record-step.sh [--no-commit|--state-only] <slug> <step-id> \"<commit message>\"}"
SID="${2:?step-id required (e.g. S3)}"
MSG="${3:?commit message required}"
MODE="attended"; [[ "$NO_COMMIT" -eq 1 ]] && MODE="autonomous"
command -v jq >/dev/null 2>&1 || { echo "missing-jq — install jq (brew install jq)" >&2; exit 1; }

REPO_ROOT="$(rtk git rev-parse --show-toplevel)"
STATE="$REPO_ROOT/.claude/steps/$SLUG/state.json"
PLAN_MD="$REPO_ROOT/.claude/steps/$SLUG/plan.md"
[[ -f "$STATE" ]] || { echo "state.json missing: $STATE" >&2; exit 1; }

# Guard: only ever commit onto the plan's own branch. A worktree left on the base branch
# (or any other) would otherwise bury the step commit where the run can't find it.
WANT_BRANCH="$(jq -r '.branch // empty' "$STATE")"
HEAD_BRANCH="$(rtk git rev-parse --abbrev-ref HEAD)"
if [[ -n "$WANT_BRANCH" && "$HEAD_BRANCH" != "$WANT_BRANCH" ]]; then
  echo "refusing to commit: worktree HEAD is '$HEAD_BRANCH', expected '$WANT_BRANCH' (.branch)" >&2
  exit 1
fi

jq -e --arg s "$SID" 'any(.steps[]; .id == $s and .status == "todo")' "$STATE" >/dev/null \
  || { echo "no open step '$SID' in $SLUG (already done, skipped, or unknown)" >&2; exit 1; }

DIRTY="$(rtk git status --porcelain | grep -vx 'ok' || true)"
if [[ "$STATE_ONLY" -eq 1 ]]; then
  # A clean tree is the expected shape here. What must NOT be there is changed code:
  # that would mean this is a normal step recorded with the wrong flag.
  CODE_DIRTY="$(grep -v "^.. \.claude/steps/$SLUG/" <<<"$DIRTY" || true)"
  [[ -z "$CODE_DIRTY" ]] || {
    echo "--state-only refused: the working tree has changes outside .claude/steps/$SLUG/ — record $SID without the flag" >&2
    echo "$CODE_DIRTY" >&2
    exit 1
  }
else
  [[ -n "$DIRTY" ]] || { echo "nothing to commit — the working tree has no changes for $SID" >&2; exit 1; }
fi

# Optional deferrals JSON on stdin.
DEFERRALS='[]'
if [[ ! -t 0 ]]; then
  IN="$(cat)"
  if [[ -n "$IN" ]] && jq -e '.deferrals | type == "array"' >/dev/null 2>&1 <<<"$IN"; then
    DEFERRALS="$(jq -c '.deferrals' <<<"$IN")"
  fi
fi

NOW="$(date -u +%FT%TZ)"
TMP="$(mktemp)"
trap 'rm -f "$TMP"' EXIT

jq --arg s "$SID" --arg t "$NOW" --arg mode "$MODE" --argjson d "$DEFERRALS" '
  (.steps[] | select(.id == $s)) |= (.status = "done" | .approved_at = $t | .approved_mode = $mode | .deferrals += $d)
  | .status = (if all(.steps[]; .status != "todo") then "done" else "in_progress" end)
  | .completed_at = (if .status == "done" then $t else .completed_at end)
' "$STATE" > "$TMP"
mv "$TMP" "$STATE"
trap - EXIT

# Tick the checkbox; a missing match is a warning, never a failure.
if [[ -f "$PLAN_MD" ]] && grep -q "^- \[ \] $SID " "$PLAN_MD"; then
  TMP_MD="$(mktemp)"
  sed "s/^- \[ \] $SID /- [x] $SID /" "$PLAN_MD" > "$TMP_MD"
  mv "$TMP_MD" "$PLAN_MD"
else
  echo "note: no '- [ ] $SID ' checkbox found in plan.md — state.json is the source of truth" >&2
fi

if [[ "$NO_COMMIT" -eq 1 ]]; then
  echo "--no-commit: state + plan.md updated, HEAD left untouched" >&2
elif [[ "$STATE_ONLY" -eq 1 ]]; then
  # Only the run's own bookkeeping — there is no code to carry.
  rtk git add ".claude/steps/$SLUG" >&2
  rtk git commit -m "$MSG" >&2
else
  rtk git add -A >&2
  rtk git commit -m "$MSG" >&2
fi

DONE="$(jq -r '[.steps[] | select(.status == "done")] | length' "$STATE")"
TOTAL="$(jq -r '.steps | length' "$STATE")"
STATUS="$(jq -r '.status' "$STATE")"

# Interim review is due after every 4th approved step, except when the plan just finished
# (the final report covers that moment).
INTERIM="not-due"
if [[ "$STATUS" != "done" && $((DONE % 4)) -eq 0 ]]; then INTERIM="due"; fi

echo "recorded=$SID"
echo "progress=$DONE/$TOTAL"
echo "status=$STATUS"
echo "interim_review=$INTERIM"
