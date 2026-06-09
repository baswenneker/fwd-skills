---
name: fwd:mission-plan
description: Plan a multi-agent "mission" — scope a software goal through conversation, write a PRD plus a validation contract (what "done" means, before any code), decompose into features and milestones, then create the mission branch and persist the plan on it. The interactive half of the fwd:mission-* orchestration layer (modelled on Factory.ai Missions); execution is handled afterwards by /fwd:mission-run. Use when the user wants to plan a larger feature as an orchestrated mission, says "plan a mission", "start a mission", "scope this as a mission", or invokes /fwd:mission-plan.
argument-hint: <the software goal, or empty to scope interactively>
allowed-tools: Read, Glob, Grep, Bash, WebFetch, WebSearch, AskUserQuestion, Write
---

# fwd:mission-plan

Turn a software goal into an executable **mission**: a PRD, a validation contract, and an ordered feature/milestone plan — committed on a `mission/<slug>` branch and ready for `/fwd:mission-run`.

This is the **interactive** half of the `fwd:mission-*` layer. Factory's insight: *the planning phase matters most, and the validation contract defines what "done" means before any code is written.* So this skill is deliberately conversational — get the contract right here and execution becomes mechanical.

**Interactive-mode principle.** Unlike `/fwd:mission-run` (which runs unattended and never prompts), this skill **should** ask. `AskUserQuestion` is allowed and encouraged for discrete choices. Iterate the PRD and contract in plain text until the user approves.

**No product code.** This skill writes only mission artifacts (`mission.md`, `validation-contract.md`, `state.json`). It never implements features — that's the coder's job under `/fwd:mission-run`.

See [REFERENCE.md](REFERENCE.md) for the PRD + contract templates and slug rules, and [`fwd:mission-run`'s reference](../fwd:mission-run/REFERENCE.md) for the canonical `state.json` schema.

## Quick start

```
/fwd:mission-plan add CSV import with clipboard paste
# → scope → PRD → contract → milestones → approve → commits mission/<slug>
# then:
/fwd:mission-run <slug>
```

## Flow

### 1. Scope the goal (gather context)

Read enough to plan, not to implement. Restate the goal in your own words. Then:

- 2–4 targeted `Glob`/`Grep` passes on terms from the goal; read 2–4 key files to learn existing patterns (naming, structure, conventions).
- Skim `CLAUDE.md`, `CONTEXT.md`, any `docs/adr/`, and rule files under `.claude/rules/` if present — every assertion in the contract must respect these.
- For libraries/frameworks, pull current docs (Context7 MCP if available, else `WebSearch`).

If the goal is ambiguous, ask now (`AskUserQuestion`) — a sharp contract depends on a sharp goal.

### 2. Draft the PRD (`mission.md`)

Present a confident PRD draft in plain text (not `AskUserQuestion`), built from real Step 1 findings, using the Factory shape (full template in REFERENCE.md):

1. **Problem Statement** — who hurts, and the measurable cost.
2. **Goals & Success Metrics** — the primary goal + measurable targets.
3. **Acceptance Criteria** — observable, testable; these seed the Layer-B assertions.
4. **Implementation Strategy** — approach + the existing patterns to follow.
5. **File-by-file breakdown** — concrete paths (only real paths from Step 1).
6. **Testing & Verification** — how correctness is confirmed.
7. **Security considerations** — secrets, input validation, authz.

Stop and let the user correct it in plain text. Re-render on changes. Don't bluff — if Step 1 was too thin, say what context you're missing and wait.

### 3. Decompose into features → milestones

Once the PRD holds, propose an **ordered** feature list grouped into **milestones** (validation checkpoints):

- Each feature is one coherent, committable unit; features are serial and inherit each other via git.
- Each feature maps to the acceptance criteria (VC-IDs) it must satisfy.
- A milestone is a meaningful checkpoint where the validators run. Smaller milestones = more frequent validation = a more stable foundation for long missions.

Present as a numbered tree (`M1 → F1, F2; M2 → F3 …`); let the user reorder/split in plain text.

### 4. Write the validation contract (`validation-contract.md`)

**Layer A — gates.** Run:

```
bash "${CLAUDE_SKILL_DIR}/scripts/discover-gates.sh"
```

It prints a JSON array of resolvable gate commands (test/typecheck/lint/build — only ones that actually resolve). Show them to the user and confirm (`AskUserQuestion` or plain text); drop or add as needed. These become `state.gates`.

**Layer B — assertions.** Write per-feature/per-milestone acceptance criteria as `given / when / then`, each with a stable ID (`VC-1`, `VC-2`, …) and an `owner` tag:
- `scrutiny-review` — judged against the diff by the adversarial reviewer.
- `user-testing` — judged against the running app by the user-tester.

**App-boot config (for user-testing).** Discover boot candidates (`package.json` `dev`/`start`/`serve`, `Procfile`, `docker-compose.yml`, `Makefile` run target). Confirm with the user: the `boot_command`, a `ready_probe` (HTTP poll or log-line match — essential), and 1–3 `smoke_commands`. If the app can't be booted (e.g. a library), set no boot command and tag everything `scrutiny-review`.

### 5. Approval gate

Present the complete plan in one view: PRD summary, the milestone/feature tree, the gates, the Layer-B assertions, and the boot config. Ask for explicit approval (`AskUserQuestion`: *Approve & create the mission* / *Revise* / *Cancel*). Only proceed on approval.

### 6. Materialise the mission

On approval, derive a `slug` (kebab-case from the goal, ≤50 chars; see REFERENCE.md), then:

```
bash "${CLAUDE_SKILL_DIR}/scripts/init-mission.sh" <slug>
```

This creates branch `mission/<slug>` off the base branch, a worktree at `.trees/mission/<slug>/`, scaffolds `.claude/missions/<slug>/` (with `handoffs/`) and a skeleton `state.json` (`status: planned`), and prints the **worktree path** on stdout.

Then, into `<worktree>/.claude/missions/<slug>/`, write the three artifacts with the `Write` tool:

- `mission.md` — the PRD from Step 2.
- `validation-contract.md` — Layer A + Layer B from Step 4.
- `state.json` — fill the skeleton: `gates[]`, `user_testing{}`, ordered `features[]` (each with `vc_ids`, `status: "pending"`), `milestones[]` (with `feature_ids`, `validation_status: "pending"`). Match the schema in `../fwd:mission-run/REFERENCE.md` exactly.

Finally validate and commit the plan:

```
bash "${CLAUDE_SKILL_DIR}/scripts/validate-artifacts.sh" <slug>
```

It asserts the three artifacts exist and are well-formed (valid `state.json` with required fields; ≥1 `VC-` in the contract), then commits `.claude/missions/<slug>/` on the mission branch as `docs(mission): scope <slug>`. On a non-zero exit, fix what it reports and re-run — do not hand off a malformed mission.

### 7. Hand off

Report: the slug, the branch, the worktree path, the milestone/feature count, and:

> Mission `<slug>` is planned and committed. Run it with `/fwd:mission-run <slug>` (or `/loop /fwd:mission-run <slug>` for a long, resumable run).

## Boundaries

- **Plan only** — never implement features or write product code here.
- **Real paths only** in the file-by-file breakdown; no invented files.
- **The contract is written before code** — that's the entire point. Don't defer assertions to "we'll see during implementation".
- Hand off via the slug; don't start execution yourself.
