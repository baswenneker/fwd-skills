---
name: codex-review-implementation
description: Adversarial review of the DIFF after implementation, checked against a resolved plan — a /fwd:plan contract, a /fwd:mission-plan mission, or a /fwd:steps-plan steps-plan — delegated to Codex through the codex plugin's rescue runtime. Determines the diff scope automatically (a resolved mission/steps branch's own commits, or the working tree as a fallback), then asks Codex the standard adversarial risk categories plus, when a plan was found, plan-fidelity questions (does the diff satisfy every Definition of Done (DoD)/VC line, did scope silently grow or shrink). Read-only — never edits code or the plan. Use when the user wants a second, adversarial opinion on an implementation before it ships, says "review this diff with Codex", "laat Codex deze implementatie checken", "codex review op deze diff", or invokes /fwd:codex-review-implementation.
argument-hint: "[--base <ref>] [--scope auto|working-tree|branch] [<slug>] [focus-tekst]"
allowed-tools: Read, Glob, Grep, Bash, Skill
---

# fwd:codex-review-implementation

Codex als adversarial reviewer van een **diff**, na implementatie — getoetst tegen het plan waar die diff tegen aanleunt (indien een plan te vinden is). Zusterskill van [`fwd:codex-review-plan`](../codex-review-plan/SKILL.md); hergebruikt daarvan de resolver-script en de leesprocedure.

**Waarom niet `/codex:adversarial-review`.** Zelfde reden als bij de zusterskill: `disable-model-invocation: true` sluit dat command uit voor skills. De ingang is `Skill(codex:rescue, ...)` — zie *Shared Codex handoff* onderaan.

## Step 1 — Scope + plan ophalen

Parse `--base <ref>` en `--scope auto|working-tree|branch` als losse tokens uit `$ARGUMENTS` — expliciete flags winnen altijd. Van de rest: eerste token bare-slug-achtig → resolver-slug; pad-achtig of vrije tekst → geen resolver, alleen focus-tekst (zelfde heuristiek als de zusterskill's Step 1). Rest na het eerste token = focus-tekst.

Zonder expliciete `--base`/`--scope`, of bij `--scope auto`:

```
bash "${CLAUDE_SKILL_DIR}/../codex-review-plan/scripts/resolve-plan-artifact.sh" [<slug>]
```

- **Exit `2`** (ambiguïteit) → zelfde platte-tekst-disambiguatie als de zusterskill. Stop en wacht.
- **Exit `0`, family `mission` of `steps`** → diff-scope = dat artefact's eigen branch:
  - Worktree bestaat nog (`.trees/mission/<slug>/` resp. `.trees/steps/<slug>/`) → diff **inclusief** ongecommit werk:
    ```
    MB="$(rtk git -C <worktree> merge-base <base_branch> HEAD)"
    rtk git -C <worktree> diff "$MB"
    ```
  - Geen worktree (al gemerged, of nog niet gestart) → alleen het gecommitte deel:
    ```
    rtk git diff <base_branch>...<branch>
    ```
- **Exit `0`, family `plan-contract`, of exit `1`** → terugvallen op dezelfde heuristiek als `/codex:adversarial-review` zelf: `rtk git status --short --untracked-files=all`, `rtk git diff --shortstat --cached`, `rtk git diff --shortstat`. Iets gevonden → scope = working tree. Niets gevonden → meld dat er niets te reviewen is en **stop**.

Expliciete flags overschrijven dit: `--base <ref>` → scope = `<ref>` tegen HEAD/working tree; `--scope working-tree` → altijd working tree, ook als er een mission/steps-slug resolvet; `--scope branch` → altijd de branch-diff hierboven.

**Plan-content lezen (indien een family is opgelost).** Exact de procedure uit [`fwd:codex-review-plan`'s Step 2](../codex-review-plan/SKILL.md) — dezelfde worktree-first → plain-file → `git show`-keuze op `path_or_branch`, dezelfde family→bestand-tabel (`mission.md`+`validation-contract.md`, of `plan.md`, of het contract zelf). Geen resultaat (exit `1`) → geen plan-content, Step 3 draait dan zonder plan-fidelity-vragen.

## Step 2 — Deterministische bestandsdekking (alleen `plan-contract`)

Uitsluitend wanneer Step 1 een `plan-contract` heeft opgelost — de enige family met een geverifieerd exact bestand-naar-plan-mechanisme. Hergebruik de twee rtk-gefilterde pipelines uit [`plan/REFERENCE.md`](../plan/REFERENCE.md) **verbatim**, tegen het contract's eigen Basis-commit:

```
rtk git diff --name-only <basis-commit> -- . ':(exclude).claude/plan-contracts' 2>/dev/null | grep -vE '^(ok|Changes:|[[:space:]]*)$'
rtk git status --porcelain --untracked-files=all 2>/dev/null | grep -vx 'ok' | grep '^??' | sed 's/^?? //' | grep -v '^\.claude/plan-contracts/'
```

Leg de vereniging van beide naast de contract's Wijzigingen-tabel; bouw drie rijen: geraakt-en-verwacht (ok) · geraakt-maar-niet-in-tabel (afwijking) · in-tabel-maar-niet-geraakt (ontbreekt). Neem deze tabel **verbatim** mee in de Step 3-prompt.

**Mission/steps: expliciet overslaan.** Geen ongeverifieerde bestand-naar-feature-mapping verzinnen — voor die families beoordeelt Codex de diff rechtstreeks tegen de rijkere plantekst (VC-lijst met file-by-file-tabellen, of de stappenlijst) die Step 1 al heeft gelezen.

## Step 3 — Adversarial-prompt samenstellen

Eén samengestelde tekst, **Engels** (zelfde reden als de zusterskill). Sjabloon:

```
--fresh

READ-ONLY ADVERSARIAL REVIEW — no edits, no fixes, no file writes. Do not add --write. Diagnosis and review only.

You are adversarially reviewing a code change. Your job is to find the strongest reasons this change should not ship yet, not to validate it.

Scope: <de exacte git-instructie/commando uit Step 1>

[alleen als een plan is opgelost:]
Plan: <titel> (<family>: <slug>)
<volledige plan-inhoud uit Step 1>

File coverage vs. the plan's changes table (computed deterministically — do not recompute):
<Step 2-tabel verbatim, alleen bij plan-contract>
[/alleen als een plan is opgelost]

User focus: <focus-tekst uit Step 1, of "none">

Review this change for:
1. The standard risk categories: auth/permissions/tenant isolation, data loss or irreversible state changes, rollback/retry/idempotency gaps, race conditions/ordering assumptions, empty-state/null/timeout/degraded-dependency behavior, schema drift/version skew, observability gaps.
[alleen als een plan is opgelost, extra:]
2. Plan fidelity — does the diff satisfy every DoD/VC line in the plan above, or is something missing or weakened? Does every reason stated in the plan still hold given what was actually built? Has scope silently grown (unrequested extras) or shrunk (something promised but not delivered) versus the plan?
[/alleen als een plan is opgelost]

Report only findings you can support from the actual diff and the context above. For each: what can go wrong, why this code is vulnerable to it, the likely impact, and a concrete fix. Mark inferences as inferences and keep confidence honest. Do not invent files, functions, or behavior you cannot verify. If the change looks safe and faithful to the plan, say so directly and report no findings.
```

## Step 4 — Overdracht

```
Skill(codex:rescue, args: <de samengestelde tekst uit Step 3>)
```

Zie *Shared Codex handoff* hieronder voor de harde regels.

## Step 5 — Presenteren & stoppen

Volg *Shared Codex handoff* voor presentatie. Skill-specifiek slotpunt: was de opgeloste family `plan-contract`, voeg dan één verwijzende regel toe: *"Aanvullend, mechanisch: `/fwd:plan check <slug>` toetst dezelfde diff tegen de bewijsregels van de Definition of Done (DoD)."* — een verwijzing, geen geketende aanroep; bij `mission`/`steps` blijft die regel weg (die families hebben geen vergelijkbare check-modus).

## Shared Codex handoff

- Altijd `--fresh` als eerste token — een onafhankelijke reviewthread, nooit stilzwijgend een oude coding-sessie voortzetten.
- Altijd als openingsregel, verbatim: `READ-ONLY ADVERSARIAL REVIEW — no edits, no fixes, no file writes. Do not add --write. Diagnosis and review only.`
- Voeg zelf nooit `--background` toe. Landt de review tóch als achtergrondtaak (`Async agent launched`, `Codex Task started in the background`), meld dat in één regel, wacht de task-notificatie af of poll met `codex-companion.mjs status <task-id>`, en presenteer pas daarna — verzin nooit zelf een poll-lus met `sleep`.
- Vermijd rauwe dubbele aanhalingstekens in de samengestelde tekst (de subagent wikkelt hem in `"..."` voor zijn eigen Bash-call) — gebruik enkele aanhalingstekens of parafraseer.
- Vóór de aanroep: `rtk git status --porcelain --untracked-files=all` vastleggen; ná de aanroep opnieuw, en elke afwijking als eerste melden, vóór de bevindingen — niets wordt automatisch teruggedraaid.
- Bevindingen presenteren op severity, exacte `file:line`, Codex' eigen feit/inferentie-onderscheid bewaard; "geen bevindingen" expliciet benoemen als de lijst leeg is.
- Geen shell-redirect binnen deze skill — geen `>`, `>>`, `tee` of heredoc naar een bestand. `Bash` dient uitsluitend git-inspectie en het samenstellen van de Codex-prompt.
- Stop na het presenteren. Nooit zelf fixen, nooit een plan-contract of mission/steps-artefact bewerken, nooit doorgaan zonder de gebruiker. Sluit af met een platte-tekstvraag welke bevinding(en), indien enige, opgevolgd moeten worden — en wacht.

## Style

- Nederlands, technische termen Engels; schrijf afkortingen uit bij eerste gebruik (DoD = Definition of Done).
- De Codex-prompt zelf (Step 3) is Engels — dat is interne machinerie, geen gebruikersoutput.
- Geen `Write`/`Edit` in `allowed-tools`; `Bash` blijft nodig voor git-inspectie, dus de read-only-belofte leunt deels op instructie (zie het verbod op shell-redirects in het gedeelde Codex-handoff-blok).

## Gedeelde taalregel

Alle tekst die een mens leest — een narrative, walkthrough, evidence-regel, tussenbalans of eindrapport — is Nederlands, legt zichzelf uit en bevat geen skill-interne taal. Verboden in die tekst: statuscodes als S2, `gate ✓ 10/10`, `interim_review=not-due` en `run_mode`, kale criterium-codes als VC-3 en DoD #3, en de woorden "gate", "seam", "ponytail" en "YAGNI". Schrijf de zaak zelf: "alle 47 tests groen", "criterium 3: de CLI geeft exitcode 1 bij lege invoer", "de plek in de code waar de test aanhaakt". Ernstlabels uit ander gereedschap (P2, [high], Required) vertaal je: "ernstig genoeg om nu te fixen". Elke vakterm krijgt bij eerste gebruik één uitlegzin — in elk nieuw rapport opnieuw. Interne velden houden hun vocabulaire: JSON voor de orchestrator, tags, bestandsnamen en code-identifiers zijn geen gebruikerstekst.
