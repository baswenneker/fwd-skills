---
name: fwd:plan
description: Plan een implementatie — verzamel codebase-context, presenteer eerst een DoD-voorstel met numbered bullets (akkoord of corrigeer in plain text, géén AskUserQuestion), stel daarna 0-3 verdiepende keuzes via AskUserQuestion, en presenteer 1 of 3 plannen in visueel distincte boxen met spec-strip + TL;DR + Wijzigingen-tabel. Sluit altijd af met (Recommended)-tag op het beste plan en een verdict-block met onderbouwing. Use when user wants to plan a feature, refactor, or change met meerdere opties op tafel, of invokes /fwd:plan.
argument-hint: <wat te plannen, of leeg om te vragen>
allowed-tools: Read, Glob, Grep, Bash, WebFetch, WebSearch, AskUserQuestion, Agent
---

# Plan

Vier stappen: investigate → clarify → present → verdict (op commando).

**Hard constraints:**

- **`AskUserQuestion` is toegestaan en gewenst** voor alle numbered-choice vragen in 2b/2c. De DoD in 2a is **géén `AskUserQuestion`** maar een plain-text voorstel met numbered bullets — gebruiker bevestigt met "ok" of geeft aanpassingen aan. Render de DoD-bullets en stop de turn; vuur de `AskUserQuestion`-bundle van 2b/2c pas af **nadat** de gebruiker akkoord heeft gegeven.
- **Subagents alleen als de gebruiker er expliciet om vraagt.** Default: blijf in main turn — subagents kunnen geen vervolgvragen stellen en verstoppen context. Bij "use subagents" / "spawn agents to research X" of vergelijkbaar mag `Agent`. Anders zelf doen.
- **Geen code-wijzigingen.** Skill eindigt met aanbeveling; implementatie is een aparte stap.

## Step 1 — Gather context

Lees genoeg om te plannen, niet om te implementeren. Tools: `Read`, `Glob`, `Grep`, `Bash` (read-only), `WebFetch`, `WebSearch`.

1. Herformuleer het verzoek in eigen woorden — wat verandert er werkelijk?
2. 2-4 gerichte Glob/Grep zoekacties op termen uit het verzoek.
3. Lees 2-4 sleutel-bestanden om bestaande patronen te leren (naming, structuur, conventies).
4. Skim `CLAUDE.md`, `CONTEXT.md`, eventuele `docs/adr/` ADRs, **en alle rule-bestanden onder `.claude/rules/`** (architecture, structure, conventions, stack, testing, `guidelines-<lang>`). Deze dicteren de conventies die elk plan moet respecteren — comments, docstrings, typing, naming, testing patterns.
5. Bij library/framework: zoek actuele docs op (Context7 MCP indien beschikbaar, anders WebSearch).
6. Vorm tijdens het lezen een beeld van de scope — dit voedt de gebruiker's keuze (in continue-check) tussen 1 en 3 plannen, maar bepaalt het niet.

Houd het licht — genoeg om te plannen, niet om te implementeren.

## Step 2 — Vragen

**Doel:** scherp krijgen wat onhelder is, niet padding. Eerst de DoD vastpinnen (2a, voorstel in een box), dan 0-3 inhoudelijke keuzes + continue-check (2b/2c). Gedreven door échte ambiguïteit uit Step 1.

### 2a — Definition of Done (propose & pin, vóór de vragen)

Render eerst — vóór elke `AskUserQuestion` — een **confident voorstel** voor de DoD, gebouwd uit échte vondsten in Step 1 (issue-tekst, bestaande tests, contracten). Geen open vraag, geen hedging ("ik vermoed", "denk ik").

Format — numbered bullets, géén box-drawing, géén `AskUserQuestion`:

```
Definition of Done (DoD) — voorstel:

1. <observeerbaar gedrag, test of contract #1>
2. <criterium #2>
3. <criterium #3>

Ok of geef aan wat je aan wil passen.
```

**Stop de turn na het renderen van de bullets.** Wacht op de plain-text reactie van de gebruiker (ok / correctie) vóórdat je de `AskUserQuestion`-bundle van 2b/2c aanroept. Bundel DoD en `AskUserQuestion` niet in dezelfde turn — dat blokkeert de gebruiker (DoD-akkoord botst met openstaande radio-buttons).

Regels:

- 2-5 criteria. Concreet en observeerbaar (gedrag, tests, contracten). Geen vage doelen.
- Bouw uit échte Step 1-vondsten. Verzin geen criteria.
- Bij correctie: render de aangepaste DoD opnieuw als numbered bullets, dán door naar 2b.
- Als Step 1 te dun was om iets te voorstellen: zeg dat expliciet ("ik mis context X om de DoD scherp te krijgen — kun je Y wijzen?") en wacht. Niet bluffen.

### 2b — Numbered-choice vragen (via één `AskUserQuestion` bundle)

Alleen voor échte ambiguïteit. Skip vragen waarvan het antwoord het plan niet zou veranderen.

- **0-3 inhoudelijke vragen.** Niet padden — als er niets onduidelijk is, geen inhoudelijke vragen.
- Gebruik **één enkele `AskUserQuestion` call** met meerdere `questions` items in de bundle, niet meerdere losse calls.
- De **continue-check (zie 2c)** wordt het laatste item in dezelfde bundle.

### 2c — Continue-check (verplicht slot van de bundle)

Het laatste item in de `AskUserQuestion` bundle is altijd:

```
question: "Hoe verder?"
header:   "Volgende stap"
options:
  - label: "Plan met 3 alternatieven (Recommended)"
    description: "Drie distincte plannen + aanbeveling"
  - label: "Plan met 1 enkelvoudig"
    description: "Alleen het meest passende plan"
  - label: "Eerst /fwd:grill-me draaien"
    description: "Skill stopt; gebruiker kan grill-me invoken voor diepere stress-test"
  - label: "Nog een ronde vragen"
    description: "Step 2 herhaalt met nieuwe vragen"
```

Op basis van de keuze:

- **Plan met 3** → Step 3 in 3-plan modus.
- **Plan met 1** → Step 3 in 1-plan modus.
- **Eerst /fwd:grill-me** → skill stopt met:
  > "Type `/fwd:grill-me` voor een diepere stress-test. Roep daarna `/fwd:plan` opnieuw aan met de aangescherpte context."
- **Nog een ronde vragen** → herhaal Step 2 met nieuwe ambiguïteiten. Maximaal nog één extra ronde; daarna forceer een keuze tussen "Plan met 3" of "Plan met 1".

## Step 3 — Plannen

Output-volgorde in één response:

1. **The Question** — 1 regel die het echte probleem framet (niet de artefact-vraag).
2. **Mental Model** — kies adaptief de vorm die het hardst landt voor deze content:
   - *ASCII-diagram* — voor structurele content (call graph, architectuur, request lifecycle). 8-15 regels max, `┌─┐│└─┘ → ↓ ─→`, geen decoratie.
   - *Analogie* — voor abstracte concepten ("denk aan dit als X"). 2-4 regels, brug naar bekend domein.
   - *Before/after* — voor refactor of migratie. 2-4 regels, oude shape → nieuwe shape.
   - *Causal narrative* — voor bug of degradatie. 2-4 regels, X → Y → crash.
   - *First principles* — als geen van bovenstaande past. 1-2 zinnen die de essentie vatten.

   Als geen vorm landt: schrijf `no model added — <reden>` en ga door. Forceer geen vorm.

3. **Plan-blokken** — 1 of 3 onder elkaar (volgens 2c keuze). Volgorde in 3-plan modus: Minimal → Uitgebreid → Pragmatisch.
4. **Verdict-block** — altijd direct na de plan-blokken (zie Step 4). Geen `verdict` commando nodig; de afweging staat standaard onderaan.

### Plan-blok shape (per plan)

Gebruik box-drawing characters voor visuele differentiatie:

```
╭─ Plan A — Minimal ────────────────────╮
│ Files: 5 │ Risk: low │ Effort: 1d     │
╰───────────────────────────────────────╯

**TL;DR:** [één zin: wat doet dit plan, en wat maakt 't 'minimaal'.]

**Details**
- [3-6 concrete bullets: wat verandert, wat hergebruikt wordt, key decisions]
- **Tests:** [niveau — unit/integration/E2E — wat gedekt, waar de testbestanden staan, hoe het de DoD afdekt]
- **Regels:** Toepasselijke regels uit `.claude/rules/` worden op elk gewijzigd bestand toegepast.

**Wijzigingen**

| File | Change | Reason |
|------|--------|--------|
| `path/to/feature.ts` | nieuw | [waarom toegevoegd] |
| `path/to/other.ts` | gewijzigd | [wat verandert] |
| `path/to/feature.test.ts` | nieuw | [tests voor welk gedrag] |
```

Het aanbevolen plan krijgt `(Recommended)` direct in de header, tussen plan-naam en de sluitende rand van de box:

```
╭─ Plan B — Uitgebreid (Recommended) ───╮
│ Files: 8 │ Risk: medium │ Effort: 3d  │
╰───────────────────────────────────────╯
```

### De drie plannen (3-plan modus)

Maak drie plannen met distincte trade-offs:

- **Minimal** — kleinste wijziging. Hergebruik bestaande code; geen nieuwe abstracties. Lage risk, kleine diff.
- **Uitgebreid (extensive)** — architectonisch ideaal. Nieuwe abstracties waar het loont; schone scheiding; testbaar. De "doe het goed" versie.
- **Pragmatisch (pragmatic)** — middenweg. Investeer waar het rendement levert, neem shortcuts waar de cost laag is.

### Hard regels per plan

- Alleen bestaande paden uit Step 1; geen verzonnen bestanden.
- `Change` kolom is één van: `nieuw` / `gewijzigd` / `verwijderd`.
- Spec-strip op één regel binnen de box: `Files: <N> │ Risk: <low|medium|high> │ Effort: <ruwe schatting in uur of dagen>`.
- Elk plan staat op zichzelf — gebruiker moet één plan in isolatie kunnen lezen en begrijpen.

### 1-plan modus

In 1-plan modus: één plan-blok zonder `(Recommended)`-tag (er is geen alternatief). Ga direct van Mental Model naar het plan, sluit met de aanbeveling-regel voor 1-plan modus.

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
- Als de juiste keuze écht afhangt van iets dat alleen de gebruiker weet ("ga je dit over 6 maanden uitbreiden?"), benoem die fork en geef een conditioneel advies.

In 1-plan modus: verdict-block is een korte verantwoording (2-3 zinnen) waarom dit plan het juiste is — geen vergelijking.

## Style

- Plain language. Geen filler.
- **Schrijf afkortingen uit bij eerste gebruik** (DoD = Definition of Done, enz.). De lezer is een mens die het plan aan een collega moet kunnen uitleggen.
- Match de gebruiker's taal (NL/EN); houd file-paths en code-identifiers exact.
- Na het verdict-block: **stop**. Niet implementeren; wacht op de volgende stap van de gebruiker.
