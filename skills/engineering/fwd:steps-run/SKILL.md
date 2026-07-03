---
name: fwd:steps-run
description: Voer een stappenplan van /fwd:steps-plan uit — attended, precies één stap per beurt. Per stap; falende test eerst (rood), minimale implementatie langs de Lazy Ladder (groen), volledige gate, vers oordeel door een read-only reviewer-subagent, en een stap-rapport van ±15 regels met "Stap N/M"-teller — daarna stopt de beurt en beslist de gebruiker (ok = commit & door, m = meer detail, stop = pauze, vrije tekst = correctie/vraag/planwijziging). Elke 4 goedgekeurde stappen een tussenbalans door twee doubt-subagents. Use when the user runs /fwd:steps-run <slug>, zegt "volgende stap", "ga door met het stappenplan", of "hervat <slug>". Zonder argument: lijst alle stappenplannen. Niet voor onbeheerd werk — dat is fwd:mission-run.
argument-hint: "[<slug>] — zonder argument: lijst alle stappenplannen"
allowed-tools: Read, Glob, Grep, Bash, Edit, Write, Agent
---

# fwd:steps-run

Eén stap per beurt, bewijs vóór uitleg, commit pas na akkoord. **Jij (de hoofdsessie) schrijft de code zélf** — er is geen coder-subagent, zodat de uitleg uit eerste hand komt. Het onafhankelijke oordeel komt per stap van `fwd-skills:fwd-steps-reviewer` (read-only, verse context); de tussenbalans elke 4 stappen van `fwd-skills:fwd-steps-doubt`.

**Attended-principe.** De gebruiker zit erbij en beslist op elk gate-moment.

- **Nooit voorbij het gate-moment bouwen.** Na het stap-rapport stopt de beurt — geen "alvast beginnen" aan de volgende stap.
- **Geen `AskUserQuestion` op gates.** Het gate-protocol is plain text (`ok` / `m` / `stop` / vrije tekst).
- **Nooit pushen, nooit PRs openen.** Committen op de plan-branch gebeurt alleen via `record-step.sh`, na akkoord.
- **Nooit groen faken.** Een test verzwakken, een assert verwijderen of een gate omzeilen om "door te komen" is uitgesloten — vastlopen wordt eerlijk gerapporteerd.

**De bash / Claude / subagent-splitsing:**

- **Bash-scripts** — deterministische state, git, exit codes. Draai ze; vertrouw hun uitvoer.
- **Jij** — code schrijven, tests schrijven, uitleggen, wegen wat de reviewer vindt.
- **Subagents** — het onafhankelijke oordeel. Jij vult het "Review (vers)"-blok nooit zelf in; zonder reviewer-run geen stap-rapport.

## Status (sessiestart)

!`bash "${CLAUDE_SKILL_DIR}/scripts/status.sh" "$ARGUMENTS"`

## Flow

**Zonder slug** — presenteer de lijst hierboven als nette tabel (slug, voortgang, branch, titel) en stop. De gebruiker kiest.

**Met slug** — interpreteer de status-injectie hierboven:

### 0. Preflight

| Signaal | Actie |
|---|---|
| `no-plan` (exit 2) | Meld het; toon de kandidaat-branches uit de uitvoer (`rtk git switch <branch>` om te hervatten). Stop. |
| `corrupt-state` (exit 3) | Meld het; toon het pad. Stop — niet zelf repareren zonder de gebruiker. |
| `branch_mismatch=yes` | Schone working tree → `rtk git switch <branch>` en door. Vuile tree → meld het exacte commando en stop; de gebruiker beslist. |
| `dirty_tree=yes` | Zie *Hervatten met een klaarstaande stap* hieronder. |
| `status=done` | Alles is af — verwijs naar het eindrapport / de merge-keuze en stop. |
| `next=none` | Alle stappen done/skipped maar status niet `done` → draai het eindrapport (stap 6). |

**Hervatten met een klaarstaande stap.** Een vuile working tree bij de start hoort bij precies één scenario: een eerdere sessie bouwde de eerstvolgende `todo`-stap en stopte vóór het akkoord. Check of de `dirty_files` bij die stap passen. Zo ja: her-draai de gate én de reviewer (de tree kan intussen aangeraakt zijn) en toon het stap-rapport opnieuw, gemarkeerd met "(stond al klaar)". Zo nee: meld eerlijk wat er ligt, geef opties (wegcommitten buiten het plan om / stashen / inspecteren) en stop.

### 1. Brief

Lees uit `.claude/steps/<slug>/`: `plan.md` (DoD, eindbeeld, seams) en de stap uit de status-injectie (`next_*`). **Lees élk rule-bestand uit `next_rules` vóór je één regel code schrijft** — regels zijn bindend en vuren niet vanzelf bij nieuwe bestanden.

### 2. Rood

Schrijf de falende test(s) voor het gedrag van deze stap — 1-3 tests, uitsluitend op de in `plan.md` afgesproken seams. Draai ze gericht; **leg de letterlijke falende uitvoer vast** voor het rapport. Testkwaliteit:

- Verwachte waarden komen uit een onafhankelijke bron (de spec, het eindbeeld, een uitgewerkt voorbeeld) — nooit narekenen zoals de productiecode het doet (schijntest).
- Publieke interface, geen interne details — de test overleeft een refactor.
- Alleen de tests van déze stap — geen tests vooruit schrijven voor latere stappen.

Bij `next_criterion_type=command` (vooraf zo gemarkeerd in het plan): sla rood over en noteer dat in het rapport; het bewijs is straks het commando met zijn verwachte resultaat.

### 3. Groen — de ponytail-discipline

Éérst begrijpen, dan pas lui zijn: lees alles wat de stap raakt en trace de echte flow. Klim daarna de **Lazy Ladder** en stop bij de eerste trede die houdt:

1. **Moet dit bestaan?** Speculatieve behoefte → schrappen, meld het in één regel (YAGNI).
2. **Bestaat het al in deze codebase?** Een helper, util, type of patroon een paar bestanden verderop → hergebruiken. Herimplementeren wat er al ligt is de meest voorkomende slop.
3. **Doet de stdlib het?** Gebruik hem.
4. **Dekt een native platformfeature het?** `<input type="date">` boven een picker-library, CSS boven JS, DB-constraint boven app-code.
5. **Lost een al-geïnstalleerde dependency het op?** Gebruik die. Nooit een nieuwe toevoegen voor wat een paar regels kan.
6. **Kan het in één regel?** Eén regel.
7. **Pas dan:** het minimum dat werkt.

Regels bij het klimmen:

- **Bugfix = oorzaak, niet symptoom.** Grep élke aanroeper van de functie die je gaat aanraken. De luie fix ís de oorzaak-fix: één guard in de gedeelde functie is een kleinere diff dan een guard in elke aanroeper.
- **Geen ongevraagde abstracties**: geen interface met één implementatie, geen factory voor één product, geen config voor een waarde die nooit verandert. Geen scaffolding "voor later" — later kan zijn eigen scaffolding bouwen.
- **Saai boven slim.** Slim is wat iemand om 3 uur 's nachts moet ontcijferen. Weghalen boven toevoegen. Zo min mogelijk bestanden; de kortste wérkende diff wint — maar de kleinste wijziging op de verkeerde plek is geen luiheid, dat is een tweede bug.
- **Twee stdlib-opties, even groot?** Pak de op edge-cases correcte. Lui = minder code schrijven, niet het wankelere algoritme kiezen.
- **Bewuste versimpeling → comment mét plafond en upgrade-pad**, op de plek zelf en zelfstandig leesbaar, bijv. `# bewust: globale lock — per-account locks zodra doorvoer knelt`. Registreer hem straks óók als deferral bij het akkoord (`{"note": …, "when": …}`).
- **Safety floor — nooit wegversimpelen:** inputvalidatie op trust boundaries, error handling die dataverlies voorkomt, security, accessibility-basics, en alles wat de gebruiker expliciet vroeg.
- **Comments en commit message zelfstandig leesbaar**: leg wat/waarom uit in gewone taal; nooit stap-nummers, de slug of plan-verwijzingen in code, comments, docstrings of commit messages.

Draai daarna de **volledige gate** (`gate=` uit de injectie) tot alles groen is — niet alleen de nieuwe tests; de gate is de regressiedetectie.

### 4. Vers oordeel

Spawn de reviewer via de Agent tool, `subagent_type: fwd-skills:fwd-steps-reviewer`. De prompt bevat **alleen**: het repo-root-pad, de stap-titel + het gedrag, het klaar-criterium, het gate-commando en de rule-paden. **Niet** de diff, niet je code, niet je redenering — de reviewer trekt alles zelf op (`rtk git diff`); dat bespaart tokens en voorkomt doorvertel-bias.

Verwerk het JSON-verdict:

- `gate.passed=false` → terug naar stap 3; fix, en daarna de reviewer opnieuw.
- `test_quality` of een rule `passed=false` → fixen vóór het rapport (dit zijn geen meningen) — tenzij het oordeel aantoonbaar onjuist is; dan gemotiveerd als open punt in het rapport.
- Over-engineering-vondsten waar je het mee eens bent → direct toepassen, gate opnieuw, in het rapport als "toegepast".
- Vondsten waar je het niet mee eens bent → open in het rapport, met één regel waarom niet.

### 5. Stap-rapport → stop de beurt

Render exact dit sjabloon (±15 regels, Nederlands, technische termen Engels, geen code-snippets — die zitten achter `m`):

```
── Stap <N>/<M> — <titel> ──────────────────────────────

Wat kan er nu:  <het gedrag in 1-2 zinnen gewone taal>

Waarom zo:      <kernkeuze(s); benoem hergebruik; indien van toepassing:
                "bewust simpel gehouden: <wat> — uitbreiden zodra <wanneer>">

Bewijs:         rood  ✗ <letterlijke falende testregel van vóór de implementatie>
                groen ✓ <n> nieuwe test(s); gate <X/X> groen (reviewer herdraaide hem)

Review (vers):  rules <✓ | ✗: wat> · over-engineering: <geen | <n> vondsten, toegepast/open>
                <de narrative-zin van de reviewer>

Bestanden:      <pad> (+<regels>) · <pad> (+<regels>)
Zelf zien:      <één copy-paste commando>

Volgende:       stap <N+1>/<M> — <titel>    (of: dit was de laatste stap)
── ok = commit & door · m = meer detail · stop = pauze · of typ correctie/vraag ──
```

**Stop hier.** De volgende beurt is aan de gebruiker.

### 6. Gate-protocol (de reactie van de gebruiker)

- **`ok` / `y`** — commit en door:

  ```
  echo '{"deferrals":[…]}' | bash "${CLAUDE_SKILL_DIR}/scripts/record-step.sh" <slug> <step-id> "<conventional message>"
  ```

  De message beschrijft het gedrag (`feat(auth): wachtwoord-reset e-mail met 1u-expiry`) — zonder stap-codes. Lees de uitvoer:
  - `interim_review=due` → draai de **tussenbalans** (volgende sectie) en stop de beurt.
  - `status=done` → draai het **eindrapport** (sectie 8) in deze beurt.
  - anders → begin de volgende stap (terug naar stap 1) en eindig bij háár rapport.
- **`m` (more)** — uitgebreide uitleg van dezelfde stap: per bestand de kernwijziging mét snippet, de volledige reviewer-bevindingen, overwogen alternatieven en waarom het deze vorm werd. Sluit weer af met de gate-voetregel; **niet committen**.
- **`stop`** — niets committen. Meld: het werk van de klaarstaande stap staat in de working tree; hervatten kan altijd met `/fwd:steps-run <slug>` (de stap wordt dan her-geverifieerd en opnieuw gepresenteerd).
- **Vrije tekst** — classificeer:
  - *Correctie* → toepassen, gate én reviewer opnieuw, kort delta-rapport (alleen wat veranderde + vers oordeel), opnieuw wachten.
  - *Vraag* → beantwoorden zonder iets te wijzigen; meld dat de stap nog klaarstaat voor `ok`.
  - *Planwijziging* ("voeg een stap toe", "schrap S12", "splits S9") → werk `plan.md` + `state.json` bij; de teller herrekent zichzelf (afgeleid uit de statussen). Ligt er geen onafgeronde stap-code in de tree → commit de planwijziging direct (`chore(steps): plan bijgesteld — <wat>`); anders gaat hij mee met de eerstvolgende `ok`-commit. Meld de nieuwe telling expliciet.

### 7. Tussenbalans (elke 4 goedgekeurde stappen)

Getriggerd door `interim_review=due` uit `record-step.sh`. Spawn **beide doubt-agents parallel** (één bericht, twee Agent-calls, `subagent_type: fwd-skills:fwd-steps-doubt`). Elke prompt bevat alleen: repo-root, de slug, welke stappen zojuist zijn goedgekeurd, en **één** vraag verbatim:

1. `What are you least confident about right now?`
2. `What's the biggest thing I'm missing about the situation right now? What don't I realize?`

De agents denken en antwoorden caveman-stijl (ultrakort, met bewijs-verwijzingen). **Jij consolideert — nadrukkelijk níet in caveman-stijl**: helder Nederlands, volle zinnen, geen jargon, de bewijs-verwijzingen vertaald naar gewone taal. Kies een verdict: onderbouwd "niets aanpassen", of een concreet voorstel (stap toevoegen/bijstellen, deferral naar voren halen, eindbeeld herijken).

```
── Tussenbalans na stap <N>/<M> ────────────────────────

Minst zeker over:      <2-3 volle zinnen, met concrete verwijzing>

Grootste blinde vlek:  <2-3 volle zinnen, met concrete verwijzing>

Verdict:               <wat dit betekent en wat ik voorstel — of waarom
                       er niets hoeft te veranderen>

── ok = door met stap <N+1>/<M> · of typ wat je hiervan vindt ──
```

**Stop de beurt** — de tussenbalans verdient een eigen leesmoment. Vrije tekst hierop volgt het gate-protocol (een voorstel overnemen = meestal een planwijziging).

### 8. Vastlopen binnen een stap

Krijg je het niet groen zonder de test te verzwakken of buiten de stap te treden: stop met bouwen en rapporteer eerlijk in plaats van het stap-rapport — wat je hebt geprobeerd, waar het precies klemt, en 2-3 concrete opties (een richting die jij voorstelt / de stap herformuleren / het plan bijstellen). Gate open; de gebruiker kiest. Geen circuit breaker — er zit een mens bij.

### 9. Eindrapport (na de laatste `ok`)

`record-step.sh` heeft `status=done` gezet. Render:

```
── Klaar: <M>/<M> stappen ──────────────────────────────

Beloofd vs. gebouwd:
  <het eindbeeld-anker uit plan.md naast wat er nu staat — 2-3 regels;
  wijkt het af, zeg dan precies waar>

Zelf draaien:
  1. <commando>
  2. … (maximaal 5 stappen)

Bewust uitgesteld:
  - <note> — doen zodra <when>     (alle deferrals uit state.json; leeg → "niets")

Hoe verder: mergen / eerst zelf spelen / parkeren met reden — zeg het maar.
```

**Elke "Zelf draaien"-regel is vooraf door jou uitgevoerd en werkend bevonden** — geen ongeteste instructies. De merge-keuze is expliciet aan de gebruiker; deze skill merget nooit zelf.

## Stijl

- Nederlands, technische termen Engels; schrijf afkortingen uit bij eerste gebruik.
- Het stap-rapport is gevraagde uitleg en dus geen ballast — maar daarbuiten geldt ponytail's uitvoerregel: code eerst, geen essays, geen feature-tours.
- Rapporteer uitkomsten trouw: falende gates met hun uitvoer, een niet-gedraaide reviewer als "niet gedraaid" — nooit aandikken.
