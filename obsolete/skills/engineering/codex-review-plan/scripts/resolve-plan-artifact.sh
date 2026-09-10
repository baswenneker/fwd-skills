#!/usr/bin/env bash
# Resolve a plan artifact across the three plan-artefact families: fwd:plan's
# plan-contracts (always a plain file), fwd:mission-plan's missions (branch +
# worktree), fwd:steps-plan's steps-plans (branch + worktree). Read-only; writes
# nothing, creates no worktree.
#
# Reuses the worktree-first -> plain-file -> `git show <branch>:<path>` fallback
# chain that fwd:mission-run's preflight.sh/list-missions.sh and fwd:steps-run's
# status.sh already use per family. What neither existing lister does is UNION
# the three families: list-missions.sh and steps-run's status.sh each only walk
# their own refs/heads/{mission,steps}/* namespace, so a plan whose branch was
# already merged-and-deleted (its files now plain on the base branch) is
# invisible to them even though it fully exists on disk.
#
# Usage: resolve-plan-artifact.sh [<slug>]
#   no slug  -> the single most-recently-resolved-at candidate across all 3 families
#   <slug>   -> exact-slug match; ambiguous across families -> lists all, exit 2
#
# Stdout (key=value lines) for one resolved candidate:
#   family=plan-contract|mission|steps
#   slug=<slug>
#   path_or_branch=<absolute path>|<branch name>   (leading "/" = a real path; else a branch ref)
#   resolved_at=<ISO-8601 date/datetime, as recorded by the artifact itself>
#   branch=<branch>            (mission/steps only)
#   base_branch=<base>         (mission/steps only)
#
# On ambiguity (slug matches >1 family), stdout is "ambiguous:<n>" followed by
# one such block per match, separated by a "---" line. Exit codes:
#   0 resolved · 1 not found / no candidates · 2 ambiguous
# missing-jq / not-a-repo go to stderr, exit 1.
set -uo pipefail

command -v jq >/dev/null 2>&1 || { echo "missing-jq" >&2; exit 1; }
GCD="$(rtk git rev-parse --path-format=absolute --git-common-dir 2>/dev/null || true)"
[[ -z "$GCD" ]] && { echo "not-a-repo" >&2; exit 1; }
REPO_ROOT="$(dirname "$GCD")"

WANT_SLUG="${1:-}"
MISSION_WT_DIR="${FWD_MISSION_WORKTREE_DIR:-$REPO_ROOT/.trees}"
STEPS_WT_DIR="${FWD_STEPS_WORKTREE_DIR:-$REPO_ROOT/.trees}"

# Candidate record (tab-separated): family  slug  path_or_branch  resolved_at  branch  base_branch
# plan-contract rows leave the last two fields empty (no branch/worktree concept).

collect_plan_contracts() {
  local f slug raw_date
  shopt -s nullglob
  for f in "$REPO_ROOT"/.claude/plan-contracts/*.md; do
    slug="$(basename "$f" .md)"
    raw_date="$(grep -m1 -oE 'Vastgelegd: [0-9]{4}-[0-9]{2}-[0-9]{2}' "$f" 2>/dev/null | sed 's/Vastgelegd: //')"
    if [[ -z "$raw_date" ]]; then
      raw_date="$(TZ=UTC date -r "$(stat -f %m "$f" 2>/dev/null || stat -c %Y "$f" 2>/dev/null || echo 0)" +%Y-%m-%d 2>/dev/null || echo "1970-01-01")"
    fi
    printf 'plan-contract\t%s\t%s\t%sT00:00:00Z\t\t\n' "$slug" "$f" "$raw_date"
  done
  shopt -u nullglob
}

# collect_branch_family <branch_prefix> <claude_dirname> <worktree_dir>
# branch_prefix: the refs/heads/<prefix>/* and .trees/<prefix>/<slug> word (mission | steps).
# claude_dirname: the .claude/<dirname>/<slug>/ word — "missions" (plural) for the
# mission family, "steps" for the steps family. The two differ for missions on purpose
# (mirrors preflight.sh's own STATE_REL vs BRANCH split) — don't collapse them.
collect_branch_family() {
  local prefix="$1" dirname="$2" wtdir="$3"
  local slug branch wt_state plain_state state root date branch_val base
  {
    for d in "$REPO_ROOT/.claude/$dirname"/*/; do
      [[ -d "$d" ]] && basename "$d"
    done
    rtk git for-each-ref --format='%(refname:short)' "refs/heads/$prefix/*" 2>/dev/null | sed "s#^$prefix/##"
  } 2>/dev/null | sort -u | while IFS= read -r slug; do
    [[ -n "$slug" ]] || continue
    branch="$prefix/$slug"
    wt_state="$wtdir/$prefix/$slug/.claude/$dirname/$slug/state.json"
    plain_state="$REPO_ROOT/.claude/$dirname/$slug/state.json"
    if [[ -f "$wt_state" ]]; then
      state="$(cat "$wt_state")"; root="$(dirname "$wt_state")"
    elif [[ -f "$plain_state" ]]; then
      state="$(cat "$plain_state")"; root="$(dirname "$plain_state")"
    else
      state="$(rtk git show "$branch:.claude/$dirname/$slug/state.json" 2>/dev/null || true)"
      root="$branch"
    fi
    [[ -n "$state" ]] || continue
    jq -e . >/dev/null 2>&1 <<<"$state" || continue
    date="$(jq -r '.completed_at // .created_at // empty' <<<"$state")"
    [[ -n "$date" ]] || date="$(rtk git log -1 --format=%cI "$branch" 2>/dev/null || echo "1970-01-01T00:00:00Z")"
    branch_val="$(jq -r '.branch // empty' <<<"$state")"; [[ -n "$branch_val" ]] || branch_val="$branch"
    base="$(jq -r '.base_branch // "main"' <<<"$state")"
    printf '%s\t%s\t%s\t%s\t%s\t%s\n' "$prefix" "$slug" "$root" "$date" "$branch_val" "$base"
  done
}

emit_block() {  # emit_block <tab-separated candidate line>
  local family slug root date branch base
  IFS=$'\t' read -r family slug root date branch base <<<"$1"
  printf 'family=%s\nslug=%s\npath_or_branch=%s\nresolved_at=%s\n' "$family" "$slug" "$root" "$date"
  [[ "$family" == "plan-contract" ]] || printf 'branch=%s\nbase_branch=%s\n' "$branch" "$base"
}

ALL="$(
  collect_plan_contracts
  collect_branch_family mission missions "$MISSION_WT_DIR"
  collect_branch_family steps steps "$STEPS_WT_DIR"
)"

if [[ -z "$WANT_SLUG" ]]; then
  [[ -n "$ALL" ]] || { echo "no-candidates" >&2; exit 1; }
  BEST="$(sort -t "$(printf '\t')" -k4,4 -r <<<"$ALL" | head -1)"
  emit_block "$BEST"
  exit 0
fi

MATCHES="$(awk -F'\t' -v s="$WANT_SLUG" '$2 == s' <<<"$ALL")"
if [[ -z "$MATCHES" ]]; then
  echo "not-found:$WANT_SLUG" >&2
  exit 1
fi

N="$(wc -l <<<"$MATCHES" | tr -d ' ')"
if [[ "$N" -eq 1 ]]; then
  emit_block "$MATCHES"
  exit 0
fi

echo "ambiguous:$N"
while IFS= read -r line; do
  emit_block "$line"
  echo "---"
done <<<"$MATCHES"
exit 2
