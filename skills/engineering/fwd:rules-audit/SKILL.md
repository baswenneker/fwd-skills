---
name: fwd:rules-audit
description: Interactief de `.claude/rules/` directory bootstrappen voor een repo. De skill scant de codebase, stelt regelbestanden voor — elk voorzien van minimaal één golden example (een pad naar een echt, exemplarisch bestand) — en schrijft pas weg na expliciete goedkeuring van de gebruiker. Gebruik bij "rules audit", "bootstrap rules", "stel regels op", "maak claude rules", of als je `/fwd:rules-audit` aanroept.
argument-hint: <optioneel: focus-gebied, bijv. "typescript" of "testing">
allowed-tools: Read, Glob, Grep, AskUserQuestion, Write
---

# fwd:rules-audit

Bootstrap de `.claude/rules/` directory interactief: scan de codebase, stel regelbestanden voor met concrete voorbeelden, en schrijf pas na akkoord.

**Wat dit doet:** codebase scannen → per conventie een regel voorstellen met minimaal één golden example → de gebruiker laten goedkeuren → pas dan wegschrijven naar `.claude/rules/`.

**Wat dit NIET doet:** regels automatisch wegschrijven zonder goedkeuring, bestanden buiten `.claude/rules/` aanmaken, of meer dan één regelbestand per conventie produceren.

**Golden example:** een concreet bestand in de repo dat de conventie goed toepast. Dient als bewijs dat de regel gebaseerd is op echte patronen, niet op aannames.

## Quick start

```
/fwd:rules-audit
# → scan → voorstel met golden examples → akkoord → .claude/rules/*.md
```

## Flow

### 1. Scan de codebase

Lees genoeg om de dominante conventies te herkennen. Gebruik `Glob` en `Grep` — lees geen bestanden integraal tenzij nodig.

Wat te zoeken:

- **Structuur** — mapindeling, naamgeving van bestanden en mappen, categorisering.
- **Code-stijl** — imports, exports, typing, docstrings, commentaar-dichtheid.
- **Test-patronen** — locatie van tests, naming van test-suites en -cases, fixtures.
- **Git-conventies** — commit-message format, branchnaming (als `CLAUDE.md` of een `.gitmessage` aanwezig is).
- **Bestaande documentatie** — `CLAUDE.md`, `CONTEXT.md`, `README.md`, eventuele `docs/adr/`.

Als een argument is meegegeven (bijv. `typescript`), beperk de scan dan tot dat domein.

Sluit de scan af met een mentale lijst van 3-8 herkenbare conventies die de moeite waard zijn om vast te leggen.

### 2. Stel regels voor

Bouw per gevonden conventie een concept-regel. Toon alle concept-regels in één overzicht:

```
## Concept-regels

### R1 — <korte naam>
**Scope:** repo-breed / <glob>
**Golden example:** `<pad/naar/bestand>`
**Regel (samenvatting):** <wat de regel zegt in 1-2 zinnen>

### R2 — <korte naam>
...
```

Regels voor de voorstelfase:

- Elke regel heeft minimaal één golden example: een bestaand bestand in de repo dat de conventie correct toepast. Geen verzonnen paden.
- Als een conventie alleen voor een deel van de repo geldt (bijv. alleen `src/` of alleen `*.test.ts`), vermeld dan de bijbehorende glob als scope.
- Repo-brede regels hebben geen scope.
- Houd de samenvatting bondig: de gebruiker beoordeelt hier of de regel klopt, niet de precieze formulering.

### 3. Vraag akkoord

Gebruik `AskUserQuestion` om het voorstel goed te laten keuren:

```
Welke regels wil je wegschrijven naar .claude/rules/?
```

Bied de volgende opties aan:

- **Alles akkoord** — schrijf alle concept-regels weg.
- **Selectie** — gebruiker geeft aan welke regelnummers (bijv. "R1, R3") goedgekeurd zijn; de rest wordt overgeslagen.
- **Aanpassen** — gebruiker geeft wijzigingen aan in plain text; pas aan en toon het aangepaste voorstel opnieuw. Vraag daarna opnieuw om akkoord (maximaal één extra ronde).
- **Annuleer** — stop zonder iets weg te schrijven.

Op "annuleer" of afwezigheid van akkoord: stop. Bevestig dat er niets is geschreven.

### 4. Schrijf de regelbestanden weg

Na akkoord: schrijf één markdown-bestand per goedgekeurde regel naar `.claude/rules/`.

**Format van elk regelbestand:**

```markdown
---
description: <één zin: wat de regel bewaakt>
paths:
  - "<glob>"
---

# <Naam van de conventie>

<2-4 zinnen: wat de conventie is en waarom die bestaat.>

## Voorschrift

<Concrete, actionable instructies. Gebruik bullets voor meerdere deelregels.>

## Golden example

Zie `<pad/naar/golden-example>` als referentie voor de juiste toepassing.
```

**Grenzen bij het wegschrijven:**

- Het `paths:`-frontmatter wordt alleen opgenomen als de regel partieel is (niet repo-breed). Een repo-brede regel laat `paths:` weg.
- Eén regelbestand per conventie. Geen samengestelde bestanden.
- Maximaal ~200 regels per regelbestand. Als een conventie meer tekst vraagt, splits hem dan op in twee afzonderlijke regels met een eigen focus.
- Bestandsnaam: korte, beschrijvende kebab-case naam, bijv. `commit-messages.md`, `typescript-imports.md`.
- Uitsluitend markdown-bestanden onder `.claude/rules/`. Geen subdirectories, geen andere bestandstypen.

### 5. Rapporteer

Toon na het wegschrijven een bondig overzicht:

```
Weggeschreven naar .claude/rules/:

- commit-messages.md      (repo-breed)
- typescript-imports.md   (src/**/*.ts)
- test-conventions.md     (**/*.test.ts)

Overgeslagen: R2 (op verzoek van gebruiker)
```

## Schrijfstijl

Zie het "Schrijfstijl missions" blok in [CONTEXT.md](../../../CONTEXT.md) voor de stijlregels die gelden voor rapporten en voorstellen die deze skill produceert.

## Boundaries

- **Geen automatisch wegschrijven.** Altijd eerst voorstel tonen en akkoord vragen.
- **Alleen `.claude/rules/`**. De skill schrijft niets buiten die map.
- **Alleen bestaande paden als golden example.** Geen verzonnen of geïnfereerde bestanden.
- **Geen scripts.** De skill gebruikt geen externe bash-scripts — alleen de agent's eigen tools: `Glob`, `Grep`, `Read`, `AskUserQuestion`, `Write`.
- **Geen andere bestanden aanraken.** `CLAUDE.md`, `CONTEXT.md`, `plugin.json` en alle overige projectbestanden blijven ongewijzigd.
