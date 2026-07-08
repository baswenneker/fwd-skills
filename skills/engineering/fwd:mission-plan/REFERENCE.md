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

## Zo ziet klaar eruit
<Het concrete eindbeeld — verplicht. Kies de vorm die bij het werk past:
- UI-werk: een ASCII-mockup of een pad naar een referentiescreenshot. Bij smaakgevoelig
  werk: bied 2–3 stijlvarianten aan, laat de gebruiker kiezen en leg de gekozen variant
  hier vast.
- CLI/API-werk: een letterlijk voorbeeld van input → output, of een korte voorbeeldsessie
  (commando's + exacte output).
- Refactor/library: een before/after van het publieke contract (de aanroep en het resultaat).
- Niets zichtbaars: "n.v.t. — <reden>" (alleen toegestaan als er werkelijk niets zichtbaar
  verandert).>

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

## Feature sizing

Eén feature is **~30–45 minuten bouwwerk**. Onderbouwing: elke verse coder-spawn betaalt vaste kosten los van het bouwen zelf — oriëntatie (plan, contract, regels en codebase herlezen) én afronding (tests draaien, risky-scan, commit schrijven). Een gemeten missie liet zien dat 9 kleine features samen ~80 minuten oriëntatie en ~63 minuten afronding kostten tegenover maar ~46 minuten echt bouwen: te fijn snijden vermenigvuldigt die overhead zonder bouwwaarde toe te voegen. Is een feature duidelijk korter dan ~30 minuten, dan is die een **samenvoeg-kandidaat** met een verwante buur (zelfde bestanden, zelfde laag, directe afhankelijkheid) — samenvoegen is de default, tenzij een harde reden dat verbiedt (een afhankelijkheidsgrens die serieel niet anders kan, of een milestone-grens die eigen validatie vereist). De grill (stap 4.5) toetst hierop expliciet vóór de approval gate.

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
- **VC-5** (scrutiny-review): *Given* the tests this milestone adds or changes, *when* the reviewer reads them, *then* every test imports the real production code (no copied or mimicked logic in the test file), no test passes vacuously (still green when the import fails), and at least one test exercises the real integration path through the public entrypoint. · *Green tests prove real behaviour.* *(features: F1, F2)*
- **VC-6** (scrutiny-review): *Given* the committed code of this milestone, *when* the reviewer reads the diff, *then* the diff introduces no dependency, abstraction, or top-level directory outside these lists — allowed new dependencies: <list verbatim from mission.md>; allowed new abstractions: <list verbatim from mission.md>. · *The code stays within the agreed design budget.* *(features: F1, F2)*

## Robuustheid
One line per feature: the sad-path / realistic-scale VCs that cover it, or an explicit
user-confirmed waiver. `validate-artifacts.sh` fails the plan when a feature has neither.
- **F1**: VC-2
- **F2**: waiver — <reden, door de gebruiker bevestigd>

## App boot (user-testing)
- boot: `npm run dev`
- ready: HTTP GET `http://localhost:3000/health` → 200 (timeout 60s)
- smoke: `curl -fsS http://localhost:3000/health`
```

### Writing good assertions

- **Independent of implementation.** "Returns 201 and persists rows", not "calls `saveRows()`". **Exception:** an explicit user agreement from the planning conversation (chosen API, directory layout, forbidden alternative) *may* pin an implementation choice — that is the function of an afspraken-VC (see below).
- **Falsifiable.** A validator must be able to render a clear PASS/FAIL with evidence.
- **Owned.** `scrutiny-review` for anything checkable from the diff/tests; `user-testing` for anything that needs the running app. If there's no bootable app, everything is `scrutiny-review` — but only after the explicit test-infra choice in SKILL.md step 4; never silently.
- **Mapped.** Every VC-ID lists the feature(s) that satisfy it; every feature's `vc_ids` in `state.json` lists the VC-IDs it targets. The two must agree.
- **Comment hygiene is a standing VC.** Every milestone carries one `scrutiny-review` assertion (the VC-4 shape above), regardless of whether `.claude/rules/` exist, enforcing that committed comments/docstrings/commit messages contain no mission-internal codes (feature/milestone/VC IDs, history references) and read standalone. The reviewer judges it like any compliance-VC. The norm is the "Codecommentaar" block in [CONTEXT.md](../../../CONTEXT.md).
- **Test quality is a standing VC.** Every milestone carries one `scrutiny-review` assertion (the VC-5 shape above) enforcing that the milestone's tests prove real behaviour: each test imports the real production code (no copied or mimicked logic in the test file), no test asserts tautologically (a test that also passes when the import fails), and at least one test exercises the real integration path through the public entrypoint. Mocks of *dependencies* are explicitly allowed — only the logic under test must not be duplicated. The reviewer audits this statically and fails the VC hard on violations.
- **Agreements are standing VCs (afspraken-VC's).** Every explicit agreement the user made during planning (chosen API/approach, directory layout, forbidden alternatives) gets its own `scrutiny-review` assertion — only agreements the user actually made, never planner preferences. These deliberately pin implementation choices; that is their function.
- **The design budget is a standing VC.** Every milestone carries one `scrutiny-review` assertion (the VC-6 shape above) with the limitative dependency/abstraction lists from `mission.md` copied verbatim into the assertion text — that is how the reviewer gets to see the budget at all. A diff that introduces anything outside those lists fails the VC.
- **Anchored taste.** Style/taste assertions ("oogt verzorgd", "geen default look") are only allowed when their *then* explicitly references the chosen end state in `mission.md` §"Zo ziet klaar eruit" — otherwise rewrite or drop them.

## Worked example (minimal)

Goal: *"add a /health endpoint"* → slug `health-endpoint`.

- **PRD**: problem = no liveness probe for the deploy platform; metric = probe returns 200 < 100ms. Zo ziet klaar eruit: `curl localhost:3000/health` → `200 {"status":"ok"}`.
- **Gates**: G1 `npm test`, G2 `npx tsc --noEmit`.
- **Assertions**: VC-1 (scrutiny-review) route returns 200 + `{status:"ok"}`; VC-2 (user-testing) `GET /health` on the booted app returns 200; VC-3 (scrutiny-review) an unknown path returns 404, not 200 — plus the three standing per-milestone VCs as VC-4..VC-6 (comment hygiene, test quality, design budget).
- **Robuustheid**: F1 → VC-3.
- **Features**: F1 "add route + test" → M1. **Milestone**: M1 "health live" → [F1], gates [G1,G2], VCs [VC-1..VC-6].
- **Boot**: `npm run dev`, ready-probe `GET /health → 200`.

That's a complete, runnable mission.
