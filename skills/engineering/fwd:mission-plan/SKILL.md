---
name: fwd:mission-plan
description: Plan a multi-agent "mission" — scope a software goal through conversation, write a PRD plus a validation contract (what "done" means, before any code), decompose into features and milestones, then create the mission branch and persist the plan on it. The interactive half of the fwd:mission-* orchestration layer (modelled on Factory.ai Missions); execution is handled afterwards by /fwd:mission-run. Use when the user wants to plan a larger feature as an orchestrated mission, says "plan a mission", "start a mission", "scope this as a mission", or invokes /fwd:mission-plan.
argument-hint: <the software goal, or empty to scope interactively>
allowed-tools: Read, Glob, Grep, Bash, WebFetch, WebSearch, AskUserQuestion, Write
---

# fwd:mission-plan

Turn a software goal into an executable **mission**: a PRD, a validation contract, and an ordered feature/milestone plan — committed on a `mission/<slug>` branch and ready for `/fwd:mission-run`.

This is the **interactive** half of the `fwd:mission-*` layer. Factory's insight: *the planning phase matters most, and the validation contract defines what "done" means before any code is written.* So this skill is deliberately conversational — get the contract right here and execution becomes mechanical.

**Interactive-mode principle.** Unlike `/fwd:mission-run` (which runs unattended and never prompts), this skill **should** ask. `AskUserQuestion` is allowed and encouraged for discrete choices. Iterate the PRD and contract in plain text until the user approves.

**Vraaghygiëne (geldt voor élke vraag in deze skill — stap 1 t/m 5).**

1. **Zelfstandig leesbaar.** Benoem welk deel van het plan de vraag raakt en waarom de keuze ertoe doet — de vraag moet begrijpelijk zijn zonder de voorgaande conversatie terug te lezen.
2. **Gewone taal.** Geen vakterm die de gebruiker zelf nog niet gebruikte; bij twijfel één concreet voorbeeld of mini-diagram van wat elke optie voor het eindresultaat betekent.
3. **Impact per optie.** Elke antwoordoptie krijgt één regel in gewone taal: wat betekent deze keuze voor het eindresultaat?

Voor niet-triviale keuzevragen: volg het format van fwd:grill-me ([QUESTION_FORMAT.md](../../productivity/fwd:grill-me/references/QUESTION_FORMAT.md)). De drie regels staan bewust ook hier inline, zodat de norm blijft werken als dat pad ooit breekt.

**No product code.** This skill writes only mission artifacts (`mission.md`, `validation-contract.md`, `state.json`). It never implements features — that's the coder's job under `/fwd:mission-run`.

See [REFERENCE.md](REFERENCE.md) for the PRD + contract templates and slug rules, and [`fwd:mission-run`'s reference](../fwd:mission-run/REFERENCE.md) for the canonical `state.json` schema.

## Regelsinventaris (sessiestart)

De beschikbare `.claude/rules/` worden bij het laden van de skill automatisch geïnjecteerd:

!`bash "${CLAUDE_SKILL_DIR}/scripts/list-rules.sh"`

Gebruik deze inventaris als startpunt: elke bewering in het validatiecontract moet de aanwezige regels respecteren.

## Quick start

```
/fwd:mission-plan add CSV import with clipboard paste
# → scope → PRD → contract → milestones → approve → commits mission/<slug>
# then:
/fwd:mission-run <slug>
```

## Flow

### 1. Scope the goal (gather context)

**Stap 1.0 — Regelskeuze (verplicht, vóór alle scopingwerk).**

Bekijk de regelsinventaris bovenaan (geïnjecteerd bij sessiestart). Als die meldt dat er **geen regels zijn gevonden**, stel dan via `AskUserQuestion` een bewuste keuze voor — stilzwijgend doorgaan is geen optie:

> De inventaris toont geen `.claude/rules/`. Hoe wil je verder?
>
> (a) Stop en draai eerst `/fwd:rules-audit` om de projectconventies vast te leggen. (Aanbevolen — een contract zonder regels mist de feitelijke codeerstandaarden.)
>
> (b) Ga expliciet verder zónder regels. De planning loopt door, maar in `mission.md` wordt vastgelegd: "Bewust gestart zonder `.claude/rules/` — regels ontbreken."

Op keuze (a): stop hier. Op keuze (b): ga door en leg de keuze vast in de `mission.md` (sectie *Aannames en afwijkingen*).

Read enough to plan, not to implement. Restate the goal in your own words. Then:

- 2–4 targeted `Glob`/`Grep` passes on terms from the goal; read 2–4 key files to learn existing patterns (naming, structure, conventions).
- Skim `CLAUDE.md`, `CONTEXT.md`, any `docs/adr/`, and rule files under `.claude/rules/` if present — every assertion in the contract must respect these.
- For libraries/frameworks, pull current docs (Context7 MCP if available, else `WebSearch`).

If the goal is ambiguous, ask now (`AskUserQuestion`) — a sharp contract depends on a sharp goal.

### 2. Draft the PRD (`mission.md`)

Present a confident PRD draft in plain text (not `AskUserQuestion`), built from real Step 1 findings, using the Factory shape (full template in REFERENCE.md):

1. **Problem Statement** — who hurts, and the measurable cost.
2. **Goals & Success Metrics** — the primary goal + measurable targets.
3. **Acceptance Criteria** — observable, testable; these seed the Layer-B assertions.
4. **Zo ziet klaar eruit** — het concrete eindbeeld: bij UI-werk een ASCII-mockup of referentiescreenshot (bied bij smaakgevoelig werk 2–3 stijlvarianten aan en laat de gebruiker kiezen), bij CLI/API-werk een letterlijk input→output-voorbeeld, bij een refactor een before/after van het publieke contract; anders "n.v.t. — <reden>". Template in REFERENCE.md.
5. **Implementation Strategy** — approach + the existing patterns to follow.
6. **File-by-file breakdown** — concrete paths (only real paths from Step 1).
7. **Testing & Verification** — how correctness is confirmed.
8. **Security considerations** — secrets, input validation, authz.

Stop and let the user correct it in plain text. Re-render on changes. Don't bluff — if Step 1 was too thin, say what context you're missing and wait. De draft is niet compleet zonder het Zo-ziet-klaar-eruit-blok; de approval gate (stap 5) mag niet bereikt worden zolang het ontbreekt.

### 3. Decompose into features → milestones

Once the PRD holds, propose an **ordered** feature list grouped into **milestones** (validation checkpoints):

- Each feature is one coherent, committable unit; features are serial and inherit each other via git.
- Each feature maps to the acceptance criteria (VC-IDs) it must satisfy.
- A milestone is a meaningful checkpoint where the validators run. Smaller milestones = more frequent validation = a more stable foundation for long missions.

**Feature-sizing.** Eén feature is **~30–45 minuten bouwwerk**. Reden: elke verse coder-spawn betaalt vaste kosten die niets met bouwen te maken hebben — oriëntatie (plan, contract, regels en codebase herlezen) én afronding (tests draaien, risky-scan, commit schrijven). Een gemeten missie liet zien dat 9 kleine features samen ~80 minuten oriëntatie en ~63 minuten afronding kostten tegenover maar ~46 minuten echt bouwen — te fijn snijden vermenigvuldigt overhead zonder bouwwaarde toe te voegen. Is een voorgestelde feature duidelijk korter dan ~30 minuten, dan is die een **samenvoeg-kandidaat** met een verwante buur (zelfde bestanden, zelfde laag, of een directe afhankelijkheid) — samenvoegen is de default, tenzij een harde reden dat verbiedt (een afhankelijkheidsgrens die serieel niet anders kan, of een milestone-grens die apart validatie vereist).

**Order features so each builds on the ones before it.** Features execute serially in array order, each inheriting its predecessors' code via git, so sequence is the only ordering signal — place a feature after everything it depends on. Present as a numbered tree, e.g.:

```
M1 → F1, F2, F3
M2 → F4
```

Let the user reorder or split features in plain text.

### 4. Write the validation contract (`validation-contract.md`)

**Layer A — gates.** Run:

```
bash "${CLAUDE_SKILL_DIR}/scripts/discover-gates.sh"
```

It prints a JSON array of resolvable gate commands (test/typecheck/lint/build — only ones that actually resolve). Show them to the user and confirm (`AskUserQuestion` or plain text); drop or add as needed. These become `state.gates`. Print het script een **lege array** (`[]` — geen enkele gate resolvet), dan geldt de test-infra-gate verderop in deze stap: een verplichte expliciete keuze. Stilzwijgend doorgaan zonder één gate is geen optie.

**Layer B — assertions.** Write per-feature/per-milestone acceptance criteria as `given / when / then`, each with a stable ID (`VC-1`, `VC-2`, …) and an `owner` tag:
- `scrutiny-review` — judged against the diff by the adversarial reviewer.
- `user-testing` — judged against the running app by the user-tester.

Elke VC bevat ook een één-regel-samenvatting in gewone taal (het `· *cursief*`-patroon — zie REFERENCE.md voor het template).

**Smaak-VC's zijn verankerd.** Stijl- en smaak-assertions ("oogt verzorgd", "geen default look") zijn alleen toegestaan als hun *then* expliciet verwijst naar het gekozen eindbeeld in `mission.md` §"Zo ziet klaar eruit" — anders herschrijven of schrappen. Zonder anker kan geen validator erop falen en wordt smaak een gok van de coder.

**Compliance-VC-generatie (verplicht wanneer `.claude/rules/` niet leeg is).** Zet de file-by-file-tabel van de PRD om in contract-criteria als volgt:

1. Neem per feature de paden uit de file-by-file-tabel.
2. Vergelijk die paden met de `paths:`-globs in elk regelbestand (een regelbestand *zonder* `paths:`-frontmatter is repo-breed en matcht altijd).
3. Per feature: schrijf de matchende regelbestanden als `rule_paths` in `features[]` van `state.json`.
4. Genereer per match een compliance-assertion in Layer B, bijv.: "Feature X's aangepaste bestanden voldoen aan rule Y — beoordeeld door de reviewer."
5. Bij materialisatie (het schrijven van `state.json` op de mission-branch): vul het top-level `rules_manifest` met `[{path, sha256}]` per regelbestand. Zie het schema in `../fwd:mission-run/REFERENCE.md` (schema v3) — documenteer het schema hier niet opnieuw.

**Comment-hygiëne-VC (verplicht — elke milestone, altijd).** Voeg per milestone één staande `scrutiny-review`-assertion toe die zelfstandig leesbare comments afdwingt, gemapt op álle features van die milestone. Dit geldt onafhankelijk van of er `.claude/rules/` zijn — zo heeft de reviewer altijd een VC-ID-slot om hard op te falen. Sjabloon:

> **VC-N** (scrutiny-review): *Given* de gecommitte code van deze milestone, *when* de reviewer de diff leest, *then* bevat geen enkele comment, docstring of commit message een mission-interne code (feature-ID, milestone-ID, validatiecriterium-ID of historie-verwijzing zoals "pre-F4") — elke comment is zelfstandig leesbaar. · *Comments leggen het wat/waarom uit, zonder mission-jargon.* *(features: alle van deze milestone)*

De norm die deze VC afdwingt is de "Codecommentaar"-block in [CONTEXT.md](../../../CONTEXT.md).

**Test-kwaliteits-VC (verplicht — elke milestone, altijd).** Voeg per milestone één staande `scrutiny-review`-assertion toe die afdwingt dat de tests van die milestone echt gedrag bewijzen, gemapt op álle features van die milestone. Sjabloon:

> **VC-N** (scrutiny-review): *Given* de tests die deze milestone toevoegt of wijzigt, *when* de reviewer ze leest, *then* importeert elke test de échte productiecode (geen gekopieerde of nagebootste logica in het testbestand), bevat geen test een tautologische assert (een test die ook slaagt als de import faalt), en oefent minstens één test het echte integratiepad via de publieke entrypoint in plaats van direct opgebouwde interne state. · *De groene tests bewijzen echt gedrag.* *(features: alle van deze milestone)*

Mocks van *dependencies* blijven toegestaan — alleen de logica ónder test mag niet gedupliceerd zijn. De reviewer auditeert dit statisch en laat vacueuze of gekopieerde-logica-tests hard op deze VC falen.

**Afspraken-VC's (verplicht zodra de gebruiker expliciete afspraken maakte).** Houd tijdens stap 2–3 een lijst **"Expliciete afspraken"** bij: gekozen aanpak of API, beoogde mappenstructuur, verboden alternatieven — alléén afspraken die de gebruiker zélf maakte, geen planner-voorkeuren. Zet élke afspraak om in een eigen `scrutiny-review`-VC met gewone-taal-samenvatting. Sjabloon:

> **VC-N** (scrutiny-review): *Given* de diff, *when* de reviewer de agent-constructie leest, *then* wordt `create_agent` gebruikt en komt `create_deep_agent` nergens voor. · *We gebruiken de afgesproken API, niet het alternatief.* *(features: F<n>)*

Afspraken-VC's mógen implementatiekeuzes vastleggen — dat is precies hun functie (zie de uitzondering op "Independent of implementation" in REFERENCE.md).

**Design-budget-VC (verplicht — elke milestone, altijd).** Voeg per milestone één staande `scrutiny-review`-assertion toe die het design budget afdwingt, gemapt op álle features van die milestone. Kopieer de limitatieve lijsten uit `mission.md` §"Strategy & Design Budget" **verbatim in de VC-tekst** — zo krijgt de reviewer het budget te zien (zonder deze VC bindt het alleen de coder en heeft "overschrijden laat een review zakken" geen handhavingspad). Sjabloon:

> **VC-N** (scrutiny-review): *Given* de gecommitte code van deze milestone, *when* de reviewer de diff leest, *then* introduceert de diff geen dependency, abstractie of top-level map buiten deze lijsten — toegestane nieuwe dependencies: <lijst verbatim uit mission.md>; toegestane nieuwe abstracties: <lijst verbatim uit mission.md>. · *De code blijft binnen het afgesproken design budget.* *(features: alle van deze milestone)*

**App-boot config (for user-testing).** Discover boot candidates (`package.json` `dev`/`start`/`serve`, `Procfile`, `docker-compose.yml`, `Makefile` run target). Confirm with the user: the `boot_command`, a `ready_probe` (HTTP poll or log-line match — essential), and 1–3 `smoke_commands`. Benoem bij die bevestiging expliciet dat stap 4.7 het boot-commando straks **écht draait in de hoofd-checkout, mét de echte `.env`** — een boot_command met seeds of migraties raakt dus de dev-omgeving.

**Test-infra-gate (verplichte keuze — stille degradatie is verboden).** Raakt de missie UI of browser-runtime, check dan de testlaag: is er een boot-kandidaat, en heeft het project een browser-testlaag? (Zoek in `package.json` naar `playwright`/`jsdom` en naar `playwright.config.*` — dit voedt meteen `playwright_present`.) Ontbreekt de boot_command óf de browser-testlaag, stel dan via `AskUserQuestion` een bewuste keuze voor, naar het model van stap 1.0:

> (a) Neem het opzetten van de testlaag op als **eerste feature** van de missie. Begrensd in het design budget: één dependency, één configbestand, één smoke-spec — niet meer.
>
> (b) Accepteer expliciet dat de betreffende VC's alleen op code-inspectie steunen. Hertag dan ook de owners: elke VC die van de ontbrekende laag afhing wordt `(scrutiny-review)` — een achtergebleven `(user-testing)`-owner zonder boot_command laat de plan-lint bij stap 6 hard falen. Leg de keuze vast in `mission.md` §*Aannames en afwijkingen* én als kopregel bovenin het contract: "Bewust geaccepteerd: VC-<x>..<y> steunen alleen op code-inspectie."

Dezelfde verplichte keuze geldt bij een **lege gates-array** uit `discover-gates.sh` (testcommando opzetten als eerste feature, of expliciet accepteren — vastgelegd in `mission.md`). Alleen voor een echt niet-bootbare library zonder UI blijft alles-`scrutiny-review` geldig — maar ook dát wordt als expliciete keuze genoteerd, nooit stilzwijgend aangenomen.

### 4.5. Simplicity & robustness grill (vóór de approval gate)

Toets het plan op vijf vragen vóórdat de gebruiker het goedkeurt. Presenteer bevindingen als plain text; verwerk ze in het plan als er actie op volgt.

1. **Kunnen features samengevoegd?** Zijn er features die samen kleiner en begrijpelijker zijn dan apart? Elke onnodige feature-grens is extra orchestratie-overhead. Toets hier expliciet de feature-sizing-richtlijn uit stap 3 (~30–45 minuten bouwwerk per feature): schat per feature de bouwtijd, en merk elke feature die duidelijk onder de richtlijn zit aan als samenvoeg-kandidaat. Dwing een bewuste keuze af — samenvoegen met een verwante buur, of vastleggen welke harde reden (afhankelijkheids- of milestone-grens) het apart houden rechtvaardigt.
2. **Welke component is speculatief?** Een component is speculatief als hij op aannames berust die nog niet door stap 1 (codebase-onderzoek) zijn bevestigd. Markeer speculatieve componenten expliciet.
3. **Wat is het eenvoudigste ontwerp dat het contract haalt?** Controleer of het voorgestelde ontwerp de goedkoopste weg is naar alle VC-IDs — niet meer, niet minder.
4. **Heeft elke user-facing input minimaal één sad-path-VC?** Denk aan: leeg, malformed, quotes/apostrof, te groot, gelijktijdig gebruik. Genereer scenario's met de premortem-denkwijze: "het is al misgegaan — hoe?".
5. **Heeft elke feature die externe of live data raakt minimaal één realistische-schaal-VC?** Denk aan: aantallen zoals in productie, paginering, een lege dataset.

Ontbreekt bij vraag 4 of 5 dekking voor een feature, dan óf een VC toevoegen, óf een expliciete waiver laten bevestigen door de gebruiker via `AskUserQuestion` — een waiver is nooit een planner-default. De dekking (VC's of waiver per feature) landt in de sectie `## Robuustheid` van het contract (template in REFERENCE.md); `validate-artifacts.sh` weigert een plan zonder die sectie.

De uitkomst gaat terug naar de gebruiker. Is er aanleiding tot vereenvoudiging, pas dan de feature-lijst, het design budget of het contract aan vóór stap 5.

### 4.6. Plan-lint — kan elke VC ooit beoordeeld worden?

Loop élke VC langs met de adversariële vraag: **"waarom kan deze nooit beoordeeld worden?"** Vier faalpatronen; elk gevonden geval wordt herschreven of geschrapt vóór de approval gate:

1. **Handmatige UI-handeling in de *then*.** Geen validator kan klikken of een notebook bedienen — zo'n VC is een permanente blocker. Herformuleer naar iets dat de reviewer in de diff of de user-tester via CLI/HTTP kan waarnemen.
2. **Preconditie die nú al onwaar is.** Een *given* die een toestand eist die vandaag niet bestaat (bv. "de git-tree is schoon" bij een dirty repo). Toets zulke precondities écht met een bash-commando — geloof ze niet op papier.
3. **User-testing zonder boot.** Owner `user-testing` terwijl er geen `boot_command` is — die VC wordt bij de run op `null` gezet en nooit beoordeeld.
4. **Then zonder waarneembaar bewijs.** Een *then* waarvoor geen validator concreet bewijs kan aanwijzen (bestand, regel, HTTP-respons, exit code).

Presenteer bevindingen als plain text en verwerk ze vóór stap 5. De machinale kant van deze lint (VC-kruisconsistentie contract ↔ `state.json`, milestone↔feature-integriteit, user-testing ⇒ `boot_command`) draait in `validate-artifacts.sh` bij stap 6 — dat is het vangnet, niet de plek om het te ontdekken.

### 4.7. Boot-preflight (live) — alleen bij een afgesproken boot_command

Test de boot-config nú, in de plan-fase — niet pas bij de eerste milestone. Draai in de hoofd-checkout (de worktree bestaat nog niet):

```
echo '<user_testing-json>' | bash "${CLAUDE_SKILL_DIR}/../fwd:mission-run/scripts/boot-app.sh" --probe
```

De probe checkt eerst of de probe-URL al antwoordt vóór het booten (dan zit een ander proces op de poort), boot dan de app, wacht op de `ready_probe` en ruimt zichzelf op. Géén `smoke_commands` — die kunnen seeds of writes bevatten; de preflight raakt de dev-omgeving zo min mogelijk. Uitkomsten:

- `ready` → noteer het resultaat; bij stap 6 gaat `user_testing.plan_probe = {ok: true, at: "<timestamp>"}` mee in `state.json` (schema v5, additief).
- `port-in-use` → een ander proces (bv. een sibling-workspace) antwoordt al op de probe-URL. Los dat eerst op — een user-tester zou straks de verkeerde app testen.
- `boot-timeout` / `boot-crashed` / `no-boot` → de boot-config klopt niet.

Bij een faal-uitkomst: verplichte keuze via `AskUserQuestion`:

> (a) Fix de boot-config (ander commando, andere poort, andere probe) en draai de preflight opnieuw.
>
> (b) Hertag de user-testing-VC's naar `scrutiny-review`, zet `user_testing.boot_command` op `null` (anders eist de runner bij finalize alsnog een cold-start-proof) en herschrijf de App-boot-sectie in het contract naar "geen — bewust geaccepteerd". Leg het vast zoals bij de test-infra-gate optie (b): `mission.md` §Aannames + kopregel in het contract.
>
> (c) Ga bewust door mét de kapotte boot-config. Waarschuwing: de missie eindigt dan bij finalize op `blocked` — de user-testing-VC's blijven `null` en de cold-start-proof kan nooit gezet worden. Alleen een mens kan dat accepteren via de bestaande waiver (`FWD_MISSION_ACCEPT_UNVERIFIED`, dekt onbewezen VC's én de ontbrekende cold-start-proof) — er komt géén tweede waiver-mechanisme.

### 5. Approval gate

Presenteer het plan gelaagd — eindbeeld eerst, detail daarna:

1. **Eerst het eindbeeld:** "In één oogopslag" + het "Zo ziet klaar eruit"-blok uit de PRD.
2. **Dan per milestone één regel:** "Na M<n> kun je: <zichtbaar gedrag of resultaat>."
3. **Dan pas het volledige detail:** milestone/feature-boom, gates, alle Layer-B-assertions (met hun één-regel-samenvattingen), boot-config mét de uitkomst van de boot-preflight (4.7), en de Robuustheid-sectie.

Sluit af, vóór de `AskUserQuestion`, met de navertel-toets als vaste regel: *"Kun je in twee zinnen aan een collega navertellen wat er gebouwd wordt en hoe je ziet dat het af is? Zo nee → kies Revise."* Ask for explicit approval (`AskUserQuestion`: *Approve & create the mission* / *Revise* / *Cancel*). Only proceed on approval.

### 6. Materialise the mission

On approval, derive a `slug` (kebab-case from the goal, ≤50 chars; see REFERENCE.md), then:

```
bash "${CLAUDE_SKILL_DIR}/scripts/init-mission.sh" <slug>
```

This creates branch `mission/<slug>` off the base branch, a worktree at `.trees/mission/<slug>/`, scaffolds `.claude/missions/<slug>/` (with `handoffs/`) and a skeleton `state.json` (`status: planned`), and prints the **worktree path** on stdout.

Then, into `<worktree>/.claude/missions/<slug>/`, write the three artifacts with the `Write` tool:

- `mission.md` — the PRD from Step 2.
- `validation-contract.md` — Layer A + Layer B from Step 4.
- `state.json` — fill the skeleton: `gates[]`, `user_testing{}` (inclusief `plan_probe` wanneer de boot-preflight uit 4.7 slaagde — schema v5, additief), ordered `features[]` (each with `vc_ids`, `status: "pending"`), `milestones[]` (with `feature_ids`, `validation_status: "pending"`). Match the schema in `../fwd:mission-run/REFERENCE.md` exactly.

Finally validate and commit the plan:

```
bash "${CLAUDE_SKILL_DIR}/scripts/validate-artifacts.sh" <slug>
```

It asserts the three artifacts exist and are well-formed (valid `state.json` with required fields; ≥1 `VC-` in the contract; mission.md bevat `## Zo ziet klaar eruit`; het contract bevat `## Robuustheid` met dekking of waiver per feature) **en draait de plan-lint**: elke feature-`vc_id` bestaat als `**VC-n**`-assertion in het contract en elke contract-assertion hoort bij ≥1 feature; elke milestone-`feature_id` bestaat en elke feature wijst naar een milestone die hem ook terugnoemt; user-testing-VC's vereisen een non-null `boot_command`. Then it commits `.claude/missions/<slug>/` on the mission branch as `docs(mission): scope <slug>`. On a non-zero exit, fix what it reports and re-run — do not hand off a malformed mission.

### 7. Hand off

Report: the slug, the branch, the worktree path, the milestone/feature count, and the run command.

Example output block:

```
Mission planned: <slug>
  Branch:   mission/<slug>
  Worktree: .trees/mission/<slug>/
  Features: <N> across <M> milestones

Run it:
  /fwd:mission-run <slug>
```

For long missions add `/loop` in front of the command.

## Boundaries

- **Schrijfstijl** — all plan narratives, PRD sections, and walkthrough text follow the "Schrijfstijl missions" block in [CONTEXT.md](../../../CONTEXT.md).
- **Plan only** — never implement features or write product code here.
- **Real paths only** in the file-by-file breakdown; no invented files.
- **The contract is written before code** — that's the entire point. Don't defer assertions to "we'll see during implementation".
- Hand off via the slug; don't start execution yourself.
