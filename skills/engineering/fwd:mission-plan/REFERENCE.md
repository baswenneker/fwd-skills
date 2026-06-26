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

## In één oogopslag

<Maximaal 5 zinnen die de kern samenvatten. Zie het "Schrijfstijl missions"-blok in CONTEXT.md voor de precieze regels. De lezer weet na dit blok wat er gebouwd wordt en waarom.>

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

## Strategy & Design Budget

<Aanpak en de bestaande patronen/bestanden die gevolgd worden (uit stap 1). Beschrijf de seriële volgorde.>

**Toegestane nieuwe dependencies (limitatief — niets buiten deze lijst is toegestaan):**
- <dependency of "geen">

**Toegestane nieuwe abstracties (limitatief — niets buiten deze lijst is toegestaan):**
- <abstractie of "geen">

**Geldende regelbestanden:**
- <pad naar regelbestand, bijv. `.claude/rules/conventions.md`> — <scope: repo-breed of glob>
- <of "Geen `.claude/rules/` aanwezig — bewust gestart zonder regels.">

Het overschrijden van dit design budget laat een review zakken.

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
Each assertion: given / when / then, a stable ID, an owner, the milestone it gates, and
**a one-line plain-language summary** (the `· *cursief*` pattern):

### M1 — <milestone title>
- **VC-1** (scrutiny-review): *Given* a CSV on the clipboard, *when* `POST /api/import` is called, *then* it returns 201 and persists the rows. · *The import endpoint stores the data.* *(features: F1)*
- **VC-2** (scrutiny-review): *Given* a malformed CSV, *when* imported, *then* the endpoint returns 400 with a field-level error — no partial write. · *Bad input is rejected cleanly.* *(features: F1)*
- **VC-3** (user-testing): *Given* the app is running, *when* a user pastes CSV into the import box and clicks Import, *then* the rows appear in the table within 2s. · *The user sees the result fast.* *(features: F2)*
- **VC-4** (scrutiny-review): *Given* the committed code of this milestone, *when* the reviewer reads the diff, *then* no comment, docstring, or commit message contains a mission-internal code (feature/milestone/VC ID, or a history reference like "pre-F4") — every comment is standalone-readable. · *Comments explain what/why, no mission jargon.* *(features: F1, F2)*

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
- **Comment hygiene is a standing VC.** Every milestone carries one `scrutiny-review` assertion (the VC-4 shape above), regardless of whether `.claude/rules/` exist, enforcing that committed comments/docstrings/commit messages contain no mission-internal codes (feature/milestone/VC IDs, history references) and read standalone. The reviewer judges it like any compliance-VC. The norm is the "Codecommentaar" block in [CONTEXT.md](../../../CONTEXT.md).

## Worked example (minimal)

Goal: *"add a /health endpoint"* → slug `health-endpoint`.

- **PRD**: problem = no liveness probe for the deploy platform; metric = probe returns 200 < 100ms.
- **Gates**: G1 `npm test`, G2 `npx tsc --noEmit`.
- **Assertions**: VC-1 (scrutiny-review) route returns 200 + `{status:"ok"}`; VC-2 (user-testing) `GET /health` on the booted app returns 200.
- **Features**: F1 "add route + test" → M1. **Milestone**: M1 "health live" → [F1], gates [G1,G2], VCs [VC-1, VC-2].
- **Boot**: `npm run dev`, ready-probe `GET /health → 200`.

That's a complete, runnable mission.
