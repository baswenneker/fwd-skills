# fwd:issue-fix — reference

Design rationale, configuration, and recovery procedures for `fwd:issue-fix`.

## Why this shape

Built on the lessons of the Ralph Wiggum technique ([ghuntley.com/ralph](https://ghuntley.com/ralph/)) and the failure modes documented in [`claude-code` issues](https://github.com/anthropics/claude-code/issues). Four principles:

1. **Bash for state, Claude for code.** Deterministic ops (locking, picking, verifying) are bash scripts that exit fast and predictably. Reasoning + editing is Claude's job. Hangs in long-running loops almost always come from blurring this line.
2. **Local state, read-only GitHub.** No label state machine. The state file is a JSON ledger you can `jq`/edit by hand. Mainstream loop projects mutate GitHub labels (`claude-ready` → `agent-working` → `agent-done`); we explicitly don't.
3. **One tick = one issue, one fresh context.** `/loop` re-fires the skill so each issue gets a clean Claude session. Keeps the context window from growing unboundedly through the night.
4. **Stealth.** This is a private overnight automation. Collaborators reviewing the eventual push should see normal commits on a normal branch, not "Co-Authored-By: Claude" or labelled state on the issue tracker. Read-only GH + no-push + no AI-attribution footers is what makes that work.

### Why GitHub stays read-only

The mainstream pattern (CCPM, claudecode-patterns) flips labels as a state machine. That's robust for *team-visible* automation: everyone can see the queue. We explicitly avoid it because:

- **Visibility leak.** A label like `agent-working` on an issue tells your team an agent is doing the work. You don't want that.
- **Partial-write risk.** A tick that crashes between label change and commit leaves GH in an inconsistent state. Local state can be cleaned up trivially; GH state requires API calls.
- **Single-machine simplicity.** Without GH state we don't need to coordinate across runners — and we don't want to anyway, since this is your private overnight setup.

Trade-off: if you ever do want team-visible automation, this skill is the wrong shape. Fork it, swap the state file for label calls, and add `gh pr create`.

## State file

Location: `<repo>/.claude/issue-loop/state.json`. Atomic writes only (scripts use `mv` over `.tmp.$$`).

```json
{
  "version": 1,
  "issues": {
    "42": {
      "status": "done",
      "branch": "feat/import-csv-from-clipboard",
      "worktree": "/abs/path/.trees/feat/import-csv-from-clipboard",
      "started_at": "2026-05-09T22:01:00Z",
      "started_at_epoch": 1715212860,
      "completed_at": "2026-05-09T22:14:30Z",
      "commit_sha": "abc1234",
      "commits": 3
    },
    "43": {
      "status": "blocked",
      "branch": "fix/parser-keyerror-on-missing-key",
      "worktree": "/abs/path/.trees/fix/parser-keyerror-on-missing-key",
      "started_at": "2026-05-09T22:15:00Z",
      "started_at_epoch": 1715213700,
      "completed_at": "2026-05-09T22:23:11Z",
      "error": "tests in tests/parser_test.py kept failing after 3 attempts: KeyError 'foo'"
    }
  },
  "circuit_breaker": { "consecutive_failures": 0 }
}
```

Statuses: `in_progress` | `done` | `blocked`.

## Configuration

| Env var | Default | Notes |
|---|---|---|
| `FWD_ISSUE_FIX_BASE_BRANCH` | `main` | Branch worktrees are based on |
| `FWD_ISSUE_FIX_WORKTREE_DIR` | `<repo>/.trees` | Root for worktrees (each lands at `<dir>/<type>/<name>/`) |

Add to `.gitignore`:

```
.trees/
.claude/issue-loop/
```

## Why these specific guardrails

| Guardrail | Why |
|---|---|
| 3 implementation attempts per tick | Beyond this an issue almost always needs human input. Cheaper to fail fast than burn tokens. |
| Stale-lock recovery at 60 min | A tick that didn't terminate (sleeping laptop, killed process, network hang) gets recovered automatically next tick. |
| Circuit breaker at 3 consecutive failures | If the agent fails repeatedly, something systemic is wrong (broken CI, env mismatch). Stop instead of chewing through the queue. |
| Tests must pass before `done` | Without this, `done` means nothing. The whole point is reviewable diffs. |
| Symlink `.claude/` into worktree | Works around [CC#28041](https://github.com/anthropics/claude-code/issues/28041); without it the worktree session has no skills/hooks/settings. |
| `timeout 30s` on `gh` | Prevents network-induced hangs ([CC#25979](https://github.com/anthropics/claude-code/issues/25979)). |

## Reviewing the night's work

```bash
# Summary of what got done / blocked
jq -r '.issues
  | to_entries
  | sort_by(.value.completed_at)
  | .[]
  | "\(.value.completed_at // "—") \(.value.status) #\(.key) \(.value.branch // "")"
' .claude/issue-loop/state.json

# Inspect a fix (worktree path comes from .value.worktree in state.json)
cd .trees/feat/import-csv-from-clipboard
rtk git log --oneline main..HEAD
rtk git diff main..HEAD

# Push when satisfied
rtk git push -u origin feat/import-csv-from-clipboard
gh pr create --fill --base main
```

## Resetting

```bash
# Wipe state + worktrees + the branches the skill created; start fresh.
# Drop branches *before* wiping state.json — that's where their names live.
jq -r '.issues|to_entries[]|.value.branch // empty' .claude/issue-loop/state.json 2>/dev/null \
  | xargs -r rtk git branch -D 2>/dev/null
rm -rf .claude/issue-loop .trees
rtk git worktree prune
```

## Re-attempting a blocked issue

```bash
# Drop the issue from state so the next tick picks it up again
ISSUE=42
jq --arg n "$ISSUE" 'del(.issues[$n])' .claude/issue-loop/state.json > /tmp/x \
  && mv /tmp/x .claude/issue-loop/state.json
```

## Resetting the circuit breaker

```bash
jq '.circuit_breaker.consecutive_failures=0' .claude/issue-loop/state.json > /tmp/x \
  && mv /tmp/x .claude/issue-loop/state.json
```

## Limits this skill does NOT enforce

- **Wall-clock timeout per tick.** Use `/loop <interval>` to space ticks, or interrupt manually if a tick wedges. The 3-attempt cap inside the prompt is your primary defence.
- **Token-cost cap.** Claude Code itself doesn't expose a per-session limit. Pair with whatever budget guards you already use.
- **Multi-runner coordination.** State file is local; multiple machines running this skill on the same repo will collide. Single-runner only.
- **Push / PR creation.** Out of scope by design — the human reviews and pushes.

## Sources

- [Ralph Wiggum technique](https://ghuntley.com/ralph/)
- [continuous-claude](https://github.com/AnandChowdhary/continuous-claude) — circuit breaker & cost caps
- [automazeio/ccpm](https://github.com/automazeio/ccpm) — label state machine (we explicitly don't do this)
- [git worktrees + AI agents (Mitchinson)](https://www.nrmitchi.com/2025/10/using-git-worktrees-for-multi-feature-development-with-ai-agents/)
- [CC#28041 — `.claude/` not copied to worktree](https://github.com/anthropics/claude-code/issues/28041)
- [CC#25979 — streaming hang](https://github.com/anthropics/claude-code/issues/25979)
- [CC#49150 — `Task()` no timeout](https://github.com/anthropics/claude-code/issues/49150)
