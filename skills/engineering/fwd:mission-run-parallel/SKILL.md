---
name: fwd:mission-run-parallel
description: Execute a planned mission in parallel waves — the opt-in, faster, riskier sibling of fwd:mission-run. Reads a v2 mission (one that has depends_on fields) and executes independent features concurrently: each wave spawns up to FWD_MISSION_MAX_PARALLEL (default 3) coder subagents, each in its own slot worktree, then integrates their work sequentially onto the mission branch through the unchanged record-feature machinery. Uses the same state.json checkpoint format, same adversarial validators, and same milestone boundaries as fwd:mission-run — switching runners between ticks is safe. Use when the user runs /fwd:mission-run-parallel <slug>, says "run mission <slug> in parallel" or "wave-based parallel execution", and the mission plan contains a dependency DAG. Refuses v1 missions (no depends_on anywhere) with a clear pointer to /fwd:mission-run. Typing this command is explicit risk acceptance: parallel coders are blind to each other, missed plan dependencies cost conflict round-trips, and tokens do not drop with wall-clock.
argument-hint: "[<slug>] — run the mission in parallel waves"
allowed-tools: Read, Glob, Grep, Bash, Agent
---

# fwd:mission-run-parallel

The wave orchestrator. Same mission, same validators, same checkpoint format as `fwd:mission-run` — but independent features within a milestone execute as a parallel wave of coder subagents rather than one at a time. Plan a mission first with `/fwd:mission-plan` (v2, with `depends_on` fields); this skill executes it in waves. The serial runner (`/fwd:mission-run`) remains the safe default and is completely unchanged.

You (the main session) ARE the orchestrator. You spawn coder subagents across slots and validator subagents at milestone boundaries — they cannot spawn each other. Read [REFERENCE.md](../fwd:mission-run/REFERENCE.md) for the canonical state.json schema, handoff shape, and resume semantics; this skill operates on the same contract.

**Explicit risk statement.** Typing `/fwd:mission-run-parallel` is your risk acceptance. Understand the trade-offs before proceeding:

- Parallel coders are **blind to each other** — same-wave features must not need each other's output. A missed dependency in the plan costs a full conflict round-trip: discard the slot work, pin the feature `serial_only`, and re-run it as a solo wave on the merged base.
- **Tokens do not drop with wall-clock.** Each coder consumes context tokens regardless of wall-clock speed; discarded work is wasted tokens. Burst-parallel API + machine load applies.
- **Amdahl's law.** Chain DAGs (F1→F2→F3→…) gain nothing. Gain is bounded by the longest feature per wave. A warning is emitted, but execution continues.
- **Fixed-port test collisions** are possible across slots (noted in coder briefings; the coder is expected to handle or avoid).
- When everything goes wrong, this runner degrades to today's serial behaviour — never worse.

If you are uncertain about the plan's DAG quality, use `/fwd:mission-run`.

**Autonomous-mode rules.** This skill runs unattended, often under `/loop`. There is nobody at the keyboard.

- **Never call `AskUserQuestion` or `ExitPlanMode`.** Plan internally; act.
- **Never use interactive shell flags** (`-i`, `git rebase -i`, …).
- **When you would normally ask, decide and log.** Pick the conservative option and record it via `${CLAUDE_SKILL_DIR}/../fwd:mission-run/scripts/log-decision.sh`. Repeated ambiguity on a feature → block it.
- **Never push, never open PRs, never mutate GitHub.** Commit locally on the mission branch only.

**The bash / Claude / subagent split:**

- **Bash scripts** — deterministic state, git, slot setup, cherry-picks, gates, exit codes. Run them; trust their exit codes.
- **You (main session)** — judgement: schedule waves, map criteria to VC-IDs, judge whether a handoff satisfies a feature, decide retry-vs-block, distil lessons. **You never write product code.**
- **Subagents** — `fwd-skills:fwd-mission-coder` writes + commits in each slot; `fwd-skills:fwd-mission-reviewer` and `fwd-skills:fwd-mission-user-tester` judge at milestone boundaries. Each is a fresh context; validators have never seen the code being written.

**Scripts that ship with this skill** (`${CLAUDE_SKILL_DIR}/scripts/<name>.sh` — land in F5/F6/F8):

- `pick-wave.sh` — ready-set scheduler (deps ⊆ done, current milestone, cap, serial_only solo, v1 refusal, chain warning)
- `setup-slot.sh` — slot worktree provision/reset + `.env` copy
- `integrate-feature.sh` — cherry-pick + wave-gate + conflict→pin policy
- `reconcile-waves.sh` — slot cleanup, then delegates to serial `reconcile.sh`
- `tests/smoke-waves.sh` — hermetic fixture-repo + stub-coder harness (gate G3)

Everything else is shared via `${CLAUDE_SKILL_DIR}/../fwd:mission-run/scripts/` (see Script references section).

## Quick start

```
/fwd:mission-run-parallel <slug>       # run to completion in waves (resumes if interrupted)
/loop /fwd:mission-run-parallel <slug> # long/overnight: one wave per fresh-context tick
```

Note: v1 missions (no `depends_on` anywhere in state.json) are **refused** — use `/fwd:mission-run` for those. Plan a new mission with `/fwd:mission-plan` to get a v2 plan with a dependency DAG.

## Flow

**`<slug>`** — run the scripts below in order. Stop the tick on the first blocking exit.

### 0. Preflight

```bash
bash "${CLAUDE_SKILL_DIR}/../fwd:mission-run/scripts/preflight.sh" <slug>
```

Same preflight as the serial runner: checks `jq`, the repo, that `mission/<slug>` branch exists, reads `state.json`, validates status ∈ {`planned`, `in_progress`}, circuit breaker < 3, recovers stale locks.

After preflight passes, **check for v1 mission**. Inspect `state.json`: if no feature has a `depends_on` field (or all are absent), this is a v1 plan:

```
REFUSE: This mission has no dependency DAG (v1 plan). fwd:mission-run-parallel
requires depends_on fields to schedule parallel waves.
Run /fwd:mission-run <slug> to execute serially, or re-plan with
/fwd:mission-plan to add a DAG.
```

**Stop the tick.** Do not modify state.

**Check for chain DAG** (every non-empty `depends_on` points linearly: F1←F2←F3←…). Emit a warning and log a decision, but proceed — degenerate case is serial-equivalent performance, not incorrect behaviour.

### 1. Set up the worktree

```bash
bash "${CLAUDE_SKILL_DIR}/../fwd:mission-run/scripts/setup-worktree.sh" <slug>
```

Reuses or recreates the worktree at `.trees/mission/<slug>/`, copies `.env*`, and transitions `planned → in_progress`. Prints the absolute worktree path — use it as `<WT>` below. **Do not `cd` into it;** stay in the main checkout.

### 2. Reconcile waves

```bash
bash "${CLAUDE_SKILL_DIR}/scripts/reconcile-waves.sh" <slug>
```

Cleans up leftover slot worktrees (`.trees/mission/<slug>--slot-*`) and temp branches (`mission/<slug>--f*`) from a previous crash or interrupted wave, then delegates to the serial `reconcile.sh` for the standard crash-window guard (adopt orphan commit or discard partial leftovers). Outputs same signals as serial reconcile: `adopted <fid>` / `cleaned` / `clean`.

### 3. Per-wave loop

Repeat until `pick-wave.sh` reports no work.

**3.1 — Pick the next wave.**

```bash
bash "${CLAUDE_SKILL_DIR}/scripts/pick-wave.sh" <slug>
```

Outputs JSON `{"wave": [{"id":"F2","title":"...","slot":1}, ...], "closes_milestone":"M1"|null}` for the next batch of ready features: all features in the current milestone whose `depends_on` are all `done`, capped at `FWD_MISSION_MAX_PARALLEL` (default 3). `serial_only`-pinned features always run as solo waves (wave size 1). Empty output → all features done → go to step 4.

`closes_milestone` is set if completing this wave finishes its milestone.

**3.2 — Brief yourself on each wave feature.** From the worktree's `.claude/missions/<slug>/`, read each feature's acceptance criteria: its `vc_ids` mapped to `validation-contract.md`, plus the relevant `mission.md` context.

**3.3 — Provision slots.**

For each feature in the wave:

```bash
bash "${CLAUDE_SKILL_DIR}/scripts/setup-slot.sh" <slug> <feature-id> <slot-n>
```

Creates or resets `.trees/mission/<slug>--slot-<n>/` as a worktree on temp branch `mission/<slug>--f<id>` branched off the current mission-branch HEAD (the wave base). Copies `.env*` into the slot root. Reuses existing slot worktrees (reset + branch switch) so per-slot setup cost (e.g. `node_modules`) is paid once per slot across the whole mission.

**3.4 — Spawn coders in parallel.** Send ONE Agent message with multiple tool uses — one `fwd-skills:fwd-mission-coder` invocation per slot feature, all at the same time. Each coder prompt MUST pin:

- the slot worktree path `<WT-slot>` (the coder works there, `cd`'d in),
- the ONE feature (id, title) and its acceptance criteria (VC-IDs verbatim),
- "implement only this feature; add/adjust tests; stage your files; run `risky-scan.sh`; commit with a conventional message; do NOT push; return the handoff as JSON",
- "NOTE: other coders are implementing sibling features concurrently in separate worktrees — you cannot see or depend on their work; implement your feature self-contained on the provided slot branch."

Each coder returns a structured handoff (see REFERENCE).

**3.5 — Integrate features (sequential, in plan order).** For each feature in the wave, in the order they appear in `state.json["features"]` (plan order, not wave order):

```bash
echo '<handoff-json>' | bash "${CLAUDE_SKILL_DIR}/scripts/integrate-feature.sh" <slug> <feature-id>
```

`integrate-feature.sh` cherry-picks the slot branch commits onto the mission branch in the existing mission worktree `<WT>`, then (with wave-gates on) runs Layer-A gates:

```bash
bash "${CLAUDE_SKILL_DIR}/../fwd:mission-run/scripts/run-gates.sh" <slug>
```

Exit codes from `integrate-feature.sh`:

| Exit | Meaning |
|---|---|
| `0` | Integration + gates clean — feature recorded done |
| `3` | Cherry-pick conflict — feature pinned `serial_only`, no attempt consumed (see Conflict policy) |
| `4` | Gates failed after clean integration — feature pinned `serial_only`, attempt consumed |
| `5` | No slot commits (empty range) — orchestrator should treat as coder failure |
| `6` | Second discard — feature recorded `blocked` |

`integrate-feature.sh` pipes the handoff JSON through to `record-feature.sh` on exit 0 and exit 6 internally — the orchestrator passes handoff JSON on stdin. On exit 0, write the coder's prose narrative to `<WT>/.claude/missions/<slug>/handoffs/<feature-id>.md` from the handoff.

`record-feature.sh` is **unchanged** — it verifies a new commit exists, records `commit_sha` + handoff, resets the breaker, and commits the checkpoint. The recorded `commit_sha` is the cherry-picked SHA on the mission branch (not the slot SHA).

On exit 3 or 4 (conflict / gate-fail): see Conflict policy below.

**Wave-gates toggle:** `FWD_MISSION_WAVE_GATES=0` disables the per-feature gate run inside `integrate-feature.sh`. Gates still run at milestone boundaries. Disable for slow suites only.

**3.6 — After the wave.** If `closes_milestone` was set AND all features in the wave were integrated cleanly: proceed to Milestone validation (step 3.7). Otherwise, loop to 3.1.

**3.7 — Milestone validation** (only when `closes_milestone` is set and all features clean).

Identical to the serial runner — all scripts are unchanged:

*Gates (Layer A):*

```bash
bash "${CLAUDE_SKILL_DIR}/../fwd:mission-run/scripts/run-gates.sh" <slug> <milestone-id>
```

*Scrutiny (Layer B):* spawn `fwd-skills:fwd-mission-reviewer` (Agent). Pin: worktree path, milestone commit range, `scrutiny-review` assertions verbatim. Returns `{narrative, verdicts}` — write prose to `handoffs/<milestone-id>-review.md`.

*User-Testing (Layer B):* run only if gates + scrutiny passed. Boot:

```bash
bash "${CLAUDE_SKILL_DIR}/../fwd:mission-run/scripts/boot-app.sh" <slug>
```

- `no-boot` (exit 2) → record user-testing VCs `null`.
- `boot-timeout` / `boot-crashed` (exit 1) → record `null`.
- `ready url=<url>` (exit 0) → spawn `fwd-skills:fwd-mission-user-tester` (Agent), pin worktree, URL, `smoke_commands`, `playwright_present`, `user-testing` assertions. Returns `{narrative, verdicts}` — write to `handoffs/<milestone-id>-usertest.md`.

Always tear down:

```bash
bash "${CLAUDE_SKILL_DIR}/../fwd:mission-run/scripts/teardown-app.sh" <slug>
```

Decide `validation_status` and record:

```bash
echo '{"gate_results":<gate-results>,"vc_results":[...]}' \
  | bash "${CLAUDE_SKILL_DIR}/../fwd:mission-run/scripts/record-validation.sh" <slug> <milestone-id> <status>
```

*On `failed`:* one bounded remediation pass — re-spawn the coder on the failing feature(s) with the verdicts as context (serial: one at a time, respect attempt cap) — re-validate. Still failing or cap hit → milestone blocked, breaker incremented, continue.

**3.8 — Learn.** Same as serial runner: if handoffs' `issues_discovered` or VC failures taught something reusable, distil ONE lesson:

```bash
bash "${CLAUDE_SKILL_DIR}/../fwd:mission-run/scripts/append-lesson.sh" <type> <scope> "<context>" "<observation>" "<lesson>"
```

Skip if nothing reusable. Do not log noise.

**3.9 — Checkpoint.** State is committed by `record-feature.sh` / `record-validation.sh`. If the breaker reached 3, stop the tick. Otherwise loop to 3.1.

### 4. Finalize

```bash
bash "${CLAUDE_SKILL_DIR}/../fwd:mission-run/scripts/finalize.sh" <slug>
```

Tears down all remaining slot worktrees and temp branches, then runs the serial finalize: marks the mission `done` or `blocked`, removes copied `.env` files (main worktree and any lingering slots), keeps the worktree for review. Report the outcome and stop.

## Conflict policy (standing decisions)

These are permanent decisions — do not override them.

**Cherry-pick conflict → discard + pin:**

1. `integrate-feature.sh` aborts the cherry-pick (`git cherry-pick --abort`).
2. The slot worktree is left intact for inspection but the slot branch is not merged.
3. The feature's `serial_only` flag is set to `true` in state.json.
4. Log the decision via `${CLAUDE_SKILL_DIR}/../fwd:mission-run/scripts/log-decision.sh`.
5. **No attempt is consumed.** This is a planner error (a missing `depends_on` edge), not a coder error.
6. **Two discards of the same feature** (conflict on two separate solo-wave attempts) → `blocked`. A feature is solo-wave when `serial_only: true` — it re-runs with the merged base as context; if it conflicts again, the plan is incorrect and human review is needed.
7. The feature re-runs as a **solo wave** (`serial_only: true`) on the merged base in the next tick.

**Wave-gate failure → identify culprit + pin:**

1. `integrate-feature.sh` reports `gate-fail <fid>` — the feature that, when integrated, first caused gates to fail.
2. Reset the culprit's commits out of the mission branch (`git reset --hard` to pre-integration HEAD).
3. Pin `serial_only: true` on the culprit feature. Record the other already-integrated wave features as done (they passed gates when integrated individually).
4. Log the decision.
5. An attempt IS consumed for the culprit (coder submitted broken code — coder error).

**`serial_only`-pinned features always run as solo waves.** `pick-wave.sh` always sizes them at wave-size 1.

## Interop / runner-switching

Both runners read and write the same `state.json` schema and the same checkpoint format. Switching runner between ticks (e.g., a wave tick with `/fwd:mission-run-parallel` followed by a serial tick with `/fwd:mission-run`, or vice versa) is **safe by design**. Details:

**The serial runner ignores slot worktrees/branches entirely.** `fwd:mission-run` never reads `.trees/mission/<slug>--slot-*` paths or `mission/<slug>--f*` refs. It resumes from `state.json` and the main mission worktree (`.trees/mission/<slug>/`) exactly as if the parallel runner had never run.

**Leftover slots are cleaned by this skill only.** `reconcile-waves.sh` (step 2) and `finalize.sh` (step 4) are the sole owners of slot cleanup. The serial `reconcile.sh` and serial `finalize.sh` do not remove slot worktrees or temp branches — they are deliberately ignorant of them. If you switch from parallel to serial execution mid-mission, leftover slot worktrees remain until the next parallel tick's `reconcile-waves.sh` or the final `finalize.sh` cleans them. They are inert and harmless to the serial runner.

**Circuit breaker and per-feature attempts live in shared `state.json`.** Both runners increment and respect the same `features[].attempts` counter and the same `circuit_breaker.consecutive_failures`. A feature blocked (attempts exhausted) by the parallel runner cannot be re-run by the serial runner without manual reset (same rule: committed work is final). A circuit-breaker trip set by the serial runner is seen by the parallel runner on the next tick (preflight refuses).

**`serial_only`-pinned features.** If the parallel runner pins a feature `serial_only: true` after a conflict, the serial runner still ignores that flag (it executes in array order regardless). The flag is consumed only by `pick-wave.sh` to force solo-wave execution in the parallel runner. Mixed runs are therefore safe: serial picks up the feature in order; parallel picks it up as a solo wave.

**`depends_on` is invisible to the serial runner.** The serial runner executes features in `state.json["features"]` array order, period. `depends_on` fields are present in the JSON but never read by serial scripts. No migration needed between v1 and v2 plans.

## Hard limits — do not override

- Attempts per feature: `FWD_MISSION_MAX_ATTEMPTS` (default 3). Conflict discards do NOT consume an attempt.
- Circuit breaker: 3 consecutive blocked features/milestones → preflight refuses.
- Wave atomicity: a crash mid-wave loses only un-integrated slot work. Integrated + recorded commits count; `reconcile-waves.sh` on resume cleans the rest.
- One active mission per repo — even with parallel slots, a single orchestrator session owns state writes.
- **Single-writer state**: ONLY the orchestrator (main session) writes `state.json`. Parallel coders write code on their slot branches only — this is what keeps parallelism safe. Coders never touch `state.json`.

## Script references

All shared scripts come **exclusively** via `${CLAUDE_SKILL_DIR}/../fwd:mission-run/scripts/` — no script bodies are duplicated. This is the first cross-skill script dependency in this repo; renaming the `fwd:mission-run` folder breaks this skill.

| Script | Location |
|---|---|
| `preflight.sh` | `${CLAUDE_SKILL_DIR}/../fwd:mission-run/scripts/preflight.sh` |
| `setup-worktree.sh` | `${CLAUDE_SKILL_DIR}/../fwd:mission-run/scripts/setup-worktree.sh` |
| `reconcile.sh` | `${CLAUDE_SKILL_DIR}/../fwd:mission-run/scripts/reconcile.sh` |
| `pick-next-unit.sh` | `${CLAUDE_SKILL_DIR}/../fwd:mission-run/scripts/pick-next-unit.sh` |
| `record-feature.sh` | `${CLAUDE_SKILL_DIR}/../fwd:mission-run/scripts/record-feature.sh` |
| `run-gates.sh` | `${CLAUDE_SKILL_DIR}/../fwd:mission-run/scripts/run-gates.sh` |
| `boot-app.sh` | `${CLAUDE_SKILL_DIR}/../fwd:mission-run/scripts/boot-app.sh` |
| `teardown-app.sh` | `${CLAUDE_SKILL_DIR}/../fwd:mission-run/scripts/teardown-app.sh` |
| `record-validation.sh` | `${CLAUDE_SKILL_DIR}/../fwd:mission-run/scripts/record-validation.sh` |
| `log-decision.sh` | `${CLAUDE_SKILL_DIR}/../fwd:mission-run/scripts/log-decision.sh` |
| `append-lesson.sh` | `${CLAUDE_SKILL_DIR}/../fwd:mission-run/scripts/append-lesson.sh` |
| `finalize.sh` | `${CLAUDE_SKILL_DIR}/../fwd:mission-run/scripts/finalize.sh` |
| `status.sh` | `${CLAUDE_SKILL_DIR}/../fwd:mission-run/scripts/status.sh` |
| `list-missions.sh` | `${CLAUDE_SKILL_DIR}/../fwd:mission-run/scripts/list-missions.sh` |
| `pick-wave.sh` | `${CLAUDE_SKILL_DIR}/scripts/pick-wave.sh` (this skill, F5) |
| `setup-slot.sh` | `${CLAUDE_SKILL_DIR}/scripts/setup-slot.sh` (this skill, F5) |
| `integrate-feature.sh` | `${CLAUDE_SKILL_DIR}/scripts/integrate-feature.sh` (this skill, F6) |
| `reconcile-waves.sh` | `${CLAUDE_SKILL_DIR}/scripts/reconcile-waves.sh` (this skill, F8) |
| `tests/smoke-waves.sh` | `${CLAUDE_SKILL_DIR}/tests/smoke-waves.sh` (this skill, F9) |

## Boundaries

- **Never push, never open PRs, never mutate GitHub.** Commit locally on the mission branch only.
- **You never write product code** in the main session — that's the coders' job. You orchestrate.
- **Validators never see the coders' reasoning** — fresh context, the diff/app, and the contract.
- **Never re-run a `done` feature.** Resume reads `commit_sha`; committed work is final.
- **Slot branches are ephemeral.** They are local-only, created off the wave base, and cleaned by reconcile-waves/finalize. They are never pushed.

## Configuration

| Env var | Default | Notes |
|---|---|---|
| `FWD_MISSION_MAX_PARALLEL` | `3` | Maximum concurrent coder slots per wave |
| `FWD_MISSION_WAVE_GATES` | `1` | Set to `0` to disable per-feature gate run after each cherry-pick (gates still run at milestone boundaries) |
| `FWD_MISSION_MAX_ATTEMPTS` | `3` | Coder attempts per feature (inherited from serial runner; conflict discards do not count) |
| `FWD_MISSION_BASE_BRANCH` | current branch (HEAD) | Branch the mission is based on |
| `FWD_MISSION_WORKTREE_DIR` | `<repo>/.trees` | Worktree root |
| `FWD_MISSION_GATE_TIMEOUT` | `600` | Per-gate timeout (seconds) |

## Reviewing / resuming

```bash
/fwd:mission-run-parallel <slug>          # resume mid-wave; reconcile-waves cleans leftovers
/fwd:mission-run <slug>                   # switch to serial runner — safe at any tick boundary
/fwd:mission-run <slug> status            # read-only progress report
cd .trees/mission/<slug> && rtk git log --oneline  # the commits
```

See [REFERENCE.md](../fwd:mission-run/REFERENCE.md) for the full schema, resume semantics, and configuration.
