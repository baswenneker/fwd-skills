---
name: fwd:steps-plan
description: Plan een klus als een reeks kleine, toetsbare stappen voor attended uitvoering met /fwd:steps-run — de lichte tegenhanger van fwd:mission-plan. Scope het doel kort, pin een Definition of Done mét concreet eindbeeld (input→output-voorbeeld of ASCII-mockup), spreek de testplekken (seams) af, en lever een genummerde stappenlijst binnen een stappenbudget — een getal als eerste argument-token = precies zoveel stappen (gate-momenten), `auto` = fijnmazig met één aantoonbaar gedrag per stap, default 3; een stap bundelt dan meerdere gedragingen, elk met een machinaal toetsbaar klaar-criterium. Use when the user zegt "plan dit in stappen", "maak een stappenplan", "steps-plan", of invokes /fwd:steps-plan. Niet voor onbeheerd/overnight werk — dat is fwd:mission-plan.
argument-hint: "[<N>|auto] <het doel, of leeg om interactief te scopen>"
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

Meldt de inventaris **geen regels**, stel dan één bewuste keuze voor (`AskUserQuestion`): (a) eerst `/fwd:rules-audit` draaien — aanbevolen, want de reviewer toetst straks per stap tegen deze regels; of (b) expliciet zonder regels verder — leg dat vast als één cursieve regel direct onder de headerregel van `plan.md` (*Regels: bewust zonder — geen `.claude/rules/` aanwezig.*). Stilzwijgend doorgaan is geen optie.

## Flow

### 0. Stappenbudget (parse, nooit vragen)

Budget = aantal **gate-momenten**, niet aantal gedragingen. Per stap één keer: stap-rapport, verse reviewer, gate, commit. Binnen een stap meerdere gedragingen mogelijk; rood→groen blijft per gedraging (steps-run).

Bepaal het budget in deze volgorde — nooit interactief ernaar vragen:

1. Eerste token van het argument is een geheel getal of `auto` → dat is het budget; de rest is het doel.
2. Anders: expliciet aantal in de doeltekst ("in 5 stappen" → 5; "bepaal zelf" / "jij bepaalt" → `auto`).
3. Anders: **3** (default — fundament / kern / afronding).

`auto` = fijnmazig: één gedraging per stap, de 10-25-korrel uit stap 3. `1` = alles in één keer, één gate-moment. Ongeldig getal (0, negatief) → behandelen als afwezig (default 3) en dat in één zin melden.

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

**Stappenlijst** — de kop vermeldt budget + herkomst, bijv. `Stappenlijst (budget: 3 — default; zeg 'auto' voor fijnmazig)` of `(budget: 5 — argument)`. Genummerd (`S1`, `S2`, …), per stap:
- **Titel + deelresultaat**: wat er na deze stap aantoonbaar bij kan, in één zin.
- **Gedragingen**: de aantoonbare gedragingen die de stap bundelt — bij meer dan één als ingesprongen sub-bullets (template hieronder), elk met eigen bewijs. Bij `auto` één gedraging per stap, geen sub-bullets nodig.
- **Klaar-criterium**: per gedraging de test(s) die het bewijzen (1-3, op een afgesproken seam), óf — alleen als unit-testen echt niet kan (config, wiring, cosmetiek) — een draaibaar commando met verwacht resultaat, expliciet gemarkeerd.
- **Regels**: de rule-bestanden waarvan de `paths:`-globs de verwachte bestanden van deze stap raken (een regelbestand zonder `paths:` is repo-breed en geldt altijd).

Snijden: verdeel op bouwvolgorde (tracer bullets — elke stap bouwt voort op de vorige, afhankelijkheden eerder in de lijst) over precies het budget; default 3 ≈ fundament / kern / afronding. Bij `auto`: 1 gedrag ≈ 1-3 tests ≈ een diff die in ±5 minuten te reviewen is; middelgrote klus ≈ 10-25 stappen. Bij een vast budget schaalt de review-inspanning per gate mee met de bundel — dat is de afspraak die de gebruiker met het getal maakt.

**Tegenvoorstel, nooit stille wijziging.** Plan op het budget. Duidelijke mismatch (triviale klus die het budget opvult, forse klus die erin geperst wordt) → één zin tegenvoorstel bij dit voorstel; het getoonde plan volgt het gevraagde budget. De gebruiker beslist.

Draai vóór het tonen de **zelf-lint** en verwerk de uitkomst stilzwijgend (meld alleen wat je erdoor hebt aangepast — het stappen-aantal wijzigt de lint nooit stilzwijgend):

- Is elk klaar-criterium machinaal toetsbaar? Géén criteria die een handmatige UI-klik of menselijk smaakoordeel vereisen.
- Verdient elke gedraging haar bestaansrecht (Lazy Ladder trede 1: moet dit bestaan?) — speculatieve gedragingen schrappen; bij `auto` bovendien: stappen die samen kleiner en begrijpelijker zijn dan apart → samenvoegen.
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

Sluit af met exact deze regels (enkelvoud bij M=1: schrijf `1 stap`, nooit `1 stappen` — geldt ook voor de commit message hierboven):

> Stappenplan staat op branch `<branch>`: **<M> stappen**.
> Start met: `/fwd:steps-run <slug>`

## Templates

### plan.md

```markdown
# Stappenplan: <titel>

*Doel: <één zin>. Branch: `<branch>`. Gate: `<gate-commando>`. Stappenbudget: <bijv. "3 (default)", "5" of "auto">.*

## Definition of Done
1. <criterium>

## Eindbeeld
<letterlijk input→output-voorbeeld of ASCII-mockup>

## Seams (testplekken)
- `<publieke interface>` — <wat hier getest wordt>

## Stappen
- [ ] S1 — <titel>: <deelresultaat in één zin>. Klaar als: <test(s) | commando → verwacht>. Regels: <paden | geen>
  - <gedrag A> → <test a>
  - <gedrag B> → <commando → verwacht>
- [ ] S2 — …
```

De checkbox-regel blijft **één regel** — steps-run's `record-step.sh` vinkt hem machinaal af. Gedragingen van een bundel als ingesprongen sub-bullets zónder checkbox, elk `<gedrag> → <bewijs>`. Eén gedraging (zoals bij `auto`) → geen sub-bullets.

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
      "approved_mode": "attended",
      "deferrals": []
    }
  ]
}
```

`done_criterion.type` is `"test"` of `"command"`; bij `"command"` komt er een `"expected"`-veld bij met het verwachte resultaat. `status` per stap: `todo` | `done` | `skipped`. `approved_mode` (`attended` | `autonomous`, default `attended`) legt vast hoe de stap is goedgekeurd — steps-run kent naast het per-stap `ok` ook een autonome `auto`-afronding die alle resterende stappen zonder tussenstops afmaakt en pas na één eindreview commit. `deferrals` vult steps-run bij akkoord (bewust-uitgesteld-lijst: `{"note": "...", "when": "..."}`). Er is bewust geen los voortgangsveld: "huidige stap" is altijd *de eerste stap met status `todo`* — afgeleide waarheid kan niet liegen. Een gebundelde stap met gemengd bewijs (tests én commando's) houdt `done_criterion.type: "test"`; `value` benoemt dan ook de command-bewezen delen, en de sub-bullets in plan.md dragen per gedraging het precieze bewijs. steps-run's rood-overslaan bij commando-bewijs geldt per gedraging, niet per stap.

## Stijl

- Nederlands, technische termen Engels; schrijf afkortingen uit bij eerste gebruik (DoD = Definition of Done).
- Voorstellen zijn confident en gebouwd op échte vondsten — was stap 1 te dun, zeg dan wélke context mist en wacht. Niet bluffen.
- Na de afsluitregels: **stop**. Niet implementeren, niet alvast stap S1 beginnen.
