# Validation Contract: parallel-mission-runner

## Layer A — Gates (machine-checked, exit 0)

| ID | Name | Command |
|----|------|---------|
| G1 | syntax | `find skills/engineering -path '*fwd:mission*' -name '*.sh' -exec bash -n {} +` |
| G2 | plugin-json | `jq -e '.skills \| type=="array"' .claude-plugin/plugin.json` |
| G3 | smoke-waves | `[ ! -f "skills/engineering/fwd:mission-run-parallel/tests/smoke-waves.sh" ] \|\| bash "skills/engineering/fwd:mission-run-parallel/tests/smoke-waves.sh"` |

G3 is guarded: it passes trivially until the harness lands (F7), then runs the full suite at every later boundary.

## Layer B — Assertions (judged)

All assertions are owned by `scrutiny-review` — this is a skills repo with no bootable app.

### M1 — Plans emit dependency DAGs

- **VC-1** (scrutiny-review): *Given* the canonical schema doc (`skills/engineering/fwd:mission-run/REFERENCE.md`), *when* read, *then* `depends_on` is documented as an optional, additive per-feature field — written by `fwd:mission-plan`, consumed by `fwd:mission-run-parallel`, **ignored by the serial runner** — including the rule "absent `depends_on` = chain semantics (each feature implicitly depends on its predecessor)". *(features: F1)*
- **VC-2** (scrutiny-review): *Given* `fwd:mission-plan` SKILL.md step 3, *when* a planner follows it, *then* it instructs proposing `depends_on` per feature with the conservative default (*unsure → add the edge*), and the handoff template includes DAG width, critical-path length, and **both** run commands (serial and parallel). *(features: F2)*
- **VC-3** (scrutiny-review): *Given* a `state.json` containing a dependency cycle, a dep on a nonexistent feature id, or a dep crossing forward into a later milestone, *when* `validate-artifacts.sh` runs, *then* it exits non-zero naming the violation; *given* features without `depends_on`, *then* it passes (backward compatible). *(features: F3)*

### M2 — Wave engine, harness-proven

- **VC-4** (scrutiny-review): *Given* the new skill, *then* it is registered in `.claude-plugin/plugin.json` and the README skills table, its SKILL.md contains the autonomous-mode rules (never prompt, never push) and an explicit risk statement, and it references shared behaviour **exclusively** via `${CLAUDE_SKILL_DIR}/../fwd:mission-run/scripts/` — no duplicated script bodies. *(features: F4)*
- **VC-5** (scrutiny-review): *Given* a v2 state with 3 ready independent features and cap 2, *when* `pick-wave.sh` runs, *then* it emits a wave of exactly 2 in plan order; *given* a `serial_only` pin on the first ready feature, *then* a solo wave; *given* a v1 state (no `depends_on` anywhere), *then* it refuses with the documented message pointing at `/fwd:mission-run`; *given* a chain-shaped DAG, *then* it warns but proceeds. *(features: F5)*
- **VC-6** (scrutiny-review): *Given* `setup-slot.sh`, *then* it creates or reuses `.trees/mission/<slug>--slot-<n>` at the wave base on branch `mission/<slug>--f<id>`, resets a dirty reused slot clean, copies `.env*` in, and `.env` can never be committed (risky-scan regime unchanged). *(features: F5)*
- **VC-7** (scrutiny-review): *Given* a slot branch with commits, *when* `integrate-feature.sh` runs, *then* commits are cherry-picked onto the mission branch in plan order and the **unchanged** `record-feature.sh` records the integrated SHA; *given* a cherry-pick conflict, *then* the abort leaves the mission worktree clean, the feature is pinned `serial_only`, a decision is logged, and **no** attempt is consumed; *given* wave-gates enabled and a gate failing after integrating feature X, *then* X's commits are reset out (back to pre-X) and X is pinned `serial_only`; *given* two discards of the same feature, *then* it is recorded `blocked`. *(features: F6)*
- **VC-8** (scrutiny-review): *Given* `smoke-waves.sh`, *then* it runs hermetically in a tmp dir (no network, no agents), covers cap enforcement, integration order, conflict→pin, wave-gate culprit isolation, and v1 refusal — and it is registered as gate G3 in this mission's `state.gates`. *(features: F7)*

### M3 — Crash-safe + interop documented

- **VC-9** (scrutiny-review): *Given* leftover slot worktrees/branches of pending features after a simulated crash, *when* `reconcile-waves.sh` runs, *then* they are removed, integrated work is untouched, and the serial `reconcile.sh` is invoked afterwards (delegation, not reimplementation); the harness covers this path. *(features: F8)*
- **VC-10** (scrutiny-review): *Given* a finished mission, *when* the finalize flow in the run-parallel SKILL.md is followed, *then* the serial `finalize.sh` runs unchanged and the slots are torn down, including `.env` scrub. *(features: F9)*
- **VC-11** (scrutiny-review): *Given* the repo docs, *then* CLAUDE.md documents the cross-skill script-reference convention and the third mission skill, `agents/fwd-mission-coder.md` mentions both orchestrators, and no remaining doc claims that only `fwd:mission-run` spawns the coder. *(features: F10)*
- **VC-12** (scrutiny-review): *Given* the run-parallel SKILL.md, *then* runner-switching semantics are documented: the serial runner safely ignores slot refs; leftovers are cleaned by the parallel reconcile/finalize; circuit breaker and attempts live in shared state so both runners respect each other's counters. *(features: F4, F8, F9)*

## App boot (user-testing)

None — skills repo, nothing bootable. `boot_command: null`; every assertion is `scrutiny-review`.
