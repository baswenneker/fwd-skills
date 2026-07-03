---
name: fwd:plan
description: Plan een implementatie — verzamel codebase-context, presenteer eerst een DoD-voorstel met numbered bullets (akkoord of corrigeer in plain text, géén AskUserQuestion), stel daarna 0-3 verdiepende keuzes via AskUserQuestion, en presenteer 1 of 3 plannen in visueel distincte boxen met spec-strip + TL;DR + Wijzigingen-tabel. Sluit af met (Recommended)-tag op het beste plan en een verdict-block, en legt na de plan-keuze een licht contract vast in `.claude/plan-contracts/<slug>.md`. `/fwd:plan check [<slug>]` toetst achteraf de diff en de DoD-bewijsregels tegen dat contract. Use when user wants to plan a feature, refactor, or change met meerdere opties op tafel, of invokes /fwd:plan.
argument-hint: "<wat te plannen> — of: check [<slug>] om een contract achteraf te toetsen"
allowed-tools: Read, Glob, Grep, Bash, WebFetch, WebSearch, AskUserQuestion, Agent, Write
---

# Plan

De dialoog met de gebruiker verloopt in drie zichtbare stappen — de flow-regels tonen "stap 1/2/3 van 3": (1) Definition of Done, (2) verdiepende vragen, (3) plan + verdict. Na de plan-keuze legt de skill stil een licht contract vast (Step 5). Losse modus: `/fwd:plan check [<slug>]` toetst een eerder vastgelegd contract achteraf (zie *Check-modus* onderaan).

**Hard constraints:**

- **`AskUserQuestion` is toegestaan en gewenst** voor alle numbered-choice vragen in 2b/2c. De DoD (Definition of Done) in 2a is **géén `AskUserQuestion`** maar een plain-text voorstel met numbered bullets — gebruiker bevestigt met "ok" of geeft aanpassingen aan. Render de DoD-bullets en stop de turn; vuur de `AskUserQuestion`-bundle van 2b/2c pas af **nadat** de gebruiker akkoord heeft gegeven.
- **Subagents alleen als de gebruiker er expliciet om vraagt.** Default: blijf in main turn — subagents kunnen geen vervolgvragen stellen en verstoppen context. Bij "use subagents" / "spawn agents to research X" of vergelijkbaar mag `Agent`. Anders zelf doen.
- **`Write` mag uitsluitend contractbestanden onder `.claude/plan-contracts/` raken** — aanmaken in Step 5, bijwerken (met de toets-uitslag) in de check-modus. Nooit code, nooit een pad daarbuiten. Verder eindigt de skill met een aanbeveling; implementatie is een aparte stap.
- **Roep nooit `ExitPlanMode` aan** — ook niet als de sessie in Claude Code plan mode draait en de harness om plan-goedkeuring vraagt; haal de tool ook niet via `ToolSearch` op. Het DoD-akkoord plus het verdict-block is het énige goedkeuringsmoment van deze skill; een tweede goedkeuring erbovenop laat de sessie stranden op een afgewezen tool-call. Dit geldt de hele skill-run, ook ná het verdict.

## Step 1 — Gather context

Lees genoeg om te plannen, niet om te implementeren. Tools: `Read`, `Glob`, `Grep`, `Bash` (read-only), `WebFetch`, `WebSearch`.

1. Herformuleer het verzoek in eigen woorden — wat verandert er werkelijk?
2. 2-4 gerichte Glob/Grep zoekacties op termen uit het verzoek.
3. Lees 2-4 sleutel-bestanden om bestaande patronen te leren (naming, structuur, conventies).
4. Skim `CLAUDE.md`, `CONTEXT.md`, eventuele `docs/adr/` ADRs, **en alle rule-bestanden onder `.claude/rules/`** (architecture, structure, conventions, stack, testing, `guidelines-<lang>`). Deze dicteren de conventies die elk plan moet respecteren — comments, docstrings, typing, naming, testing patterns.
5. Bij library/framework: zoek actuele docs op (Context7 MCP indien beschikbaar, anders WebSearch).
6. Vorm tijdens het lezen een beeld van de scope. Dit bepaalt wélke continue-check-optie (2c) de `(Recommended)`-tag krijgt — kleine scope (hooguit een paar bestanden, low risk, geen architectuurkeuze) → "Plan met 1"; anders → "Plan met 3". De gebruiker kiest nog steeds zelf; de default is alleen proportioneel.

Houd het licht — genoeg om te plannen, niet om te implementeren.

## Step 2 — Vragen

**Doel:** scherp krijgen wat onhelder is, niet padding. Eerst de DoD vastpinnen (2a, voorstel in een box), dan 0-3 inhoudelijke keuzes + continue-check (2b/2c). Gedreven door échte ambiguïteit uit Step 1.

### 2a — Definition of Done (propose & pin, vóór de vragen)

Render eerst — vóór elke `AskUserQuestion` — een **confident voorstel** voor de DoD, gebouwd uit échte vondsten in Step 1 (issue-tekst, bestaande tests, contracten). Geen open vraag, geen hedging ("ik vermoed", "denk ik").

Format — numbered bullets, géén box-drawing, géén `AskUserQuestion`. Open met de flow-regel zodat de gebruiker altijd ziet waar hij in het proces zit:

```
*fwd:plan — stap 1 van 3: Definition of Done (daarna: vragen → plan + verdict)*

Definition of Done (DoD) — voorstel:

1. <observeerbaar gedrag, test of contract #1>
   — bewijs: `<commando>` → <verwachte observatie>
2. <criterium #2>
   — bewijs: `<commando>` → <verwachte observatie>
3. <faalgedrag: wat gebeurt er bij foute input / ontbrekende data>
   — bewijs: `<commando>` → <verwachte foutmelding of status>

Ok of geef aan wat je aan wil passen.
```

**Stop de turn na het renderen van de bullets.** Wacht op de plain-text reactie van de gebruiker (ok / correctie) vóórdat je de `AskUserQuestion`-bundle van 2b/2c aanroept. Bundel DoD en `AskUserQuestion` niet in dezelfde turn — dat blokkeert de gebruiker (DoD-akkoord botst met openstaande radio-buttons).

Regels:

- 2-5 criteria. Concreet en observeerbaar (gedrag, tests, contracten). Geen vage doelen.
- **Elk criterium krijgt een bewijsregel**: "— bewijs: `<commando>` → `<verwachte observatie>`". Zo is bij oplevering afvinkbaar hoe "werkend" gedemonstreerd wordt. Vereist het bewijs een key of omgeving die er nu niet is, markeer dat expliciet ("— bewijs: **live**, vereist `<X>`"); een geskipte testmarker of gemockt pad telt níet als bewijs voor een criterium dat echt gedrag belooft.
- **Minstens één criterium beschrijft faalgedrag** (foute input, ontbrekende data, error-pad) — niet alleen de bekende weg.
- Bouw uit échte Step 1-vondsten. Verzin geen criteria.
- Bij correctie: render de aangepaste DoD opnieuw als numbered bullets, dán door naar 2b.
- Als Step 1 te dun was om iets te voorstellen: zeg dat expliciet ("ik mis context X om de DoD scherp te krijgen — kun je Y wijzen?") en wacht. Niet bluffen.

### 2b — Numbered-choice vragen (via één `AskUserQuestion` bundle)

Alleen voor échte ambiguïteit. Skip vragen waarvan het antwoord het plan niet zou veranderen.

Render vóór het afvuren van de bundle één flow-regel: `*fwd:plan — stap 2 van 3: verdiepende vragen*`.

- **0-3 inhoudelijke vragen.** Niet padden — als er niets onduidelijk is, geen inhoudelijke vragen.
- Gebruik **één enkele `AskUserQuestion` call** met meerdere `questions` items in de bundle, niet meerdere losse calls.
- De **continue-check (zie 2c)** wordt het laatste item in dezelfde bundle.

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

**Proportionele default.** Zet de `(Recommended)`-tag in het label op de optie die past bij het scope-beeld uit Step 1 (punt 6): op **"Plan met 1 enkelvoudig"** wanneer de scope klein is — richtlijn: hooguit een paar bestanden, low risk, geen architectuurkeuze; anders op **"Plan met 3 alternatieven"**. Geen harde telling (voorbeeldgetallen ankeren — zie LESSONS 2026-06-09), maar een richtlijn. Benoem de reden kort in de option-description van de aangeraden optie (bijv. "scope is klein: 2 bestanden, low risk"). De gebruiker kan altijd alsnog het andere pad kiezen.

Op basis van de keuze:

- **Plan met 3** → Step 3 in 3-plan modus.
- **Plan met 1** → Step 3 in 1-plan modus.
- **Eerst stress-testen** → skill stopt met:
  > "Type `/fwd:grill-me` (vraagverdieping) of `/fwd:premortem` (faalscenario's vooraf) voor een diepere stress-test. Roep daarna `/fwd:plan` opnieuw aan met de aangescherpte context."
- **Nog een ronde vragen** → herhaal Step 2 met nieuwe ambiguïteiten. Maximaal nog één extra ronde; daarna forceer een keuze tussen "Plan met 3" of "Plan met 1".

## Step 3 — Plannen

Open met de flow-regel: `*fwd:plan — stap 3 van 3: plan + verdict*`. Output-volgorde in één response:

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

Het aanbevolen plan krijgt `(Recommended)` direct in de header, tussen plan-naam en de sluitende rand van de box:

```
╭─ Plan B — Uitgebreid (Recommended) ───╮
│ Files: <N> │ Risk: <low|med|high> │ Effort: <uur|dagen> │
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

In 1-plan modus: één plan-blok zonder `(Recommended)`-tag (er is geen alternatief). Ga direct van Mental Model naar het plan, sluit met de aanbeveling-regel voor 1-plan modus. Bij kleine scope mag het Mental Model vervallen (`no model added — scope is klein`) en volstaan 2-3 Details-bullets; DoD, Tests-bullet, Wijzigingen-tabel en verdict blijven verplicht.

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

Sluit het verdict-block af met één regel: *"Zeg welk plan je kiest (of 'ok' voor de aanbeveling) — dan leg ik het vast als contract."* Dit is de overgang naar Step 5; render géén `AskUserQuestion` en géén `ExitPlanMode` — de plain-text keuze van de gebruiker is genoeg.

## Step 5 — Contract vastleggen (na de plan-keuze)

Zodra de gebruiker een plan kiest (of "ok" voor de aanbeveling zegt), schrijf je één licht contract met de `Write`-tool naar **`.claude/plan-contracts/<slug>.md`** en stop je daarna. Dit is de mini-variant van mission-plan's validation-contract — zonder scripts of subagents. De `<slug>` is kebab-case uit het doel (bijv. "CSV-import toevoegen" → `csv-import`).

**Nooit stil overschrijven.** Bestaat `.claude/plan-contracts/<slug>.md` al, kies dan het laagste getal N ≥ 2 waarvoor `<slug>-N.md` nog niet bestaat (loop over de bestaande varianten met `ls .claude/plan-contracts/<slug>*.md`), schrijf daarheen en meld het gekozen pad in de chat.

**Basis-commit vastleggen.** Draai vóór het schrijven `rtk git rev-parse --short HEAD` en zet die SHA in het contract als "Basis-commit". De check-modus toetst de diff later tegen exact dat punt — een deterministisch nulpunt.

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

## Toets na implementatie
Afvinkbare checklist — wie implementeert, vinkt dit af vóór oplevering (of draai `/fwd:plan check <slug>`):
- [ ] De diff sinds de basis-commit raakt precies de bestanden in de Wijzigingen-tabel — afwijkingen benoemd.
- [ ] Per DoD-criterium is de bewijsregel zélf gedraaid en de observatie genoteerd — zelfrapportage en geskipte markers tellen niet.
- [ ] Het faalcriterium is aantoonbaar getest.

Implementatie is een aparte stap; wie implementeert vinkt dit contract af vóór oplevering.
```

**Fallback (plan mode of Write geweigerd).** Kun je niet schrijven, render het contract dan als codeblok in de chat met de instructie: "Sla dit op als `.claude/plan-contracts/<slug>.md`." Roep géén `ExitPlanMode` aan.

Na het schrijven: meld het pad en de basis-commit, en **stop**. Niet implementeren.

## Check-modus — `/fwd:plan check [<slug>]`

Toetst een eerder vastgelegd contract achteraf. **Ingang met disambiguatie** — kaap geen normaal plan-doel dat toevallig met "check" begint (bijv. `check the login flow`):

- Argument is exact `check` (niets erachter) → check-modus, **zonder slug** (lijst-tak hieronder).
- Argument is `check <token>` én `.claude/plan-contracts/<token>.md` (of een `<token>-N.md`-variant) bestaat → check-modus met slug `<token>`.
- In **alle andere** gevallen (`check <token>` waar geen contract voor bestaat, of meer woorden) → dit is een gewoon plan-doel; draai Step 1-5 normaal met het volledige argument als doel.

**Zonder slug** (`/fwd:plan check`): lijst de contracten in `.claude/plan-contracts/` (`ls`) en stop. De gebruiker kiest er één.

**Met slug** (`/fwd:plan check <slug>`): lees het contract. Bestaan er gesuffixte varianten (`<slug>-2.md`, …), kies dan de nieuwste (hoogste N) of vraag de gebruiker welke — toets nooit stilzwijgend het verouderde `<slug>.md` als er een nieuwer contract naast ligt. Toets dan:

1. **Diff-toets.** Bouw de lijst geraakte bestanden uit twee bronnen (rtk vervuilt output — filter dus):
   - Tracked wijzigingen sinds de basis-commit: `rtk git diff --name-only <basis-commit> -- . ':(exclude).claude/plan-contracts' 2>/dev/null | grep -vE '^(ok|Changes:|[[:space:]]*)$'` — de `:(exclude)`-pathspec houdt het contract zelf eruit; de `grep` verwijdert rtk's `ok`-sentinel, de `Changes:`-trailer en lege regels (geen bestanden).
   - Nieuwe (untracked) bestanden: `rtk git status --porcelain --untracked-files=all 2>/dev/null | grep -vx 'ok' | grep '^??' | sed 's/^?? //' | grep -v '^\.claude/plan-contracts/'` — `--untracked-files=all` somt untracked bestanden per stuk op (anders collapst een nieuwe map tot één regel en glipt het contract erdoor).

   Leg de vereniging van beide naast de Wijzigingen-tabel en meld per regel: geraakt-en-verwacht (ok), geraakt-maar-niet-in-tabel (afwijking), in-tabel-maar-niet-geraakt (ontbreekt).
2. **Bewijs-toets.** Draai per DoD-criterium de bewijsregel zélf en noteer de observatie. Een geskipte testmarker of gemockt pad telt níet als bewijs voor een criterium dat echt gedrag belooft. Vereist het bewijs een key/omgeving die er niet is ("live, vereist `<KEY>`"), dan is dat criterium **niet toetsbaar** — niet "gehaald".
3. **Verdict per criterium** — dezelfde drieslag als de mission-verdicts: **gehaald** / **niet gehaald** / **niet toetsbaar** (met reden).
4. **Contract bijwerken** (dit is het tweede schrijf-moment naar hetzelfde contractbestand): voeg onderaan het contract een sectie "Toets-uitslag — `<datum>`" toe met de diff-afwijkingen en het verdict per criterium. Rapporteer hetzelfde in de chat.

**Niet-gehaald = rapporteren, nooit fixen.** Een toetser die repareert, toetst zijn eigen werk. De check-modus wijzigt alleen het contractbestand, nooit code.

## Style

- Plain language. Geen filler.
- **Schrijf afkortingen uit bij eerste gebruik** (DoD = Definition of Done, enz.). De lezer is een mens die het plan aan een collega moet kunnen uitleggen.
- Match de gebruiker's taal (NL/EN); houd file-paths en code-identifiers exact.
- Na Step 5 (contract vastgelegd) of de check-modus: **stop**. Niet implementeren; geen `ExitPlanMode`; wacht op de volgende stap van de gebruiker.
