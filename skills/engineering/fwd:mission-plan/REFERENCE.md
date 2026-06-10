# fwd:mission-plan — reference

Templates and rules for the artifacts `fwd:mission-plan` produces. The canonical `state.json` schema lives in [`../fwd:mission-run/REFERENCE.md`](../fwd:mission-run/REFERENCE.md) — this file covers the two markdown artifacts and the slug.

## Slug rules

The slug names the branch (`mission/<slug>`), the worktree (`.trees/mission/<slug>/`), and the artifact dir (`.claude/missions/<slug>/`). Derive it from the goal:

- kebab-case, `[a-z0-9]+(-[a-z0-9]+)*`, ≤ 50 chars.
- Drop articles and the leading verb (add/update/fix/…); keep the distinctive nouns.
- Example: *"Add CSV import with clipboard paste"* → `csv-clipboard-import`.

`init-mission.sh` validates the slug and refuses if a `mission/<slug>` branch already exists (pick a more specific slug, or resume the existing mission with `/fwd:mission-run <slug>`).

## `mission.md` — the PRD

Factory's PRD shape. Keep it concrete and measurable; this is the contract's narrative half.

```markdown
# Mission: <Title>

## Problem Statement
<Who is hurting, and the measurable cost. Numbers if you have them.>
- <symptom / metric>
- <symptom / metric>

## Goals and Success Metrics
**Primary goal**: <one sentence>.

**Success metrics**:
- <measurable target #1>
- <measurable target #2>

## Acceptance Criteria
<Observable, testable outcomes. These seed the Layer-B assertions (VC-IDs).>
- <criterion>
- <criterion>

## Implementation Strategy
<Approach + the existing patterns/files to follow (from Step 1). Note serial ordering.>

## File-by-file
| File | Change | Reason |
|------|--------|--------|
| `path/to/x` | new | <why> |
| `path/to/y` | modified | <what changes> |

## Testing & Verification
<How correctness is confirmed: which gates, which flows, which fixtures.>

## Security
<Secrets, input validation, authz, anything that could leak or break trust.>
```

## `validation-contract.md` — what "done" means

Two layers. Written before any code, independent of how it's implemented.

```markdown
# Validation Contract: <slug>

## Layer A — Gates (machine-checked, exit 0)
| ID | Name | Command |
|----|------|---------|
| G1 | test | `npm test` |
| G2 | typecheck | `npx tsc --noEmit` |
| G3 | lint | `npm run lint` |

## Layer B — Assertions (judged)
Each assertion: given / when / then, a stable ID, an owner, and the milestone it gates.

### M1 — <milestone title>
- **VC-1** (scrutiny-review): *Given* a CSV on the clipboard, *when* `POST /api/import` is called, *then* it returns 201 and persists the rows. *(features: F1)*
- **VC-2** (scrutiny-review): *Given* a malformed CSV, *when* imported, *then* the endpoint returns 400 with a field-level error — no partial write. *(features: F1)*
- **VC-3** (user-testing): *Given* the app is running, *when* a user pastes CSV into the import box and clicks Import, *then* the rows appear in the table within 2s. *(features: F2)*

## App boot (user-testing)
- boot: `npm run dev`
- ready: HTTP GET `http://localhost:3000/health` → 200 (timeout 60s)
- smoke: `curl -fsS http://localhost:3000/health`
```

### Writing good assertions

- **Independent of implementation.** "Returns 201 and persists rows", not "calls `saveRows()`".
- **Falsifiable.** A validator must be able to render a clear PASS/FAIL with evidence.
- **Owned.** `scrutiny-review` for anything checkable from the diff/tests; `user-testing` for anything that needs the running app. If there's no bootable app, everything is `scrutiny-review`.
- **Mapped.** Every VC-ID lists the feature(s) that satisfy it; every feature's `vc_ids` in `state.json` lists the VC-IDs it targets. The two must agree.

## Feature `depends_on` — the dependency DAG

Each feature in `state.json` may carry an optional `depends_on` array of feature ids (schema v2, defined in [`../fwd:mission-run/REFERENCE.md`](../fwd:mission-run/REFERENCE.md)). Write this during Step 3 of planning.

**Rules:**
- Only reference ids that already exist (same or earlier milestone). No forward-milestone refs, no cycles.
- Absent or empty (`[]`) means chain semantics: the feature implicitly depends on its predecessor in the array.
- The serial runner (`fwd:mission-run`) ignores `depends_on` entirely — it always executes in array order. A plan with no `depends_on` fields runs correctly on both runners.
- The parallel runner (`fwd:mission-run-parallel`) uses these edges to group independent features into concurrent waves.

**Conservative default: unsure → add the edge.** A false dependency only costs parallelism; a missing dependency causes a conflict round-trip at run time.

**Small DAG example** (three features, M1; F2 and F3 both depend on F1, so they can run in parallel in wave 2):

```jsonc
{ "id": "F1", "title": "scaffold DB schema",      "depends_on": []          },
{ "id": "F2", "title": "add read endpoint",        "depends_on": ["F1"]      },
{ "id": "F3", "title": "add write endpoint",       "depends_on": ["F1"]      },
{ "id": "F4", "title": "integration tests",        "depends_on": ["F2","F3"] }
```

Wave breakdown: W1 = [F1], W2 = [F2, F3], W3 = [F4]. DAG width = 2; critical-path length = 3.

## Worked example (minimal)

Goal: *"add a /health endpoint"* → slug `health-endpoint`.

- **PRD**: problem = no liveness probe for the deploy platform; metric = probe returns 200 < 100ms.
- **Gates**: G1 `npm test`, G2 `npx tsc --noEmit`.
- **Assertions**: VC-1 (scrutiny-review) route returns 200 + `{status:"ok"}`; VC-2 (user-testing) `GET /health` on the booted app returns 200.
- **Features**: F1 "add route + test" → M1, `depends_on: []`. **Milestone**: M1 "health live" → [F1], gates [G1,G2], VCs [VC-1, VC-2].
- **Boot**: `npm run dev`, ready-probe `GET /health → 200`.

That's a complete, runnable mission.
