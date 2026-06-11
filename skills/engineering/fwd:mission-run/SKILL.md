---
name: fwd:mission-run
description: Execute a planned mission — the resident orchestrator of the fwd:mission-* layer (a Claude Code take on Factory.ai Missions). Reads the mission's state.json, drives features one at a time by spawning a fresh coder subagent each, runs adversarial validators (Scrutiny + User-Testing) at milestone boundaries, and records a checkpoint after every unit so the mission resumes from any worktree or clone. Runs autonomously — never prompts. Use when the user runs /fwd:mission-run <slug>, says "run/execute/resume mission <slug>", or wraps it in /loop for a long multi-day run. Pass `status` as a second argument for a read-only progress report.
argument-hint: "[<slug>] [status] — no args lists all missions"
allowed-tools: Read, Glob, Grep, Bash, Agent, Write
---

# fwd:mission-run

The resident orchestrator. One mission → serial features → adversarial validators at milestone boundaries → a committed checkpoint after every unit. Plan a mission first with `/fwd:mission-plan`; this skill executes it. Missions whose plan records a dependency DAG (`depends_on` fields) can alternatively be executed in parallel waves by `fwd:mission-run-parallel`; this serial runner ignores `depends_on` entirely and remains the safe default.

You (the main session) ARE the orchestrator. You spawn the coder and validator subagents — they cannot spawn each other, which is why the orchestrator is a main-session skill, not an agent. The canonical `state.json` schema, handoff shape, and resume semantics are in [REFERENCE.md](REFERENCE.md) — read it if anything below is ambiguous.

**Autonomous-mode principle.** This skill runs unattended, often under `/loop` for days. There is nobody at the keyboard.

- **Never call `AskUserQuestion` or `ExitPlanMode`.** Plan internally; act.
- **Never use interactive shell flags** (`-i`, `git rebase -i`, …).
- **When you would normally ask, decide and log.** Pick the conservative option and record it via `${CLAUDE_SKILL_DIR}/scripts/log-decision.sh`. Repeated ambiguity on a feature → block it (the human reviews blocked missions).
- **Never push, never open PRs, never mutate GitHub.** This skill commits locally on the mission branch; the human reviews and pushes.

**The bash / Claude / subagent split** (blurring this is where loops hang):

- **Bash scripts** — deterministic state, git, gates, exit codes. Run them; trust their exit codes.
- **You (main session)** — judgement: map criteria to VC-IDs, judge whether a handoff satisfies a feature, decide retry-vs-block, distil lessons. **You never write product code.**
- **Subagents** — `fwd-skills:fwd-mission-coder` writes + commits; `fwd-skills:fwd-mission-reviewer` and `fwd-skills:fwd-mission-user-tester` judge. Each is a fresh context; the validators have never seen the code being written.

## Quick start

```
/fwd:mission-run                   # list all missions in this repo + their status
/fwd:mission-run <slug>            # run to completion (resumes if interrupted)
/loop /fwd:mission-run <slug>      # long/overnight: one unit per fresh-context tick
/fwd:mission-run <slug> status     # read-only progress report for one mission
```

Don't remember the slug? Run `/fwd:mission-run` with no arguments — it lists every mission (the slug is also the `mission/<slug>` branch name). `fwd:mission-plan` prints the slug + the exact run command when it finishes planning.

## Flow

**No `<slug>` (or first argument `list`)** — discovery mode. Run `list-missions.sh`, report the table, and stop. Don't start anything; the user picks a slug to run. (If exactly one mission is `in_progress`, you may point them at it, but still don't auto-run.)

```
bash "${CLAUDE_SKILL_DIR}/scripts/list-missions.sh"
```

**`<slug> status`** — run `status.sh <slug>` and stop; it prints one mission's progress and writes nothing.

**`<slug>`** — run the scripts below in order. Stop the tick on the first blocking exit.

### 0. Preflight

```
bash "${CLAUDE_SKILL_DIR}/scripts/preflight.sh" <slug>
```

Checks `jq`, the repo, that the `mission/<slug>` branch exists, reads `state.json` from the branch, and validates: status ∈ {`planned`, `in_progress`}, circuit breaker < 3, and recovers a stale `in_progress` feature lock. First line `ok` → continue. Anything else → stop the tick cleanly and report the line:

| Output | Meaning |
|---|---|
| `ok` | proceed |
| `mission-done` / `mission-blocked` | nothing to do — report and stop |
| `no-mission` | no `mission/<slug>` branch — did you run `/fwd:mission-plan`? |
| `circuit-breaker-tripped` | 3 consecutive failures — stop; reset is manual (see REFERENCE) |
| `not-a-repo` / `missing-jq` | stop |

### 1. Set up the worktree

```
bash "${CLAUDE_SKILL_DIR}/scripts/setup-worktree.sh" <slug>
```

Reuses the worktree at `.trees/mission/<slug>/` (recreates it from the branch on a fresh clone), copies `.env*` into the worktree root (so the User-Testing validator can boot the app), and transitions `planned → in_progress` (committed). Prints the absolute worktree path — use it as `<WT>` below: pass it into the coder/validator subagent prompts so they work there. The scripts resolve the worktree themselves (they don't depend on your cwd), so **don't** `cd` into it — stay in the main checkout.

### 2. Per-unit loop

Once per invoke, before the loop, reconcile any crash from the previous tick:

```
bash "${CLAUDE_SKILL_DIR}/scripts/reconcile.sh" <slug>
```

`adopted <fid>` → a feature was committed last tick but never recorded; it's now `done`. `cleaned` → partial crash leftovers were discarded. `clean` → nothing to do.

Then repeat until `pick-next-unit.sh` reports no work.

**2.1 — Pick the next unit.**

```
bash "${CLAUDE_SKILL_DIR}/scripts/pick-next-unit.sh" <slug>
```

Outputs JSON `{"feature": {...}, "closes_milestone": "M2"|null}` for the first feature with `status != done`. Empty output → all features done → go to step 3. `closes_milestone` is the milestone id if completing this feature finishes its milestone (triggers validation in 2.5).

**2.2 — Brief yourself.** From the worktree's `.claude/missions/<slug>/`, read the feature's acceptance criteria: its `vc_ids` mapped to the assertions in `validation-contract.md`, plus the relevant `mission.md` context. The previous feature's code is already present (inherited via git).

**2.3 — Spawn the coder.** Use the Agent tool with `subagent_type: fwd-skills:fwd-mission-coder`. The prompt MUST pin:
- the worktree path `<WT>` (the coder works there, `cd`'d in),
- the ONE feature (id, title) and its acceptance criteria (the VC-IDs verbatim),
- the mission's **design budget** (copy the "Strategy & Design Budget" section verbatim from `mission.md`) — the coder must stay within it,
- the feature's `rule_paths` from `state.json` as a **mandatory reading list** — declare them binding ("these rules are binding; read each one before writing any code; report `rules_applied` for every rule in your handoff"). When `rule_paths` is absent or empty, omit this bullet entirely — backward compatible with v1/v2 plans.
- "implement only this feature; add/adjust tests; stage your files; run `risky-scan.sh`; commit with a conventional message; do NOT push; return the handoff as JSON".

The coder returns a structured handoff (the five fields — see REFERENCE).

**2.4 — Verify and record.** Write the coder's prose narrative to `<WT>/.claude/missions/<slug>/handoffs/<feature-id>.md`. Then:

```
echo '<handoff-json>' | bash "${CLAUDE_SKILL_DIR}/scripts/record-feature.sh" <slug> <feature-id> done
```

`record-feature.sh` verifies the worktree is clean and a new commit exists, records `commit_sha` + the handoff + `attempts`, resets the breaker, and commits the checkpoint on the branch. If the coder made no commit or didn't satisfy the feature — **including** when the feature's `rule_paths` is non-empty and the returned handoff lacks a non-empty `rules_applied` field (no verantwoording, no accepted handoff):
- `attempts < FWD_MISSION_MAX_ATTEMPTS` (default 3) → re-spawn the coder (2.3) with the failure context appended.
- attempts exhausted → `record-feature.sh <slug> <feature-id> blocked "<reason>"` (increments the breaker), then go to 2.7.

**2.5 — Milestone validation** (only if `closes_milestone` is set).

*Gates (Layer A):*

```
bash "${CLAUDE_SKILL_DIR}/scripts/run-gates.sh" <slug> <milestone-id>
```

Prints a JSON array of per-gate `{exit_code, passed}` and exits 0 iff all passed. Capture it as `<gate-results>`.

*Scrutiny (Layer B — `scrutiny-review` VC-IDs):* spawn `fwd-skills:fwd-mission-reviewer` (Agent tool). The prompt MUST pin the worktree path, the milestone's commit range (the feature SHAs from `state.json`), and the `scrutiny-review` assertions verbatim. It returns `{narrative, verdicts:[{id,passed,evidence}]}` — write its narrative to `handoffs/<milestone-id>-review.md`.

*User-Testing (Layer B — `user-testing` VC-IDs):* run only if gates passed AND scrutiny passed (else record these VC-IDs `null`, evidence "skipped: upstream failed"). Boot the app:

```
bash "${CLAUDE_SKILL_DIR}/scripts/boot-app.sh" <slug>
```

- `no-boot` (exit 2) → record user-testing VCs `null` ("no boot command captured").
- `boot-timeout` / `boot-crashed` (exit 1) → record `null` ("app did not boot").
- `ready url=<url>` (exit 0) → spawn `fwd-skills:fwd-mission-user-tester` (Agent), pinning the worktree, the URL, the `smoke_commands`, the `playwright_present` flag, and the `user-testing` assertions verbatim. It returns `{narrative, verdicts}` — write its narrative to `handoffs/<milestone-id>-usertest.md`.

Always tear down afterwards (whatever the boot outcome):

```
bash "${CLAUDE_SKILL_DIR}/scripts/teardown-app.sh" <slug>
```

*Decide `validation_status`:* any gate failed OR any scrutiny VC failed → `failed`; gates + scrutiny passed but user-testing couldn't run (no boot / boot failed) → `gates_passed`; everything that ran (gates + scrutiny + user-testing) passed → `passed`. **Advisories from the reviewer never influence `validation_status`** — they are non-blocking by definition (see CONTEXT.md "advisory").

*Record + commit:*

```
echo '{"gate_results":<gate-results>,"vc_results":[<reviewer verdicts + user-testing nulls, each {id,passed,evidence,report_path}>]}' \
  | bash "${CLAUDE_SKILL_DIR}/scripts/record-validation.sh" <slug> <milestone-id> <status>
```

*Write the milestone walkthrough* (regardless of `validation_status` — every milestone ends with a readable walkthrough): compile `handoffs/<milestone-id>-walkthrough.md` following the template in REFERENCE.md ("In één oogopslag"; reading order; per-feature what/why + key files + self-verify commands; advisories section from the reviewer's `advisories[]`). Then set `milestones[].walkthrough_path` in `state.json` with an atomic write:

```bash
TMPFILE="$(dirname "${STATE_JSON}")/state.json.tmp.$$"
jq --arg mid "<milestone-id>" \
   --arg wp  ".claude/missions/<slug>/handoffs/<milestone-id>-walkthrough.md" \
   '(.milestones[] | select(.id == $mid) | .walkthrough_path) = $wp' \
   "${STATE_JSON}" > "${TMPFILE}" && mv "${TMPFILE}" "${STATE_JSON}"
```

Commit the walkthrough alongside the validation checkpoint (one commit, or as its own `chore(mission):` commit immediately after — pick whichever keeps the diff cleanest).

*On `failed`:* give the milestone ONE bounded remediation pass — re-spawn the coder on the failing feature(s) with the verdicts as context (respect the attempt cap) — then re-validate. Still failing or cap hit → the milestone is blocked (`record-validation.sh` already incremented the breaker); log it and continue.

**2.6 — Learn.** After a milestone, if the handoffs' `issues_discovered` or any VC failure taught something reusable, distil ONE lesson and append it:

```
bash "${CLAUDE_SKILL_DIR}/scripts/append-lesson.sh" <type> <scope> "<context>" "<observation>" "<lesson>"
```

`type` ∈ `insight` (a gotcha worth remembering) | `deviation` (a gate/constraint forced a workaround) | `rule-gap` (a missing convention) | `correction`. `scope` is the area (the mission slug or a subsystem). One line per field. **Skip it if nothing reusable came up — don't log noise.** Lessons land in the main repo's `.claude/lessons/LESSONS.md`, not the mission branch.

**2.7 — Checkpoint.** State is already committed by `record-feature.sh` / `record-validation.sh`. If the breaker reached 3, stop the tick (report; `/loop` will idle). Otherwise loop to 2.1.

### 3. Finalize

When no features remain (*finalize added by M6*):

```
bash "${CLAUDE_SKILL_DIR}/scripts/finalize.sh" <slug>
```

Marks the mission `done` (all milestones passed) or `blocked`, removes the copied `.env` from the worktree, and keeps the worktree for review.

Report the outcome to the user. The final report MUST include a **rule-kandidaten** section: distil candidate new rules from the accumulated `issues_discovered` fields across all feature handoffs and from any lessons appended during the mission. Present each candidate as a one-sentence proposal — what pattern, and why it belongs in `.claude/rules/`. **The runner never mutates `.claude/rules/` itself.** The human reviews these kandidaten and decides whether to add them as rules.

## Hard limits — do not override

- Attempts per feature: `FWD_MISSION_MAX_ATTEMPTS` (default 3).
- Circuit breaker: 3 consecutive blocked features/milestones → preflight refuses.
- Crash recovery: `reconcile.sh` (loop start) adopts an orphan commit or discards partial leftovers — commit-based, not time-based.
- One active mission per repo (serial; single-writer state).

## Boundaries

- **Never push, never open PRs, never mutate GitHub.** Commit locally on the mission branch only.
- **You never write product code** in the main session — that's the coder's job. You orchestrate.
- **Validators never see the coder's reasoning** — they get a fresh context, the diff/app, and the contract. Don't paste implementation details into validator prompts.
- **Never re-run a `done` feature.** Resume reads `commit_sha`; committed work is final.
- **Schrijfstijl** — walkthroughs and orchestration narratives follow the "Schrijfstijl missions" block in [CONTEXT.md](../../../CONTEXT.md).

## Reviewing / resuming

```
/fwd:mission-run <slug> status                    # progress
cd .trees/mission/<slug> && rtk git log --oneline # the commits
# resume on another machine:
rtk git fetch && rtk git worktree add .trees/mission/<slug> mission/<slug>
/fwd:mission-run <slug>
```

See [REFERENCE.md](REFERENCE.md) for the schema, resume/idempotency rules, agent naming, and configuration.
