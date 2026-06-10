# M1 — Scrutiny review (Plans emit dependency DAGs)

Reviewed the M1 product diff (d929d150..d56120cf), ignoring .claude/missions/ orchestration state. VC-1 and VC-2 are documentation assertions verified by reading plus exact-phrase grep against the canonical schema doc (fwd:mission-run/REFERENCE.md) and fwd:mission-plan/SKILL.md — every required clause is present verbatim. VC-3 was tested empirically with ~15 fixture state.json files in /tmp (using FWD_MISSION_WORKTREE_DIR to redirect the script): all three enumerated violations (cycle, nonexistent-ref, forward-milestone dep) exit non-zero with a naming message, self-dependency is caught as a self-cycle, a cycle hidden alongside a valid component still surfaces, and every backward-compatible shape passes (absent depends_on, empty arrays, empty-string entries, chains, diamonds, backward/same-milestone deps, out-of-order milestones[] with rank derived from array position). Failing cases create no commit (fail closed).

## Verdicts

- **VC-1: PASS** — REFERENCE.md documents depends_on as optional/additive (schema v2) in the inline schema comment and field-notes bullet: written by fwd:mission-plan, consumed by fwd:mission-run-parallel, ignored entirely by the serial runner, absent = chain semantics.
- **VC-2: PASS** — SKILL.md step 3 proposes depends_on per feature with "when unsure, add the edge"; step 7 handoff includes DAG width, critical-path length, and both run commands.
- **VC-3: PASS** — empirical fixture matrix: cycle/bad-ref/forward-milestone all exit non-zero naming the violation; backward-compatible shapes pass.

## Non-blocking nit

A malformed `depends_on` that is a JSON string instead of an array (e.g. `"depends_on":"F0"`) makes jq error and the script dies with bare exit 5 and no message (the `// []` guard only catches null, not a wrong type). Still fails closed/non-zero; outside VC-3's enumerated violations. A clearer "depends_on must be an array" message would be nice later.
