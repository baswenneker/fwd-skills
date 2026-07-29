#!/usr/bin/env bash
# Record the approval of ONE step: mark it done in state.json (merging any deferrals from
# stdin) and tick the plan.md checkbox. In attended mode it then commits code + state
# atomically (the tree was clean when the step started, so everything dirty now IS the step).
# With --no-commit it updates state + checkbox but commits nothing and leaves HEAD untouched
# — the autonomous path, which accumulates steps and makes one commit at the end of the run.
# The mode is recorded on the step as approved_mode (attended | autonomous).
# Usage:
#   echo '{"deferrals":[{"note":"…","when":"…"}]}' | record-step.sh [--no-commit] <slug> <step-id> "<commit message>"
#   (stdin is optional)
# Stdout: recorded=<id> · progress=<done>/<total> · status=<plan status> · interim_review=due|not-due
set -euo pipefail

NO_COMMIT=0
if [[ "${1:-}" == "--no-commit" ]]; then NO_COMMIT=1; shift; fi
SLUG="${1:?usage: record-step.sh [--no-commit] <slug> <step-id> \"<commit message>\"}"
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
[[ -n "$DIRTY" ]] || { echo "nothing to commit — the working tree has no changes for $SID" >&2; exit 1; }

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
else
  rtk git add -A
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
