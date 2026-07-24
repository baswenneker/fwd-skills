---
name: fwd:codex-review-plan
description: Adversarial review of a plan BEFORE any code is written, delegated to Codex through the codex plugin's rescue runtime. Resolves the plan itself — a /fwd:plan contract, a /fwd:mission-plan mission, or a /fwd:steps-plan steps-plan (also accepts a path or pasted plan text) — then has Codex attack it for Definition of Done (DoD) coverage gaps, unobservable evidence lines, stale assumptions, and the classic risk categories (auth, data loss, rollback, races, empty-state, schema drift, observability). Read-only — never edits the plan and never writes code. Use when the user wants a second, adversarial opinion on a plan before building it, says "review this plan with Codex", "laat Codex dit plan checken", "codex review op dit plan", or invokes /fwd:codex-review-plan.
argument-hint: "[<slug> | <pad> | geplakte plantekst] [focus-tekst]"
allowed-tools: Read, Glob, Grep, Bash, Skill
---

# fwd:codex-review-plan

Codex als adversarial reviewer van een **plan** — vóór er ook maar één regel code komt. Herkent alle drie plan-artefact-families in deze plugin (`/fwd:plan`, `/fwd:mission-plan`, `/fwd:steps-plan`) naast een los pad of geplakte tekst.

**Waarom niet `/codex:adversarial-review`.** Dat command (en `/codex:review`) hebben `disable-model-invocation: true` — een skill kan ze niet aanroepen. De enige bruikbare ingang is `/codex:rescue` (geen disable-vlag), aangeroepen via `Skill(codex:rescue, ...)`. Dat command forwardt intern naar de `codex:codex-rescue`-subagent, die met één `Bash`-call de Codex-companion-runtime draait. Die runtime is **standaard schrijf-capabel** (`--write`) — vandaar de harde read-only-regel in elke prompt die deze skill samenstelt (zie *Shared Codex handoff* onderaan).

## Step 1 — Plan oplossen

Splits `$ARGUMENTS` in een eerste token (bepaalt de loader) en optionele focus-tekst erna:

| Eerste token | Actie |
|---|---|
| leeg | Draai de resolver zonder slug — pakt de meest recente kandidaat over alle drie families. |
| kaal token (kebab-case, geen `/`, geen bestandsextensie — bv. `csv-import`) | Draai de resolver mét dat token als slug. Rest van `$ARGUMENTS` = focus-tekst. |
| pad-achtig (bevat `/` of een bestandsextensie) | `Read` het pad direct — resolver overgeslagen. Rest van `$ARGUMENTS` = focus-tekst. |
| geen van beide (vrije tekst, meerdere woorden die niet als token+rest te splitsen zijn) | Behandel de **hele** `$ARGUMENTS` als inline geplakte plantekst — resolver overgeslagen, geen aparte focus-tekst-extractie (te onbetrouwbaar te scheiden van de plantekst zelf). |

Resolver:

```
bash "${CLAUDE_SKILL_DIR}/scripts/resolve-plan-artifact.sh" [<slug>]
```

Verwerk de exit-code:

- **`0`** — precies één kandidaat. Ga naar Step 2 met de gerapporteerde `family` / `slug` / `path_or_branch` / `branch` / `base_branch`.
- **`1`** — niets gevonden (`not-found:<slug>` of `no-candidates`). Meld dat in platte tekst, wijs naar `/fwd:plan`, `/fwd:mission-plan` of `/fwd:steps-plan`, of vraag om het plan direct te plakken. **Stop.**
- **`2`** — dezelfde slug bestaat in meer dan één family. Toon elke kandidaat (family, slug, `resolved_at`) in platte tekst en vraag welke bedoeld is — **geen** `AskUserQuestion` (zelfde stijl als `/fwd:plan check`'s eigen disambiguatie). **Stop en wacht.**

## Step 2 — Inhoud lezen + staleness

Een `path_or_branch` die met `/` begint is een echt bestand of map → `Read`. Begint hij niet met `/`, dan is het een branch-naam → lees via `rtk git show <path_or_branch>:<relatief pad>`.

| Family | Te lezen |
|---|---|
| `plan-contract` | `path_or_branch` zelf (is al het `.md`-bestand) |
| `mission` | `<root>/mission.md` + `<root>/validation-contract.md` |
| `steps` | `<root>/plan.md` |

(`<root>` = `path_or_branch`; bij een branch-naam is het relatieve pad `.claude/missions/<slug>/mission.md` resp. `.claude/steps/<slug>/plan.md`.)

**Staleness (informatief, geen blokkade).** Eén regel over wat er sinds dit plan veranderde:

- `plan-contract`: `rtk git diff --stat <basis-commit-uit-het-contract> HEAD -- .`
- `mission` / `steps`:
  ```
  MB="$(rtk git merge-base <branch> <base_branch>)"
  rtk git diff --stat "$MB" "<base_branch>"
  ```
  (toont wat er op de basisbranch is veranderd sinds het plan werd afgetakt)

Leeg resultaat → "geen wijzigingen sinds het plan." Niet-leeg → één zin samenvatting. Dit gaat mee de Codex-prompt in (Step 3), het blokkeert niets.

## Step 3 — Adversarial-prompt samenstellen

Eén samengestelde tekst, **Engels** (de Codex-runtime en zijn eigen prompts zijn doorgaans Engels; de rest van deze skill — inclusief alles wat je aan de gebruiker meldt — blijft Nederlands). Sjabloon:

```
--fresh

READ-ONLY ADVERSARIAL REVIEW — no edits, no fixes, no file writes. Do not add --write. Diagnosis and review only.

You are adversarially reviewing a PLAN before any code is written — not a diff. Your job is to find the strongest reasons this plan should not be approved as-is, not to validate it.

Plan: <titel> (<family>: <slug>)

<volledige plan-inhoud uit Step 2 — DoD, Wijzigingen-tabel of VC-lijst, aannames, relevante context>

Staleness: <de één-zin-samenvatting uit Step 2>

User focus: <de focus-tekst uit Step 1, of "none">

Review this plan for:
1. DoD/VC coverage — does the changes table (or VC list) together cover the entire Definition of Done, or is there a criterion with no matching line?
2. Evidence lines — is every "proof" line actually observable as written, or does it depend on something that doesn't exist yet (a key, an environment, a command that won't run)?
3. Assumption staleness — do this plan's assumptions still hold against the current repository state (see Staleness above)?
4. The standard risk categories, applied to what this plan PROPOSES to build (not existing code): auth/permissions/tenant isolation, data loss or irreversible state changes, rollback/retry/idempotency gaps, race conditions/ordering assumptions, empty-state/null/timeout/degraded-dependency behavior, schema drift/version skew, observability gaps.

Report only findings you can support from the plan content given above. For each: what can go wrong, why this plan is vulnerable to it, the likely impact, and a concrete change TO THE PLAN (not to code) that would reduce the risk. Mark inferences as inferences and keep confidence honest. Do not invent files, functions, or behavior not present in the plan content above. If the plan looks solid, say so directly and report no findings.
```

Weeg `User focus` zwaar als aanwezig, maar laat andere materiële bevindingen niet vallen (zelfde regel als de plugin's eigen `/codex:adversarial-review`).

## Step 4 — Overdracht

```
Skill(codex:rescue, args: <de samengestelde tekst uit Step 3>)
```

Zie *Shared Codex handoff* hieronder voor de harde regels (altijd `--fresh`, nooit `--background`, quoting, git-status-bracket).

## Step 5 — Presenteren & stoppen

Volg *Shared Codex handoff* voor presentatie. Skill-specifiek: "opvolgen" betekent hier **het plan bijwerken** — opnieuw `/fwd:plan`, `/fwd:mission-plan` of `/fwd:steps-plan` aanroepen met de bevinding als input. Deze skill wijzigt het plan-artefact zelf nooit.

## Shared Codex handoff

- Altijd `--fresh` als eerste token — een onafhankelijke reviewthread, nooit stilzwijgend een oude coding-sessie voortzetten.
- Altijd als openingsregel, verbatim: `READ-ONLY ADVERSARIAL REVIEW — no edits, no fixes, no file writes. Do not add --write. Diagnosis and review only.`
- Nooit `--background` — de bevindingen moeten in dezelfde beurt landen.
- Vermijd rauwe dubbele aanhalingstekens in de samengestelde tekst (de subagent wikkelt hem in `"..."` voor zijn eigen Bash-call) — gebruik enkele aanhalingstekens of parafraseer.
- Vóór de aanroep: `rtk git status --porcelain --untracked-files=all` vastleggen; ná de aanroep opnieuw, en elke afwijking als eerste melden, vóór de bevindingen — niets wordt automatisch teruggedraaid.
- Bevindingen presenteren op severity, exacte `file:line`, Codex' eigen feit/inferentie-onderscheid bewaard; "geen bevindingen" expliciet benoemen als de lijst leeg is.
- Stop na het presenteren. Nooit zelf fixen, nooit een plan-contract of mission/steps-artefact bewerken, nooit doorgaan zonder de gebruiker. Sluit af met een platte-tekstvraag welke bevinding(en), indien enige, opgevolgd moeten worden — en wacht.

## Style

- Nederlands, technische termen Engels; schrijf afkortingen uit bij eerste gebruik (DoD = Definition of Done).
- De Codex-prompt zelf (Step 3) is Engels — dat is interne machinerie, geen gebruikersoutput.
- Geen `Write`/`Edit` in `allowed-tools` — deze skill kan structureel niets bewerken, niet alleen via instructie.
