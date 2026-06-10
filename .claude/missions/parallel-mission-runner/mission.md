# Mission: Parallel Mission Runner

## Problem Statement

`fwd:mission-run` executes features strictly serially: one coder subagent at a time, each feature waiting on the previous commit. Trace analysis of 15 run sessions (129 coder spawns) shows:

- Coders account for **14.4 h of ~18.5 h active wall-clock (~78%)** — reviewers 2.9 h, user-testers 1.1 h, gates median **4 s**.
- Ideal intra-milestone parallelisation would save **6.1 h (42%)**; measured per mission: 29–62%.
- The serial order is mostly *unnecessary*: the plan records no dependencies, so the runner must assume F(n+1) builds on F(n) even when they don't touch each other.

## Goals and Success Metrics

**Primary goal**: run features that don't depend on each other in parallel, with exactly the same quality guarantees as serial execution — as an explicit, opt-in choice.

**Success metrics**:
- Wall-clock of the coder phase on DAG-rich missions: −30–40%.
- Behaviour of the existing serial runner: **unchanged — zero code changes** (docs only).
- Quality machinery (validation contract, adversarial validators, checkpoint=commit, single-writer state): unchanged.
- Worst case (chain DAG / everything conflicts): degrades to today's serial behaviour, never worse.

## Acceptance Criteria

- `fwd:mission-plan` writes an optional `depends_on` per feature (the DAG) and validates it (no cycles, refs exist, no forward-milestone deps); plans without it remain valid.
- The serial runner ignores `depends_on` entirely; v1 missions keep working everywhere.
- A new skill `fwd:mission-run-parallel` executes ready features (deps ⊆ done, same milestone) in waves of ≤ `FWD_MISSION_MAX_PARALLEL` (default 3), each coder in its own slot worktree.
- Integration is sequential cherry-picks in plan order through the **unchanged** `record-feature.sh`; the recorded `commit_sha` is the integrated SHA on the mission branch.
- A cherry-pick conflict discards the slot work, pins the feature `serial_only`, logs a decision, and consumes **no** attempt; two discards of the same feature → `blocked`.
- With wave-gates enabled (default), Layer-A gates run after each integrated feature; the first failure identifies the culprit, which is reset out and pinned `serial_only`.
- A crash mid-wave loses only un-integrated slot work (wave atomicity); resume cleans slots and continues.
- Both runners read/write the same checkpoint format — switching runner between ticks is safe and documented.
- `fwd:mission-run-parallel` refuses v1 missions (no DAG) with a clear pointer; warns on chain DAGs.

## Implementation Strategy

### Three skills, one state

```
fwd:mission-plan          writes the DAG (depends_on per feature) into state.json (schema v2)
        │                 + handoff prints: DAG width, critical path, both run options
        ▼
mission/<slug> branch     state.json = single source of truth (schema: fwd:mission-run/REFERENCE.md)
        │
        ├── /fwd:mission-run            ← UNCHANGED serial runner (safe default)
        └── /fwd:mission-run-parallel   ← NEW: wave scheduler (faster, explicit risk choice)
```

The plan documents *how* parallel execution is possible; which runner to use is a run-time decision per mission — even per tick, because both runners share the checkpoint format.

### Wave engine (inside fwd:mission-run-parallel)

- **Waves**: ready set = features in the current milestone whose `depends_on` are all `done`, capped at `FWD_MISSION_MAX_PARALLEL` (default 3). One ready feature → behaves like today. `serial_only`-pinned features always run as solo waves.
- **Slot worktrees**: `.trees/mission/<slug>--slot-1..N`, each on a temp branch `mission/<slug>--f<id>` off the wave base. Slots persist across waves (reset + branch switch), so per-slot setup cost (e.g. `node_modules`) is paid once. `.env*` copied in like the main worktree.
- **Integration**: after the wave, cherry-pick each feature's slot commits onto the mission branch in plan order, in the existing mission worktree, then call the **unchanged** `record-feature.sh`. All invariants hold: PREV-SHA→HEAD code-diff check, checkpoint=commit, state HEAD == code HEAD, single-writer state (only the orchestrator writes state; coders only write code on slot branches).
- **Three safety nets** for the three new risks:
  1. *Textual conflict* → cherry-pick conflicts → abort, discard slot work, pin `serial_only`, log decision, no attempt consumed (planner error, not coder error). Feature reruns solo on the merged base next round.
  2. *Semantic conflict* (merges clean, breaks behaviour) → **wave-gates**: run Layer-A gates after each integrated feature (measured median 4 s — near-free). First failing feature is precisely identified → reset out + pin. Tighter fault isolation than serial has today. Disable via `FWD_MISSION_WAVE_GATES=0` for slow suites.
  3. *Crash mid-wave* → wave atomicity: only integrated+recorded commits count. `reconcile-waves.sh` removes leftover slot branches/worktrees of pending features on resume; the existing adopt mechanism covers the cherry-pick-vs-record crash window because integration runs in plan order.
- Milestone validation is untouched: gates + scrutiny + (if bootable) user-testing on the integrated state; remediation stays serial.

### Script reuse, not duplication

`fwd:mission-run-parallel` ships only what is new (`pick-wave.sh`, `setup-slot.sh`, `integrate-feature.sh`, `reconcile-waves.sh`, tests). Everything unchanged (preflight, record-feature, run-gates, boot/teardown, record-validation, status, log-decision, …) is referenced via `${CLAUDE_SKILL_DIR}/../fwd:mission-run/scripts/` — the repo's first cross-skill script dependency, to be documented as a convention in CLAUDE.md.

### Trade-offs and consequences (accepted at approval)

**Pros**: zero regression risk on the proven serial path (29 sessions of trace evidence stay valid); risk is an explicit, visible choice (typing `/fwd:mission-run-parallel` *is* the risk acceptance); the parallel engine can evolve aggressively without destabilising serial; same mission format allows A/B comparison.

**Cons / consequences**: two orchestrator SKILL.mds to maintain (~70% overlapping flow text — scripts are shared, instructions are not); first cross-skill script coupling (renaming the serial skill folder breaks the parallel one); checkpoint compatibility becomes a contract tested against two consumers; tokens don't drop with wall-clock (discards are wasted work; burst-parallel load on API and machine); Amdahl — gain bounded by the longest feature per wave (chain DAG gains nothing); planner burden — DAG quality determines the gain, a missed dependency costs a conflict round-trip; parallel coders are blind to each other (same-wave features must not need each other's code; style divergence is caught by the reviewer); cap+1 worktrees of disk; fixed-port test collisions possible across slots (known limitation, noted in coder briefing); noisier observability (interleaved logs, temp refs); `/loop` ticks become coarser (one wave per tick, atomic).

**Standing decisions**: cap default **3**; wave-gates default **on**; conflict consumes **no** attempt, 2 discards → blocked; v1 missions → **refuse** (no silent degradation); scripts shared via sibling path (not copied).

## File-by-file

| File | Change | Reason |
|------|--------|--------|
| `skills/engineering/fwd:mission-run-parallel/SKILL.md` | new | wave orchestration flow, explicit risk profile, autonomous-mode rules |
| `skills/engineering/fwd:mission-run-parallel/scripts/pick-wave.sh` | new | ready-set scheduler (deps ⊆ done, current milestone, cap, serial_only solo, v1 refusal, chain warning) |
| `skills/engineering/fwd:mission-run-parallel/scripts/setup-slot.sh` | new | slot worktree provision/reset + `.env` copy |
| `skills/engineering/fwd:mission-run-parallel/scripts/integrate-feature.sh` | new | cherry-pick + wave-gate + conflict→pin policy |
| `skills/engineering/fwd:mission-run-parallel/scripts/reconcile-waves.sh` | new | slot cleanup, then delegate to serial `reconcile.sh` |
| `skills/engineering/fwd:mission-run-parallel/tests/smoke-waves.sh` | new | hermetic fixture-repo + stub-coder harness (gate G3) |
| `.claude-plugin/plugin.json` | modified | register the new skill |
| `README.md` | modified | skills-table row |
| `skills/engineering/fwd:mission-plan/SKILL.md` | modified | step 3 proposes the DAG (conservative default: unsure → edge); handoff prints DAG stats + both run commands |
| `skills/engineering/fwd:mission-plan/REFERENCE.md` | modified | template gains depends_on guidance |
| `skills/engineering/fwd:mission-plan/scripts/validate-artifacts.sh` | modified | DAG validation (refs exist, no cycles, no forward-milestone deps) |
| `skills/engineering/fwd:mission-run/REFERENCE.md` | modified | **docs only**: `depends_on` in canonical schema (additive; ignored by serial runner) |
| `skills/engineering/fwd:mission-run/SKILL.md` | modified | one referring sentence to the parallel variant |
| `agents/fwd-mission-coder.md` | modified | one sentence: spawned by both orchestrators; sibling awareness arrives via the spawn prompt |
| `CLAUDE.md` | modified | cross-skill script convention + third mission skill |

Deliberately untouched: all `fwd:mission-run` scripts, both validator agents.

## Testing & Verification

- **`smoke-waves.sh`** (gate G3): builds a tmp fixture repo, fabricates a v2 mission (3 independent + 1 dependent feature), stub coder = bash function committing on the slot branch; asserts cap respected, integration order, conflict→`serial_only` pin with clean tree, wave-gate culprit isolation, crash simulation→reconcile, v1 refusal. Hermetic: no network, no agents.
- **G1**: `bash -n` over all mission scripts. **G2**: `jq` validation of `plugin.json`.
- Milestone boundaries: adversarial scrutiny review against the VC-IDs in the validation contract (no bootable app → no user-testing VCs).
- Optional post-mission shake-down: `/fwd:skill-eval` on `fwd:mission-run-parallel`.

## Security

No new surface: nothing pushes, nothing touches GitHub. `.env*` is now also copied into slot worktrees — same regime as today (under gitignored `.trees/`, risky-scan per commit, finalize scrubs). Temp branches stay local and are cleaned by reconcile/finalize.
