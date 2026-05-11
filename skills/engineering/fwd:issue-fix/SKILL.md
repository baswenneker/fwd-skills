---
name: fwd:issue-fix
description: Privately work through your assigned GitHub issues overnight — pick the oldest open issue, fix it in an isolated worktree, run tests, commit (no push). Driven by /loop. Strictly read-only on GitHub (no labels, no comments, no PRs) so collaborators can't tell the work was automated; all state local in `.claude/issue-loop/state.json`. Use when user says "work through my GitHub issues overnight", runs `/loop /fwd:issue-fix`, or invokes `/fwd:issue-fix` to fix one issue.
---

# fwd:issue-fix

One open GitHub issue → one worktree → one commit. Driven by `/loop`. State lives in `.claude/issue-loop/state.json`.

**Stealth principle.** This is a *private* automation. Collaborators must not be able to tell that the work was done autonomously. That means:

- **GitHub stays read-only** — no label changes, no comments, no closing, no `gh pr create`.
- **Nothing gets pushed** — branches stay local until you push them yourself after morning review.
- **Commits look human-authored** — use a normal commit message (via `/fwd:git-commit`); do **not** add `Co-Authored-By: Claude` or "Generated with Claude Code" footers.

**Autonomous-mode principle.** This skill runs unattended, often overnight. There is nobody at the keyboard to answer questions. Every branch must resolve deterministically.

- **Never call `AskUserQuestion`.** Not for confirmations, not for clarifications, not "just to be safe". The user has explicitly forbidden it for this skill.
- **Never call `ExitPlanMode`.** Plan mode prompts the user for approval. Plan internally instead, then act.
- **Never use interactive shell flags** (`-i`, `--interactive`, `git rebase -i`, etc.).
- **When you would normally ask, decide and log.** Pick the conservative option — "stop this tick cleanly" beats "modify the user's tree". Decisions taken on the user's behalf are recorded in `state.json` under `decisions[]` (preflight does this automatically; you do it via `${CLAUDE_SKILL_DIR}/scripts/log-decision.sh` in step 4 if needed).
- **Ambiguity is not a question for the user.** If the issue is unclear or the right fix requires their input, call `finalize.sh blocked <N> "<reason>"` — the user reviews blocked issues in the morning.

## Quick start

```
# Standalone — fix one issue:
/fwd:issue-fix

# Overnight — fix issues until queue empty or circuit breaker trips:
/loop /fwd:issue-fix
```

`/loop` re-fires this skill repeatedly. Each tick = one issue + fresh context. When no pickable issue remains, the tick exits cleanly with `no-work`.

## Per-tick flow

Run the bundled scripts in this exact order. Stop the tick on the first non-zero exit.

### 1. Preflight

```
bash "${CLAUDE_SKILL_DIR}/scripts/preflight.sh"
```

Verifies `gh` auth, repo state, circuit breaker (3 consecutive failures = stop). Auto-recovers stale `in_progress` locks (>60 min old) by marking them `blocked`. On any non-ok exit, preflight also appends a `{situation, action: "skip-tick"}` entry to `state.json.decisions[]` so morning-review can see what happened.

If the first line is `ok` (or `ok — recovered stale lock on issue #N`), continue to step 2. **For every other output, stop the tick cleanly** — report the line and exit. Do NOT prompt the user about how to recover (see "Autonomous-mode principle").

| Preflight output | Action |
|---|---|
| `not-a-repo` | Stop tick. |
| `missing-jq` | Stop tick. |
| `gh-not-authenticated` | Stop tick. |
| `main-checkout-dirty` | Stop tick. **Never** stash, commit, or reset on the user's behalf — they may have unfinished work. `/loop` retries next tick. |
| `circuit-breaker-tripped` | Stop tick. Reset is a manual step (see REFERENCE.md). |

### 2. Pick next issue

```
bash "${CLAUDE_SKILL_DIR}/scripts/pick-issue.sh"
```

Outputs JSON `{"number":N,"title":"...","body":"..."}` for the oldest open issue assigned to `@me` that is not already `done`/`blocked`/`in_progress` in state. Empty output = no work; report `no-work` and stop the tick (do NOT call setup-worktree).

### 3. Setup worktree

First derive two values from the pick-issue output (title + body):

- **`<type>`** — one of `fix`, `feat`, `chore`, `docs`, `refactor`, `perf`, `test`, `build`, `ci`, `style`. Judge it the way `fwd:git-commit` does: bug → `fix`; new capability → `feat`; tooling/repo housekeeping → `chore`; docs-only edit → `docs`; etc. Strip any leading `Type:` from the issue title before judging.
- **`<name>`** — kebab-case slug derived from what's left of the title. Drop articles and the conventional-prefix verb (add/update/fix/etc); keep ≤50 chars. Example: `Fix: dropdown stays open after Esc on Safari` → `dropdown-stays-open-after-esc-safari`.

Then:

```
bash "${CLAUDE_SKILL_DIR}/scripts/setup-worktree.sh" <N> <type> <name>
```

Branch `<type>/<name>` off `main`, worktree `.trees/<type>/<name>`. Symlinks `.claude/` into the worktree (CC#28041 workaround). Locks state to `in_progress`. Prints absolute worktree path on stdout.

### 4. Fix the issue (your job, Claude)

- Read full issue context: `rtk gh issue view <N> --json title,body,labels,comments`.
- `cd` into the worktree path from step 3.
- Plan internally (no `ExitPlanMode`) → implement → run tests. **Hard cap: 3 implementation attempts per tick.** If still failing after 3 attempts, go to step 5b.
- Commit using `/fwd:git-commit` (or plain `rtk git commit`). Include `Refs #<N>` in the message body so reviewers can trace it back. Do **not** add `Co-Authored-By: Claude` or other AI-attribution footers — see "Stealth principle" above.
- **Never** `rtk git push`. **Never** mutate GitHub (no `gh issue edit/comment/close`, no `gh pr create`).
- **Never prompt the user.** Re-read the Autonomous-mode principle. If the issue is ambiguous, the repro impossible, or you'd need to ask for a clarification — go to 5b with reason `"needs-human-input: <one-line summary>"`. If a non-blocking design decision arises mid-fix (e.g. choosing between two equally valid approaches), pick the more conservative one, log it with `bash "${CLAUDE_SKILL_DIR}/scripts/log-decision.sh" <N> "<situation>" "<action-taken>"`, and continue.

### 5a. Success → finalize

```
bash "${CLAUDE_SKILL_DIR}/scripts/finalize.sh" ok <N>
```

Verifies tests pass, ≥1 commit on the branch, working tree clean. Marks `done`, resets circuit breaker, leaves the worktree intact for review.

### 5b. Failure → block and continue

```
bash "${CLAUDE_SKILL_DIR}/scripts/finalize.sh" blocked <N> "<short reason>"
```

Removes the worktree, drops the branch, marks `blocked`, increments the circuit breaker. Tick exits cleanly so `/loop` can fire the next one.

## Hard limits — do not override

- 3 implementation attempts per issue per tick.
- Tests must pass before `finalize.sh ok`.
- Circuit breaker: 3 consecutive `blocked` issues → preflight refuses to start.
- Stale lock recovery: `in_progress` >60 min → auto-marked `blocked`.

## Boundaries

- **GitHub is read-only.** Never run `gh issue edit/comment/close`, `gh pr create`, `gh repo edit`. Only `gh issue list` and `gh issue view`.
- **Never push.** Branches stay local until you review them and push yourself.
- **No AI-attribution footers** in commit messages — collaborators reviewing the diff should see normal authorship.
- **Never reattempt** an issue already in state with `done` or `blocked`. Manual state edit required.
- **No PRs.** This skill commits — that's it.

## Reviewing the night's work

```
jq -r '.issues|to_entries[]|"\(.key) \(.value.status) \(.value.branch // "")"' .claude/issue-loop/state.json
cd .trees/<type>/<name> && rtk git log --oneline main..HEAD
```

See [REFERENCE.md](REFERENCE.md) for state-file shape, configuration env vars, reset procedure, and design rationale.
