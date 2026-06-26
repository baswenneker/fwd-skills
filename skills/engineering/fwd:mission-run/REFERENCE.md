# fwd:mission-run — reference

The canonical data contract for the `fwd:mission-*` family: the mission topology, the `state.json` schema, the handoff report shape, the validation contract, and the execution/resume semantics. `fwd:mission-plan` writes these artifacts; `fwd:mission-run` reads and advances them. This file is the **source of truth** — when in doubt, this wins.

Modelled on Factory.ai's "Missions" (orchestrator → workers → adversarial validators, validation contract written before any code, serial execution). Built on the same machinery as [`fwd:issue-fix`](../fwd:issue-fix/REFERENCE.md) — atomic JSON state, worktrees, circuit breaker, stale-lock recovery — but with one decisive difference (see *Why state is committed*).

## Topology: a mission is a branch

```
mission/<slug>                      ← the unit of work AND the unit of state
├── <product code commits>          ← one+ commit per feature (the deliverable)
└── .claude/missions/<slug>/        ← committed on the branch, travels with it
    ├── mission.md                  ← the PRD
    ├── validation-contract.md      ← what "done" means, written before code
    ├── state.json                  ← the ledger (schema below)
    └── handoffs/                   ← coder + validator prose reports

.trees/mission/<slug>/              ← worktree (gitignored); where execution happens
└── .env*                           ← copied in (gitignored; never committed)
```

`fwd:mission-plan` creates the branch + worktree and commits the initial artifacts (`status: planned`). `fwd:mission-run` reuses that worktree (or recreates it from the branch on a fresh clone) and drives execution, **committing the updated `state.json` + `handoffs/` after every feature and every milestone**.

### Why state is committed (and `fwd:issue-fix` ignores its state)

`fwd:issue-fix` gitignores `.claude/issue-loop/state.json` on purpose: it's a *stealth, overnight* tool whose whole point is that collaborators can't tell work was automated, and it runs in the main checkout over loose issues. Local-and-ignored fits.

A mission is the opposite: **your attributed work, on its own branch, that must be resumable from a fresh worktree / clone / teammate** ("coherent over days, not minutes"). Gitignored files don't exist on a branch — so `git worktree add .trees/mission/<slug> mission/<slug>` on another machine would have **no state**, making resume impossible and risking re-running already-committed features. Therefore the checkpoint *is* a commit: HEAD's `state.json` always matches HEAD's code, and resume anywhere is `git worktree add` → read HEAD state → continue.

The only gitignored thing is the `.env*` copy at the worktree root (under the already-ignored `.trees/`): a secret, never committed, re-copied on each fresh tree.

**Merge hygiene:** the branch carries `.claude/missions/<slug>/` scaffolding you likely don't want in `main`. Squash the mission branch on merge, or let `finalize.sh` drop `state.json` + `handoffs/` in a final commit (optionally relocating the PRD + contract to `docs/`).

## state.json schema

Location: `.claude/missions/<slug>/state.json` (inside the worktree, committed on the branch). Atomic writes only — every script writes `state.json.tmp.$$` then `mv`s over the original (a half-written ledger is worse than a stale one).

```jsonc
{
  "version": 1,
  "slug": "csv-clipboard-import",
  "title": "CSV clipboard import",
  "status": "in_progress",              // planned | in_progress | done | blocked
  "branch": "mission/csv-clipboard-import",
  "worktree": "/abs/path/.trees/mission/csv-clipboard-import",
  "base_branch": "main",                // what the mission branched off
  "created_at": "2026-06-02T10:00:00Z",
  "started_at": "2026-06-02T10:05:00Z", // first transition to in_progress
  "started_at_epoch": 1717322700,       // for stale-lock recovery
  "completed_at": null,

  // ── Layer A: gates (discovered at plan time, confirmed by the user) ──
  // The Scrutiny validator runs each and checks the exit code.
  "gates": [
    { "id": "G1", "name": "test",      "command": "npm test",         "expected_exit": 0 },
    { "id": "G2", "name": "typecheck", "command": "npx tsc --noEmit",  "expected_exit": 0 },
    { "id": "G3", "name": "lint",      "command": "npm run lint",      "expected_exit": 0 }
  ],

  // ── User-Testing boot config (captured at plan time; see "App boot") ──
  "user_testing": {
    "boot_command": "npm run dev",
    "ready_probe": { "type": "http", "url": "http://localhost:3000/health", "expect_status": 200, "timeout_sec": 60 },
    "smoke_commands": [
      "curl -fsS http://localhost:3000/health"
    ],
    "playwright_present": false,
    "teardown_command": null            // null → orchestrator kills the boot PID it captured
  },

  // ── Rules manifest (OPTIONAL, schema v3): freezes rule-file content at plan time.
  // An array of {path, sha256} entries — path is relative to repo root, sha256 is the
  // hash of the rule file at plan/materialization time. validate-artifacts.sh re-hashes
  // each file and fails if any entry is missing or has drifted. Plans without this field
  // (v1/v2) are fully valid everywhere — both runners, all scripts treat it as absent.
  "rules_manifest": [
    { "path": ".claude/rules/git.md", "sha256": "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855" }
  ],

  // ── Features: ORDERED. Resume = first feature whose status != done. ──
  "features": [
    {
      "id": "F1",
      "title": "Add clipboard read endpoint",
      "milestone": "M1",                // owning milestone id
      "vc_ids": ["VC-1", "VC-2"],       // contract assertions this feature targets
      "status": "done",                 // pending | in_progress | done | blocked
      "attempts": 1,                    // hard cap 3
      "commit_sha": "abc1234",          // THE checkpoint — resume reads this
      "started_at": "2026-06-02T10:05:10Z",
      "completed_at": "2026-06-02T10:18:00Z",
      "error": null,
      // rule_paths (OPTIONAL, schema v3): rule-file paths that apply to this feature,
      // computed at plan time from the feature's file-by-file table × rule paths: globs.
      // The coder subagent receives these paths and reports per-rule application in
      // its handoff (see rules_applied below). Plans without this field remain valid.
      "rule_paths": [".claude/rules/git.md"],
      "handoff": {                      // structured summary; prose in handoffs/F1.md
        "implemented": ["POST /api/import route", "clipboard parser util"],
        "left_undone": ["multi-file upload — out of scope for this feature"],
        "commands": [ { "command": "npm test tests/import.test.ts", "exit_code": 0 } ],
        "issues_discovered": ["fixture CSV had a BOM; stripped it"],
        "procedures_followed": ["risky-scan clean; conventional commit feat(import):"],
        // rules_applied (OPTIONAL, schema v3): one entry per rule in rule_paths,
        // reporting how the coder honored it. record-feature.sh stores the handoff
        // JSON integrally (no field whitelist), so this field travels into state.json
        // without any script change.
        "rules_applied": [
          { "rule": ".claude/rules/git.md", "how": "used conventional commit prefix feat(import): per rule §3" }
        ],
        "report_path": ".claude/missions/csv-clipboard-import/handoffs/F1.md"
      }
    }
  ],

  // ── Milestones: validation checkpoints over groups of features ──
  "milestones": [
    {
      "id": "M1",
      "title": "Clipboard import end-to-end",
      "feature_ids": ["F1", "F2"],
      "validation_status": "pending",   // pending | gates_passed | failed | passed
      "validated_at": null,
      "gate_results": [                 // Layer A outcome at this boundary
        { "id": "G1", "command": "npm test", "exit_code": 0, "passed": true }
      ],
      "vc_results": [                   // Layer B per-assertion verdicts
        { "id": "VC-1", "owner": "scrutiny-review", "passed": true,  "evidence": "route returns 201; parser handles BOM", "report_path": ".claude/missions/csv-clipboard-import/handoffs/M1-review.md" },
        { "id": "VC-3", "owner": "user-testing",    "passed": null,  "evidence": "not run — gates failed", "report_path": null }
      ],
      // walkthrough_path (OPTIONAL, schema v3): path to the human-readable milestone
      // walkthrough written by the runner after validation passes. Written in the user's
      // language; see "Milestone walkthrough template" below. Plans without this field
      // remain valid — the runner sets it after writing the walkthrough file.
      "walkthrough_path": ".claude/missions/csv-clipboard-import/handoffs/M1-walkthrough.md"
    }
  ],

  "circuit_breaker": { "consecutive_failures": 0 },   // 3 → preflight refuses

  "decisions": [                                       // autonomous choices logged, never prompted
    { "timestamp": "2026-06-02T10:12:00Z", "feature": "F1", "situation": "two CSV libs equally valid", "action": "used stdlib (no new dep — conservative)" }
  ]
}
```

### Field notes

- **`features[]` is ordered**, not keyed (unlike issue-fix's `issues{}`): features have a deterministic sequence and inherit each other via git. Resume = the first feature with `status != "done"`. The runner always executes features in array order.
- **`commit_sha` is the checkpoint.** Resume re-derives position from `status` + `commit_sha`; committed work is never replayed. If a feature is `in_progress` but its commit already exists on the branch (crash between commit and record), adopt it — mark `done`, don't re-spawn.
- **`vc_results[].passed` is tri-state:** `true` / `false` / `null`. `null` = not-run or skipped (e.g. user-testing skipped because gates failed). A re-run never mistakes a skip for a pass.
- **`gates` vs `gate_results`:** `gates` is the definition (from planning); `milestones[].gate_results` is the per-boundary outcome. Same split for `user_testing` (definition) vs `vc_results` (outcome).
- **`circuit_breaker` + `decisions[]`** are byte-compatible with issue-fix, so `log-decision.sh` is a near-verbatim crib.
- **Schema v3 fields are optional and additive.** Plans without `rules_manifest`, `features[].rule_paths`, `milestones[].walkthrough_path`, or `handoff.rules_applied` (older plans) remain valid everywhere — the runner and all scripts. No renames, no removals; nothing breaks on absent fields.
  - **`rules_manifest`** (top-level `[{path, sha256}]`): freezes rule-file content at plan/materialization time. `validate-artifacts.sh` re-hashes each entry and fails if a file is missing or has drifted. Absent or null → no check (v1/v2 behavior unchanged).
  - **`features[].rule_paths`** (array of paths): rule files that apply to this feature, computed at plan time from the feature's file-by-file scope × rule `paths:` globs. Passed to the coder subagent as its rule context.
  - **`milestones[].walkthrough_path`** (string path): where the runner writes the post-validation milestone walkthrough markdown (see *Milestone walkthrough template* below). Set by the runner after validation passes; absent in the initial plan.
  - **`handoff.rules_applied`** (`[{rule, how}]`): see the handoff table below.

## The handoff report

Every coder subagent returns a structured handoff (recorded into `features[].handoff`, prose into `handoffs/F<n>.md`). The five core fields are non-negotiable — they're how the mission stays coherent across fresh contexts:

| Field | Type | Meaning |
|---|---|---|
| `implemented` | string[] | what this feature actually delivered |
| `left_undone` | string[] | anything deferred or out of scope (so the next worker/validator knows) |
| `commands` | {command, exit_code}[] | commands the coder ran + their exit codes (self-check evidence) |
| `issues_discovered` | string[] | surprises, gotchas, latent bugs found along the way |
| `procedures_followed` | string[] | which conventions/gates were honored (risky-scan, conventional commit, …) |
| `rules_applied` | [{rule, how}][] | (OPTIONAL, schema v3) one entry per rule in `rule_paths`, describing how the coder honored that rule. `record-feature.sh` stores the handoff JSON integrally — no field whitelist — so this field travels into `state.json` without any script change. Absent when `rule_paths` is absent or empty. |

Validators return per-VC verdicts (recorded into `milestones[].vc_results`), prose into `handoffs/M<n>-review.md`.

## The validation contract (`validation-contract.md`)

Two layers, written **before any code**, independent of implementation:

- **Layer A — Gates (machine-checked).** The project's `test` / `typecheck` / `lint` / `build` commands, each expected to exit 0. Discovered at plan time (`discover-gates.sh`), confirmed by the user, stored in `state.gates`. The Scrutiny validator runs them and records exit codes.
- **Layer B — Assertions (judged).** Per-feature / per-milestone acceptance criteria as `given / when / then` statements, each with a stable ID (`VC-1`, `VC-2`, …) and an `owner` tag:
  - `scrutiny-review` — judged by the adversarial code reviewer against the diff.
  - `user-testing` — judged by the user-tester against the running app.

Validators judge against specific VC-IDs (not vibes); per-ID pass/fail flows into `vc_results` and the handoff reports.

## Execution & resume semantics

`fwd:mission-run` is a **main-session skill** (the orchestrator), because subagents can't spawn subagents. It is the sole spawner within a run — it spawns the coder per feature, and the validators at milestone boundaries. The bash/Claude/subagent split:

- **Bash** (deterministic, fast-exit): preflight, worktree setup + `.env` copy, pick-next-unit, gate execution + exit-code capture, all state writes, lesson append, decision log, finalize, status.
- **Claude (main session)**: which feature's criteria map to which VC-IDs; judging whether a handoff satisfies the feature; retry-vs-block decisions; distilling a lesson; deciding to skip user-testing when gates fail. **No code-writing in the main session.**
- **Subagents** (`fwd-skills:fwd-mission-{coder,reviewer,user-tester}`): coder writes + commits; validators judge.

### Checkpoint = commit

After each feature (and each milestone validation), the orchestrator commits the updated `state.json` + new `handoffs/*.md` on the mission branch. This is what makes resume work from any tree.

### Resume (idempotency)

On (re-)invoke — including a fresh `git worktree add` on another machine, or a `/loop` tick:

1. Read `state.json` at HEAD.
2. If `status` is `done` / `blocked` → nothing to do.
3. Resume point = first feature with `status != "done"`.
4. **Crash-window guard (`reconcile.sh`, run at loop start):** if real (non-metadata) code was committed since the last recorded feature SHA but never recorded — a tick that died between the coder's commit and `record-feature.sh` — adopt the first not-done feature as `done` at HEAD. Otherwise discard any uncommitted tracked leftovers (`git reset --hard`) so the next coder starts clean. A healthy resume is a no-op.
5. **No time-based stale lock.** Missions don't mark features `in_progress`; commit-based reconciliation is the resume signal (robust across fresh worktrees/clones, which a timer is not). Repeated failure is bounded by the per-feature attempt cap + the circuit breaker.

### Guardrails

| Guardrail | Value | Why |
|---|---|---|
| Attempts per feature | 3 | Beyond this a feature needs human input. Fail fast. |
| Circuit breaker | 3 consecutive blocked features/milestones | Systemic problem (broken env, bad base) — stop, don't chew the queue. |
| Crash reconciliation | loop start | `reconcile.sh` adopts orphan commits / discards leftovers (commit-based). |
| One active mission per repo | — | Serial by design; `state.json` is single-writer. |

## Subagent naming

Agents are shipped at the plugin root in `agents/` and auto-discovered. They are referenced via `subagent_type` as `fwd-skills:fwd-mission-coder`, `fwd-skills:fwd-mission-reviewer`, `fwd-skills:fwd-mission-user-tester` — `fwd-skills` is the plugin `name` in `.claude-plugin/plugin.json`. If the plugin is ever installed under a different name, these identifiers change; this is the single place that fact is recorded.

Plugin agents do **not** support `hooks`, `mcpServers`, or `permissionMode` (stripped on load) — the mission agents need none of these. They do support `tools` / `disallowedTools` (used to make the validators write-incapable), `model`, and `isolation`.

**Validators run in the mission worktree, not an isolated one.** The reviewer and user-tester are pointed at the mission worktree (the orchestrator passes the path) and read the diff / boot the app there. They deliberately do **not** use `isolation: worktree`: the orchestrator's main session is not checked out on the mission branch (it lives in the `.trees/` worktree), so an isolated worktree would branch off the wrong ref and contain none of the mission's committed code. Their write-incapability comes from the `tools` allowlist (no `Write`/`Edit`); their adversarial independence comes from being a fresh context briefed only on the diff/app + the contract — never the coder's reasoning.

## App boot (User-Testing)

The User-Testing validator needs to launch the app. The boot recipe is **captured during planning, never guessed at run time**: `fwd:mission-plan` discovers candidates (`package.json` `dev`/`start`/`serve`, `Procfile`, `docker-compose.yml`, a `Makefile` `run` target) and confirms the `boot_command` + `ready_probe` + `smoke_commands` with the user. If `boot_command` is absent at run time, user-testing VC-IDs are recorded `null` ("no boot command captured") — the agent never improvises (autonomous-conservative rule). The `ready_probe` (HTTP poll or log-line match) is essential, or the tester races the server.

## Configuration

| Env var | Default | Notes |
|---|---|---|
| `FWD_MISSION_BASE_BRANCH` | current branch (HEAD) | Branch the mission is based on |
| `FWD_MISSION_WORKTREE_DIR` | `<repo>/.trees` | Worktree root (`<dir>/mission/<slug>/`) |
| `FWD_MISSION_GATE_TIMEOUT` | `600` | Per-gate timeout (seconds) |
| `FWD_MISSION_MAX_ATTEMPTS` | `3` | Coder attempts per feature |

## Milestone walkthrough template

After a milestone passes validation, the runner writes a human-readable walkthrough at `milestones[].walkthrough_path` (e.g. `.claude/missions/<slug>/handoffs/M1-walkthrough.md`). This file is the hand-off document for the human who reviews the milestone. Write it in the user's language; the structure below uses Dutch labels as prescribed but the skeleton is language-neutral.

```markdown
# <Milestone title> — walkthrough

## In één oogopslag
<!-- Max 5 sentences. What does this milestone deliver? Why does it matter?
     What is the most important decision that was made? Any non-obvious risk? -->

## Leesvolgorde
<!-- Suggested reading order for someone reviewing the diff cold.
     List files / commits in the order that builds the clearest mental model. -->
1. `<path/to/key/file>` — <one sentence why to read this first>
2. ...

## Per feature

### <Feature id>: <Feature title>
**Wat / waarom** — <1-2 sentences: what was built and why this approach>

**Sleutelbestanden**
- `<path>` — <role>

**Zelf verifiëren**
```bash
<command to smoke-test or check this feature's output>
```

<!-- Repeat for each feature in this milestone -->

## Advisories
<!-- Non-blocking findings from the Scrutiny reviewer: simplicity observations,
     latent tech debt, things to watch. Not failures — those would have blocked
     the milestone. Leave empty if the reviewer had no advisories. -->
- <advisory> _(optional)_
```

The runner fills in each section from the coder handoffs and the validator reports. The "In één oogopslag" block must be written last (after reading all per-feature sections) so it can summarise the whole milestone honestly.

## Sources

- Factory.ai Missions — orchestrator / worker / validator, validation contract, serial execution ([docs.factory.ai/cli/features/missions](https://docs.factory.ai/cli/features/missions))
- [`fwd:issue-fix`](../fwd:issue-fix/REFERENCE.md) — state machinery, worktrees, circuit breaker, stale-lock recovery this builds on
- [CC#28041](https://github.com/anthropics/claude-code/issues/28041) — `.claude/` not copied to worktree (symlink workaround)
