---
name: fwd:steps-plan
description: Plan een klus als een reeks kleine, toetsbare stappen voor attended uitvoering met /fwd:steps-run — de lichte tegenhanger van fwd:mission-plan. Scope het doel kort, pin een Definition of Done mét concreet eindbeeld (input→output-voorbeeld of ASCII-mockup), spreek de testplekken (seams) af, en lever een genummerde stappenlijst waarin elke stap één aantoonbaar gedrag is met een machinaal toetsbaar klaar-criterium. Use when the user zegt "plan dit in stappen", "maak een stappenplan", "steps-plan", of invokes /fwd:steps-plan. Niet voor onbeheerd/overnight werk — dat is fwd:mission-plan.
argument-hint: <het doel, of leeg om interactief te scopen>
allowed-tools: Read, Glob, Grep, Bash, WebFetch, WebSearch, AskUserQuestion, Write
---

# fwd:steps-plan

Zet een doel om in een **stappenplan**: een Definition of Done (DoD) met eindbeeld, afgesproken seams, en een geordende lijst kleine stappen — vastgelegd in `.claude/steps/<slug>/` op een eigen `steps/<slug>`-branch, klaar voor `/fwd:steps-run`. (De uitvoering verhuist bij `/fwd:steps-run` naar een worktree, zodat je hoofd-checkout vrij blijft voor parallel werk; plannen doe je gewoon in je huidige checkout.)

Dit is de **attended** planner: de gebruiker zit erbij en blijft er tijdens de uitvoering bij (één review-moment per stap). Voor onbeheerd werk bestaat `fwd:mission-plan`; voor het afwegen van plan-alternatieven vóór een richtingkeuze bestaat `fwd:plan` — deze skill begint pas als de richting gekozen is.

**Interactief, maar zonder ceremonie.** `AskUserQuestion` mag voor discrete keuzes, maar stel alleen vragen bij échte ambiguïteit — geen vaste vragenronde. Elke vraag is zelfstandig leesbaar: benoem wat hij raakt, waarom het uitmaakt, en per optie wat die in gewone taal betekent.

**Geen productcode.** Deze skill schrijft alleen `plan.md` en `state.json`. Implementeren doet `/fwd:steps-run`.

## Regelsinventaris (sessiestart)

De beschikbare `.claude/rules/` worden bij het laden van de skill automatisch geïnjecteerd:

!`bash "${CLAUDE_SKILL_DIR}/scripts/list-rules.sh"`

Meldt de inventaris **geen regels**, stel dan één bewuste keuze voor (`AskUserQuestion`): (a) eerst `/fwd:rules-audit` draaien — aanbevolen, want de reviewer toetst straks per stap tegen deze regels; of (b) expliciet zonder regels verder (vastleggen in `plan.md`). Stilzwijgend doorgaan is geen optie.

## Flow

### 1. Context (licht)

Lees genoeg om te plannen, niet om te implementeren. Herformuleer het doel in eigen woorden. Dan: 2-4 gerichte `Glob`/`Grep`-zoekacties, 2-4 sleutelbestanden lezen (naming, structuur, testconventies), `CLAUDE.md`/`CONTEXT.md`/rules skimmen. Bij libraries: actuele docs (Context7 MCP of `WebSearch`).

### 2. DoD + eindbeeld-anker (plain text, dan stoppen)

Presenteer een zeker voorstel — geen hedging — als numbered bullets:

1. **DoD**: 2-5 observeerbare criteria (gedrag, tests, contracten), gebouwd uit échte stap-1-vondsten.
2. **Eindbeeld** (verplicht): voor CLI/API-werk een letterlijk input→output-voorbeeld; voor UI-werk een ASCII-mockup of verwijzing naar een referentiescreenshot. Smaak-eisen ("oogt strak") mogen alleen bestaan als ze naar dit anker verwijzen.

Sluit af met "Ok of geef aan wat je aan wil passen." en **stop de turn**. Bij correctie: opnieuw renderen, dan pas door.

### 3. Seams + stappenlijst (plain text, dan stoppen)

Eén gecombineerd voorstel:

**Seams** — de publieke interfaces waarop de tests gaan mikken (functie-/endpoint-/CLI-niveau). Tests komen alléén op afgesproken seams; nooit op interne details.

**Stappenlijst** — genummerd (`S1`, `S2`, …), per stap:
- **Titel + gedrag**: één klein, aantoonbaar gedrag ("na deze stap kan het systeem X").
- **Klaar-criterium**: de test(s) die het gedrag bewijzen (1-3, op een afgesproken seam), óf — alleen als unit-testen echt niet kan (config, wiring, cosmetiek) — een draaibaar commando met verwacht resultaat, expliciet gemarkeerd.
- **Regels**: de rule-bestanden waarvan de `paths:`-globs de verwachte bestanden van deze stap raken (een regelbestand zonder `paths:` is repo-breed en geldt altijd).

Korrel: 1 gedrag ≈ 1-3 tests ≈ een diff die in ±5 minuten te reviewen is. Middelgrote klus ≈ 10-25 stappen. Volgorde = bouwvolgorde: elke stap bouwt voort op de vorige (tracer bullets), afhankelijkheden staan eerder in de lijst.

Draai vóór het tonen de **zelf-lint** en verwerk de uitkomst stilzwijgend (meld alleen wat je erdoor hebt aangepast):

- Is elk klaar-criterium machinaal toetsbaar? Géén criteria die een handmatige UI-klik of menselijk smaakoordeel vereisen.
- Verdient elke stap zijn bestaansrecht (Lazy Ladder trede 1: moet dit bestaan?) — stappen die samen kleiner en begrijpelijker zijn dan apart: samenvoegen.
- Dekt de lijst de hele DoD, en raakt elke test alleen afgesproken seams?

Laat de gebruiker in plain text herordenen, splitsen of schrappen.

### 4. Gate-commando

```
bash "${CLAUDE_SKILL_DIR}/scripts/discover-gates.sh"
```

Print een JSON-array van oplosbare gates (test/typecheck/lint/build). Kies het testcommando als **gate**; stel voor om lint/typecheck erbij te ketenen als het project die heeft (`npm test && npm run lint`). Bevestig in plain text of neem het mee in het stappenlijst-voorstel van stap 3 — geen aparte beurt als het antwoord voorspelbaar is. Geen enkele gate vindbaar → dat is een blokkerende vraag aan de gebruiker: zonder draaibare tests kan steps-run geen bewijs leveren.

### 5. Materialiseren (na plain-text akkoord)

```
bash "${CLAUDE_SKILL_DIR}/scripts/init-steps.sh" <slug>
```

Slug: kebab-case uit het doel, ≤50 tekens. Het script takt **altijd** een eigen `steps/<slug>`-branch af van je huidige branch (die wordt de `base`), scaffoldt `.claude/steps/<slug>/` in de huidige checkout (nog géén worktree — die maakt `/fwd:steps-run` straks van deze branch) en print `branch=`, `base=`, `dir=`. Base ≠ branch is met opzet: run zet je hoofd-checkout terug op `base` en geeft `steps/<slug>` aan een worktree.

Schrijf dan met `Write` in die dir:

- **`plan.md`** — leesbaar voor mensen, volgens het template hieronder.
- **`state.json`** — machine-state, volgens het schema hieronder. Sanity-check na het schrijven: `jq -e '.steps | length > 0' <dir>/state.json`.

Commit beide (alleen deze twee bestanden):

```
rtk git add .claude/steps/<slug> && rtk git commit -m "chore(steps): plan <slug> (<M> stappen)"
```

Sluit af met exact deze regels:

> Stappenplan staat op branch `<branch>`: **<M> stappen**.
> Start met: `/fwd:steps-run <slug>`

## Templates

### plan.md

```markdown
# Stappenplan: <titel>

*Doel: <één zin>. Branch: `<branch>`. Gate: `<gate-commando>`.*

## Definition of Done
1. <criterium>

## Eindbeeld
<letterlijk input→output-voorbeeld of ASCII-mockup>

## Seams (testplekken)
- `<publieke interface>` — <wat hier getest wordt>

## Stappen
- [ ] S1 — <titel>: <gedrag>. Klaar als: <test(s) | commando → verwacht>. Regels: <paden | geen>
- [ ] S2 — …
```

### state.json (schema v1)

```json
{
  "version": 1,
  "slug": "<slug>",
  "title": "<titel>",
  "status": "planned",
  "branch": "<branch>",
  "base_branch": "<base>",
  "created_at": "<UTC ISO-8601>",
  "completed_at": null,
  "gate_command": "<commando>",
  "seams": ["<interface>"],
  "steps": [
    {
      "id": "S1",
      "title": "<titel>",
      "behavior": "<het gedrag in één zin>",
      "done_criterion": { "type": "test", "value": "<testnaam of -bestand>" },
      "rule_paths": [".claude/rules/<x>.md"],
      "status": "todo",
      "approved_at": null,
      "deferrals": []
    }
  ]
}
```

`done_criterion.type` is `"test"` of `"command"`; bij `"command"` komt er een `"expected"`-veld bij met het verwachte resultaat. `status` per stap: `todo` | `done` | `skipped`. `deferrals` vult steps-run bij akkoord (bewust-uitgesteld-lijst: `{"note": "...", "when": "..."}`). Er is bewust geen los voortgangsveld: "huidige stap" is altijd *de eerste stap met status `todo`* — afgeleide waarheid kan niet liegen.

## Stijl

- Nederlands, technische termen Engels; schrijf afkortingen uit bij eerste gebruik (DoD = Definition of Done).
- Voorstellen zijn confident en gebouwd op échte vondsten — was stap 1 te dun, zeg dan wélke context mist en wacht. Niet bluffen.
- Na de afsluitregels: **stop**. Niet implementeren, niet alvast stap S1 beginnen.
