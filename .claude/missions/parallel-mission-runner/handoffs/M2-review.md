# M2 — Scrutiny review (Wave engine, harness-proven)

M2 is high quality and well-tested. The reviewer read the full diff (d56120cf..4f73662b), the SKILL.md, all three new scripts (pick-wave.sh, setup-slot.sh, integrate-feature.sh), the smoke harness, and the unchanged serial record-feature.sh. The serial fwd:mission-run/ directory is byte-for-byte untouched in the range (empty diff), so "unchanged record-feature.sh" and "no duplicated script bodies" hold. tests/smoke-waves.sh ran hermetically from /tmp (43/43 PASS, no network/agents). Additional reviewer-built fixtures empirically exercised the paths the harness does not cover: two-discard→blocked (exit 6, attempts+1, breaker+1, tree clean, sibling work intact), empty-range (exit 5, no state change), chain-DAG (warns but proceeds), .env gitignore safety (refuses when not ignored; copied-but-uncommittable when ignored), dirty-slot reuse (tracked dirt reset, untracked preserved, branch force-moved), and plan/array-order scheduling (reverse-alpha array proves array order; serial_only first → solo; serial_only mid-list halts the wave before it). All shared scripts are invoked exclusively via ${CLAUDE_SKILL_DIR}/../fwd:mission-run/scripts/. G3 is registered in state.gates running smoke-waves.sh.

## Verdicts

- **VC-4: PASS** — registered in plugin.json + README; autonomous-mode rules (never prompt, never push) and explicit risk statement present; shared behaviour exclusively via ../fwd:mission-run/scripts/; no duplicated bodies.
- **VC-5: PASS** — cap 2 over 3 ready → exactly 2 in plan (array) order; serial_only first → solo wave; v1 → exit 2 pointing at /fwd:mission-run; chain DAG → warns, proceeds.
- **VC-6: PASS** — slot created/reused at wave base on mission/<slug>--f<id>; dirty reuse resets tracked, preserves untracked; .env* copied; refuses if .env not gitignored; risky-scan regime unchanged.
- **VC-7: PASS** — clean integrate cherry-picks in plan order, unchanged record-feature.sh records integrated SHA; conflict → exit 3, clean tree, serial_only pin, decision logged, no attempt; gate-fail → exit 4, X reset out, pinned; two discards → exit 6 blocked, breaker incremented.
- **VC-8: PASS** — hermetic (BASH_SOURCE-relative, mktemp -d, trap cleanup, no network/agents); 43/43 from /tmp; covers cap, order, conflict→pin, culprit isolation, v1 refusal; registered as G3.

## Non-blocking nit

SKILL.md step 3.3 and setup-slot.sh's header comment document the arg order as `<slug> <feature-id> <slot-n>` while the script (and harness) use `<slug> <slot-n> <feature-id>`. Functional behavior correct; usage example misleading. → Scheduled into F9 (touches that SKILL.md).
