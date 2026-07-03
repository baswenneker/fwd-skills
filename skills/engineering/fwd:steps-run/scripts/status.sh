#!/usr/bin/env bash
# Progress snapshot for steps-plans. Read-only — writes nothing.
# Usage:
#   status.sh            → one line per steps-plan in the current checkout
#   status.sh <slug>     → key=value detail for one plan (next step, branch check, dirty tree)
# Exit codes: 0 ok · 2 no such plan in this checkout · 3 corrupt state.json
set -euo pipefail

command -v jq >/dev/null 2>&1 || { echo "missing-jq — install jq (brew install jq)" >&2; exit 1; }
REPO_ROOT="$(rtk git rev-parse --show-toplevel)"
STEPS_ROOT="$REPO_ROOT/.claude/steps"
SLUG="${1:-}"

if [[ -z "$SLUG" ]]; then
  found=0
  if [[ -d "$STEPS_ROOT" ]]; then
    for st in "$STEPS_ROOT"/*/state.json; do
      [[ -f "$st" ]] || continue
      found=1
      jq -r '"\(.slug)\t\(.status)\t\([.steps[] | select(.status == "done")] | length)/\(.steps | length) stappen\tbranch=\(.branch)\t\(.title)"' "$st" \
        || printf '%s\tcorrupt-state\n' "$st"
    done
  fi
  if [[ $found -eq 0 ]]; then
    echo "geen stappenplannen in deze checkout"
    BRANCHES="$(rtk git branch --list 'steps/*' --format='%(refname:short)' 2>/dev/null || true)"
    [[ -n "$BRANCHES" ]] && printf 'wel steps-branches aanwezig (eerst uitchecken):\n%s\n' "$BRANCHES"
  fi
  exit 0
fi

STATE="$STEPS_ROOT/$SLUG/state.json"
if [[ ! -f "$STATE" ]]; then
  echo "no-plan: $STATE ontbreekt — staat de checkout op de juiste branch?"
  rtk git branch --list 'steps/*' --format='kandidaat-branch: %(refname:short)' 2>/dev/null || true
  exit 2
fi
jq -e . "$STATE" >/dev/null 2>&1 || { echo "corrupt-state: $STATE is geen geldige JSON"; exit 3; }

CURRENT="$(rtk git rev-parse --abbrev-ref HEAD)"
DIRTY="$(rtk git status --porcelain | grep -vx 'ok' || true)"

jq -r --arg current "$CURRENT" --arg dirty "${DIRTY:+yes}" '
  ([.steps[] | select(.status == "done")] | length) as $done
  | (.steps | length) as $total
  | ([.steps[] | select(.status == "todo")] | first) as $next
  | "slug=\(.slug)",
    "title=\(.title)",
    "status=\(.status)",
    "branch=\(.branch)",
    "branch_mismatch=\(if .branch == $current then "no" else "yes (checkout staat op \($current))" end)",
    "progress=\($done)/\($total)",
    "gate=\(.gate_command)",
    "dirty_tree=\(if $dirty == "yes" then "yes" else "no" end)",
    (if $next == null then
      "next=none — alle stappen zijn done of skipped"
    else
      "next_id=\($next.id)",
      "next_nr=\((.steps | map(.id) | index($next.id)) + 1)/\($total)",
      "next_title=\($next.title)",
      "next_behavior=\($next.behavior)",
      "next_criterion_type=\($next.done_criterion.type)",
      "next_criterion=\($next.done_criterion.value)\(if $next.done_criterion.expected then " → verwacht: \($next.done_criterion.expected)" else "" end)",
      "next_rules=\(if ($next.rule_paths | length) == 0 then "geen" else ($next.rule_paths | join(", ")) end)"
    end)
' "$STATE"

if [[ -n "$DIRTY" ]]; then
  printf 'dirty_files:\n%s\n' "$DIRTY"
fi
