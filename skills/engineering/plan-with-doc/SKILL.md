---
name: plan-with-doc
description: Plan een feature, refactor of wijziging met DoD, 1-3 plannen en een verdict. Use when user invokes /fwd:plan-with-doc of een implementatie wil plannen;
argument-hint: description of the feature, refactor or change to plan
allowed-tools: Read, Glob, Grep, Bash, WebFetch, WebSearch, AskUserQuestion, Agent, Write
---

# Plan

Drie zichtbare stappen — de flow-regels tonen "Stap 1/2/3 van 3": (1) Definition of Done, (2) verdiepende vragen, (3) plan + verdict. Na de plan-keuze legt de skill stil een licht contract vast (Step 5).

**Hard constraints:**

- **`AskUserQuestion` is toegestaan en gewenst** voor alle numbered-choice vragen in 2b/2c. De DoD (Definition of Done) in 2a is **géén `AskUserQuestion`** maar een plain-text voorstel met numbered bullets; vuur de `AskUserQuestion`-bundle van 2b/2c pas af **nadat** de gebruiker akkoord heeft gegeven.
- **Subagents alleen als de gebruiker er expliciet om vraagt** ("use subagents", "spawn agents to research X"). Default: main turn — subagents kunnen geen vervolgvragen stellen en verstoppen context.
- **`Write` mag uitsluitend contractbestanden onder `.claude/plan-contracts/` raken** — aanmaken in Step 5, bijwerken (toets-uitslag) in de check-modus. Nooit code, nooit een pad daarbuiten.
- **Roep nooit `ExitPlanMode` aan** — ook niet als de sessie in Claude Code plan mode draait en de harness om plan-goedkeuring vraagt; haal de tool ook niet via `ToolSearch` op. Het DoD-akkoord plus het verdict-block is het énige goedkeuringsmoment van deze skill; een tweede goedkeuring erbovenop laat de sessie stranden op een afgewezen tool-call. Dit geldt de hele skill-run, ook ná het verdict.

## Step 1 — Gather context

Lees genoeg om te plannen, niet om te implementeren. Alleen lezen (`Bash` read-only).

1. Herformuleer het verzoek in eigen woorden — wat verandert er werkelijk?
2. Met subagents: doe gerichte Glob/Grep-zoekacties op termen uit het verzoek.
3. Lees 2-4 sleutelbestanden voor bestaande patronen (naming, structuur, conventies).
4. Skim `CLAUDE.md`, `CONTEXT.md`, eventuele `docs/adr/` ADRs, **en alle rule-bestanden onder `.claude/rules/`** — die dicteren de conventies die elk plan respecteert (comments, docstrings, typing, naming, testing patterns).
5. Library/framework → actuele docs die relevant zijn voor het plan (Context7 MCP indien beschikbaar, anders WebSearch).
6. Vorm een scope-beeld. Dit bepaalt welke continue-check-optie (2c) de `(Recommended)`-tag krijgt — kleine scope (hooguit een paar bestanden, low risk, geen architectuurkeuze) → "Plan met 1"; anders → "Plan met 3". De gebruiker kiest zelf; de default is alleen proportioneel.

## Step 2 — Vragen

Scherp krijgen wat onhelder is — gedreven door échte ambiguïteit uit Step 1. Eerst de DoD vastpinnen (2a), dan 0-3 inhoudelijke keuzes + continue-check (2b/2c).

### 2a — Definition of Done (propose & pin, vóór de vragen)

Render eerst — vóór elke `AskUserQuestion` — een **confident voorstel** voor de DoD, gebouwd uit échte Step 1-vondsten (issue-tekst, bestaande tests, contracten). Geen open vraag, geen hedging ("ik vermoed", "denk ik"). Format — numbered bullets, géén box-drawing; open met de flow-regel zodat de gebruiker ziet waar hij in het proces zit:

```
*fwd:plan-with-doc — stap 1 van 3: Definition of Done (daarna: vragen → plan + verdict)*

Definition of Done (DoD) — voorstel:

1. <observeerbaar gedrag, test of contract #1>
   — bewijs: `<commando>` → <verwachte observatie>
2. <criterium #2>
   — bewijs: `<commando>` → <verwachte observatie>
3. <faalgedrag: wat gebeurt er bij foute input / ontbrekende data>
   — bewijs: `<commando>` → <verwachte foutmelding of status>

Ok of geef aan wat je aan wil passen.
```

**Stop de turn na het renderen van de bullets.** Wacht op de plain-text reactie (ok / correctie). Bundel DoD en `AskUserQuestion` niet in dezelfde turn — dat blokkeert de gebruiker (DoD-akkoord botst met openstaande radio-buttons).

Regels:

- 2-5 criteria. Concreet en observeerbaar (gedrag, tests, contracten).
- **Elk criterium krijgt een bewijsregel** — geen enkele uitgezonderd: "— bewijs: `<commando>` → `<verwachte observatie>`" — bij oplevering afvinkbaar hoe "werkend" gedemonstreerd wordt. Hangt het bewijs af van een latere keuze (2b) → kies het meest waarschijnlijke bewijs en pas het daarna aan; nooit "hangt af van stap 2" als bewijsregel. Bewijs vereist een key/omgeving die er nu niet is → expliciet markeren ("— bewijs: **live**, vereist `<X>`"). Een geskipte testmarker of gemockt pad telt níet als bewijs voor een criterium dat echt gedrag belooft — geldt overal waar bewijs beoordeeld wordt (Tests-bullet in Step 3, check-modus).
- **Minstens één criterium beschrijft faalgedrag** (foute input, ontbrekende data, error-pad) — niet alleen de bekende weg.
- Bouw uit échte Step 1-vondsten. Verzin geen criteria.
- Correctie → aangepaste DoD opnieuw renderen als numbered bullets, dán door naar 2b.
- Step 1 te dun om iets voor te stellen → zeg dat expliciet ("ik mis context X — kun je Y wijzen?") en wacht. Niet bluffen.

### 2b — Numbered-choice vragen (via één `AskUserQuestion` bundle)

Render vóór de bundle één flow-regel: `*fwd:plan-with-doc — stap 2 van 3: verdiepende vragen*`.

- **0-3 inhoudelijke vragen** — alleen voor échte ambiguïteit; skip vragen waarvan het antwoord het plan niet zou veranderen.
- **Eén enkele `AskUserQuestion`-call** met meerdere `questions`-items — niet meerdere losse calls.
- De **continue-check (2c)** is het laatste item in dezelfde bundle.

### 2c — Continue-check (verplicht slot van de bundle)

Het laatste item in de `AskUserQuestion` bundle is altijd:

```
question: "Hoe verder?"
header:   "Volgende stap"
options:
  - label: "Plan met 3 alternatieven"
    description: "Drie distincte plannen + aanbeveling"
  - label: "Plan met 1 enkelvoudig"
    description: "Alleen het meest passende plan"
  - label: "Eerst stress-testen"
    description: "Skill stopt; draai /fwd:grill-me of /fwd:premortem en roep /fwd:plan daarna opnieuw aan"
  - label: "Nog een ronde vragen"
    description: "Step 2 herhaalt met nieuwe vragen"
```

**Proportionele default.** Zet de `(Recommended)`-tag op de optie die past bij het scope-beeld uit Step 1 (punt 6): "Plan met 1 enkelvoudig" bij kleine scope, anders "Plan met 3 alternatieven". Richtlijn, geen harde telling (voorbeeldgetallen ankeren — zie LESSONS 2026-06-09). Benoem de reden kort in de option-description van de aangeraden optie (bijv. "scope is klein: 2 bestanden, low risk").

Op basis van de keuze:

- **Plan met 3** → Step 3 in 3-plan modus.
- **Plan met 1** → Step 3 in 1-plan modus.
- **Eerst stress-testen** → skill stopt met:
  > "Type `/fwd:grill-me` (vraagverdieping) of `/fwd:premortem` (faalscenario's vooraf) voor een diepere stress-test. Roep daarna `/fwd:plan-with-doc` opnieuw aan met de aangescherpte context."
- **Nog een ronde vragen** → herhaal Step 2 met nieuwe ambiguïteiten. Maximaal nog één extra ronde; daarna forceer een keuze tussen "Plan met 3" of "Plan met 1".

## Step 3 — Plannen

Open met de flow-regel: `*fwd:plan-with-doc


 — stap 3 van 3: plan + verdict*`. Output-volgorde in één response:

1. **The Question** — 1 regel die het echte probleem framet (niet de artefact-vraag).
2. **Mental Model** — de vorm die het hardst landt voor deze content:
   - *ASCII-diagram* — structureel (call graph, architectuur, request lifecycle). 8-15 regels max, `┌─┐│└─┘ → ↓ ─→`, geen decoratie.
   - *Analogie* — abstract concept. 2-4 regels, brug naar bekend domein.
   - *Before/after* — refactor of migratie. 2-4 regels, oude shape → nieuwe shape.
   - *Causal narrative* — bug of degradatie. 2-4 regels, X → Y → crash.
   - *First principles* — als niets past. 1-2 zinnen die de essentie vatten.

   Landt geen vorm: schrijf `no model added — <reden>` en ga door. Forceer geen vorm.

3. **Plan-blokken** — 1 of 3 onder elkaar (volgens 2c-keuze). Volgorde in 3-plan modus: Minimal → Uitgebreid → Pragmatisch.
4. **Verdict-block** — altijd direct na de plan-blokken (Step 4). Geen `verdict`-commando nodig; de afweging staat standaard onderaan.

### Plan-blok shape (per plan)

Gebruik box-drawing characters voor visuele differentiatie:

```
╭─ Plan A — Minimal ────────────────────╮
│ Files: <N> │ Risk: <low|med|high> │ Effort: <uur|dagen> │
╰───────────────────────────────────────╯

**TL;DR:** [één zin: wat doet dit plan, en wat maakt 't 'minimaal'.]

**Details**
- [3-6 concrete bullets: wat verandert, wat hergebruikt wordt, key decisions]
- **Tests:** per DoD-criterium één regel — niveau (unit/integration/E2E), testbestand, en of het bewijs **live** draait of **gemockt** is; het faalcriterium uit de DoD krijgt aantoonbaar een eigen test. Benoem gemockte kritieke paden expliciet ("CAPTCHA gemockt", "lokale SQLite i.p.v. Turso") — een gemockt pad telt niet als live-bewijs.
- **Regels:** Toepasselijke regels uit `.claude/rules/` worden op elk gewijzigd bestand toegepast.

**Wijzigingen**

| File | Change | Reason |
|------|--------|--------|
| `path/to/feature.ts` | nieuw | [waarom toegevoegd] |
| `path/to/other.ts` | gewijzigd | [wat verandert] |
| `path/to/feature.test.ts` | nieuw | [tests voor welk gedrag] |
```

Het aanbevolen plan krijgt `(Recommended)` direct in de box-header, tussen plan-naam en de sluitende rand (bijv. `╭─ Plan B — Uitgebreid (Recommended) ───╮`).

### De drie plannen (3-plan modus)

Drie distincte trade-offs:

- **Minimal** — kleinste wijziging. Hergebruik bestaande code; geen nieuwe abstracties. Lage risk, kleine diff.
- **Uitgebreid (extensive)** — architectonisch ideaal. Nieuwe abstracties waar het loont; schone scheiding; testbaar. De "doe het goed"-versie.
- **Pragmatisch (pragmatic)** — middenweg. Investeer waar het rendement levert, shortcuts waar de cost laag is.

### Hard regels per plan

- Alleen bestaande paden uit Step 1; geen verzonnen bestanden.
- `Change`-kolom is één van: `nieuw` / `gewijzigd` / `verwijderd`.
- Spec-strip op één regel binnen de box: `Files: <N> │ Risk: <low|medium|high> │ Effort: <ruwe schatting in uur of dagen>`.

### 1-plan modus

Eén plan-blok zonder `(Recommended)`-tag (er is geen alternatief). Direct van Mental Model naar het plan, sluit met de aanbeveling-regel. Bij kleine scope mag het Mental Model vervallen (`no model added — scope is klein`) en volstaan 2-3 Details-bullets; DoD, Tests-bullet, Wijzigingen-tabel en verdict blijven verplicht.

## Step 4 — Verdict (altijd, direct na de plannen)

Render het verdict-block standaard, in dezelfde response als de plan-blokken:

```
## Verdict

[2-4 zinnen: vergelijking van de plannen tegen de gebruiker's situatie — constraints, codebase-state, size of change, risk profile.]

**Aanbeveling: Plan [A | B | C]**

[2-4 zinnen: *waarom* dit plan past. Verbind aan Step 1 bevindingen + Step 2 antwoorden. Benoem de éne trade-off die deze keuze accepteert versus de alternatieven.]
```

Regels:

- **Kies een winnaar.** "Hangt af van je voorkeur" is geen verdict.
- Verbind aan échte antwoorden + échte codebase, niet aan abstracte principes.
- Hangt de juiste keuze écht af van iets dat alleen de gebruiker weet ("ga je dit over 6 maanden uitbreiden?"): benoem die fork, geef conditioneel advies.
- 1-plan modus: het verdict is een korte verantwoording (2-3 zinnen) waarom dit plan het juiste is — geen vergelijking.

Sluit het verdict-block af met één regel: *"Zeg welk plan je kiest (of 'ok' voor de aanbeveling) — dan leg ik het vast als contract."* Dit is de overgang naar Step 5; render géén `AskUserQuestion` — de plain-text keuze van de gebruiker is genoeg.

## Step 5 — Contract vastleggen (na de plan-keuze)

Plan gekozen (of "ok" op de aanbeveling) → schrijf één licht contract (`Write`) naar **`.claude/plan-contracts/<slug>.md`**. Mini-variant van mission-plan's validation-contract, zonder scripts of subagents. Slug: kebab-case uit het doel ("CSV-import toevoegen" → `csv-import`).

**Nooit stil overschrijven.** Bestaat `<slug>.md` al: kies het laagste getal N ≥ 2 waarvoor `<slug>-N.md` nog niet bestaat (`ls .claude/plan-contracts/<slug>*.md`), schrijf daarheen, meld het gekozen pad in de chat.

**Basis-commit vastleggen.** Vóór het schrijven: `rtk git rev-parse --short HEAD` → als "Basis-commit" in het contract — het deterministische nulpunt waar de check-modus de diff later tegen toetst.

Contract-inhoud (in de taal van de gebruiker):

```markdown
# Plan-contract: <titel>

Basis-commit: <sha>  ·  Vastgelegd: <datum>

## In één oogopslag
<max 3 zinnen: wat gebouwd wordt en hoe je ziet dat het af is>

## Definition of Done
<de gepinde DoD verbatim — inclusief elke bewijsregel "— bewijs: <commando> → <observatie>">

## Gekozen plan: <naam>
<TL;DR van het gekozen plan>

**Wijzigingen**

| File | Change | Reason |
|------|--------|--------|
| ... | nieuw/gewijzigd/verwijderd | ... |


## Style

- **Schrijf afkortingen uit bij eerste gebruik** (DoD = Definition of Done, enz.). De lezer is een mens die het plan aan een collega moet kunnen uitleggen.
- Match de gebruiker's taal (NL/EN); houd file-paths en code-identifiers exact.