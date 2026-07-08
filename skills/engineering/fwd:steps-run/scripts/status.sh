#!/usr/bin/env bash
# Progress snapshot for steps-plans in the worktree model. Read-only — writes nothing,
# never checks out or creates a worktree (that's setup-worktree.sh). Resolves the main
# repo root itself, so it works from the main checkout OR from inside a steps worktree.
# Plans live on steps/<slug> branches; work happens in .trees/steps/<slug>.
# Usage:
#   status.sh            -> one line per steps-plan (from the steps/* branches)
#   status.sh <slug>     -> key=value detail (next step, worktree presence, dirty tree,
#                           and pending_autonomous_commit: yes when the dirty worktree holds
#                           an interrupted autonomous run's work, still awaiting one commit)
# Exit codes: 0 ok · 2 no such plan · 3 corrupt state.json
set -euo pipefail

command -v jq >/dev/null 2>&1 || { echo "missing-jq — install jq (brew install jq)" >&2; exit 1; }
REPO_ROOT="$(dirname "$(rtk git rev-parse --path-format=absolute --git-common-dir)")"
WT_DIR="${FWD_STEPS_WORKTREE_DIR:-$REPO_ROOT/.trees}"
SLUG="${1:-}"

# Echo a plan's state.json: from its worktree if materialised, else straight from the
# branch (committed) via `git show`. Empty output on failure.
read_state() {
  local slug="$1"
  local wt_state="$WT_DIR/steps/$slug/.claude/steps/$slug/state.json"
  if [[ -f "$wt_state" ]]; then
    cat "$wt_state"
  else
    ( cd "$REPO_ROOT" && rtk git show "steps/$slug:.claude/steps/$slug/state.json" 2>/dev/null || true )
  fi
}

if [[ -z "$SLUG" ]]; then
  # for-each-ref (not `branch --list --format`, which rtk reformats) for a clean list.
  mapfile -t BRANCHES < <( cd "$REPO_ROOT" && rtk git for-each-ref --format='%(refname:short)' 'refs/heads/steps/*' 2>/dev/null )
  if [[ ${#BRANCHES[@]} -eq 0 ]]; then
    echo "geen stappenplannen (geen steps/*-branch gevonden)"
    exit 0
  fi
  for br in "${BRANCHES[@]}"; do
    [[ -n "$br" ]] || continue
    s="${br#steps/}"
    js="$(read_state "$s")"
    if [[ -n "$js" ]] && jq -e . >/dev/null 2>&1 <<<"$js"; then
      wt="afwezig"; [[ -d "$WT_DIR/steps/$s" ]] && wt="actief"
      jq -r --arg wt "$wt" '"\(.slug)\t\(.status)\t\([.steps[] | select(.status == "done")] | length)/\(.steps | length) stappen\tbranch=\(.branch)\tworktree=\($wt)\t\(.title)"' <<<"$js"
    else
      printf '%s\tcorrupt-of-onleesbaar\n' "$br"
    fi
  done
  exit 0
fi

# --- detail for one slug ---
JS="$(read_state "$SLUG")"
if [[ -z "$JS" ]]; then
  echo "no-plan: geen state.json voor steps/$SLUG (branch of plan ontbreekt) — plan eerst met /fwd:steps-plan"
  ( cd "$REPO_ROOT" && rtk git for-each-ref --format='kandidaat-branch: %(refname:short)' 'refs/heads/steps/*' 2>/dev/null || true )
  exit 2
fi
jq -e . >/dev/null 2>&1 <<<"$JS" || { echo "corrupt-state: state.json voor steps/$SLUG is geen geldige JSON"; exit 3; }

WT_PATH="$WT_DIR/steps/$SLUG"
if [[ -d "$WT_PATH" ]]; then
  WT_STATE="present"
  DIRTY="$( cd "$WT_PATH" && rtk git status --porcelain | grep -vx 'ok' || true )"
else
  WT_STATE="absent"
  DIRTY=""
fi

jq -r --arg wt "$WT_STATE" --arg wtpath "$WT_PATH" --arg dirty "${DIRTY:+yes}" '
  ([.steps[] | select(.status == "done")] | length) as $done
  | (.steps | length) as $total
  | ([.steps[] | select(.status == "todo")] | first) as $next
  | ([.steps[] | select(.status == "done")] | sort_by(.approved_at) | last) as $lastdone
  | "slug=\(.slug)",
    "title=\(.title)",
    "status=\(.status)",
    "branch=\(.branch)",
    "base_branch=\(.base_branch)",
    "worktree=\($wt)",
    "worktree_path=\($wtpath)",
    "progress=\($done)/\($total)",
    "gate=\(.gate_command)",
    "dirty_tree=\(if $dirty == "yes" then "yes" else "no" end)",
    "pending_autonomous_commit=\(if ($dirty == "yes" and (($lastdone.approved_mode // "attended") == "autonomous")) then "yes" else "no" end)",
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
' <<<"$JS"

if [[ -n "$DIRTY" ]]; then
  printf 'dirty_files:\n%s\n' "$DIRTY"
fi
