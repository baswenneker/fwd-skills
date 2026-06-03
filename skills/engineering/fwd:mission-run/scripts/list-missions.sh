#!/usr/bin/env bash
# List every mission in this repo (from mission/* branches) and its status.
# Read-only; works without any worktree (reads state from each branch). Args: none.
set -uo pipefail

command -v jq >/dev/null 2>&1 || { echo "missing-jq"; exit 1; }
GCD="$(rtk git rev-parse --path-format=absolute --git-common-dir 2>/dev/null || true)"
[[ -z "$GCD" ]] && { echo "not-a-repo"; exit 1; }
REPO_ROOT="$(dirname "$GCD")"

mapfile -t BR < <(rtk git for-each-ref --format='%(refname:short)' 'refs/heads/mission/*' 2>/dev/null)
if [[ ${#BR[@]} -eq 0 ]]; then
  echo "no missions yet — plan one with /fwd:mission-plan"
  exit 0
fi

printf '%-30s %-12s %-10s %s\n' "SLUG" "STATUS" "FEATURES" "MILESTONES"
for br in "${BR[@]}"; do
  slug="${br#mission/}"
  st="$(rtk git show "$br:.claude/missions/$slug/state.json" 2>/dev/null || true)"
  if [[ -z "$st" ]] || ! jq -e . >/dev/null 2>&1 <<<"$st"; then
    printf '%-30s %-12s %-10s %s\n' "$slug" "?" "—" "(no state)"
    continue
  fi
  status="$(jq -r '.status' <<<"$st")"
  feats="$(jq -r '"\([.features[]|select(.status=="done")]|length)/\(.features|length)"' <<<"$st")"
  miles="$(jq -r '"\([.milestones[]|select(.validation_status=="passed" or .validation_status=="gates_passed")]|length)/\(.milestones|length)"' <<<"$st")"
  printf '%-30s %-12s %-10s %s\n' "$slug" "$status" "$feats" "$miles"
done

echo
echo "run/resume: /fwd:mission-run <slug>    detail: /fwd:mission-run <slug> status"
