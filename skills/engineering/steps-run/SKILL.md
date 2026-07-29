---
name: steps-run
description: Voer een stappenplan van /fwd:steps-plan uit — attended, precies één stap per beurt. Per stap; falende test eerst (rood), minimale implementatie langs de Lazy Ladder (groen), volledige gate, vers oordeel door een read-only reviewer-subagent, en een beslis-eerst stap-rapport van ±25 regels met "Stap N/M"-teller (open punten bovenaan, veranderd per map, titels boven de tekst) — daarna stopt de beurt en beslist de gebruiker (ok = commit & door, auto = autonoom afmaken, m = meer detail, stop = pauze, vrije tekst = correctie/vraag/planwijziging). Elke 4 goedgekeurde stappen een tussenbalans door twee doubt-subagents. Use when the user runs /fwd:steps-run <slug>, zegt "volgende stap", "ga door met het stappenplan", of "hervat <slug>". Zonder argument: lijst alle stappenplannen. Niet voor onbeheerd werk — dat is fwd:mission-run.
argument-hint: "[<slug>] — zonder argument: lijst alle stappenplannen"
allowed-tools: Read, Glob, Grep, Bash, Edit, Write, Agent
---

# fwd:steps-run

Eén stap per beurt, bewijs vóór uitleg, commit pas na akkoord. **Jij (hoofdsessie) schrijft de code zélf** — geen coder-subagent; uitleg uit eerste hand. Vers oordeel per stap: `fwd:steps-reviewer` (read-only, verse context); tussenbalans elke 4 stappen: `fwd:steps-doubt`. Werk in een eigen worktree — setup + werkafspraken: stap 0; hoofd-checkout blijft vrij voor parallel werk.

**Attended-principe.** De gebruiker zit erbij en beslist op elk gate-moment.

- **Nooit voorbij het gate-moment bouwen.** Na het stap-rapport stopt de beurt — geen "alvast beginnen" aan de volgende stap.
- **Geen `AskUserQuestion` op gates.** Het gate-protocol is plain text (`ok` / `m` / `stop` / vrije tekst).
- **Nooit pushen, nooit PRs openen.** Committen op de plan-branch gebeurt alleen via `record-step.sh`, na akkoord.
- **Nooit groen faken.** Een test verzwakken, een assert verwijderen of een gate omzeilen om "door te komen" is uitgesloten — vastlopen wordt eerlijk gerapporteerd.

**De bash / Claude / subagent-splitsing:**

- **Bash-scripts** — deterministische state, git, exit codes. Draai ze; vertrouw hun uitvoer.
- **Jij** — code schrijven, tests schrijven, uitleggen, wegen wat de reviewer vindt.
- **Subagents** — het onafhankelijke oordeel. Jij vult het reviewer-oordeel in het stap-rapport nooit zelf in; zonder reviewer-run geen stap-rapport.

## Status (sessiestart)

!`bash "${CLAUDE_SKILL_DIR}/scripts/status.sh" "$ARGUMENTS"`

## Flow

**Zonder slug** — lijst hierboven als nette tabel (slug, voortgang, branch, worktree, titel), stop; de gebruiker kiest.

**Met slug** — interpreteer de status-injectie:

### 0. Worktree opzetten + preflight

**Eerst de worktree:**

```
WT="$(bash "${CLAUDE_SKILL_DIR}/scripts/setup-worktree.sh" <slug>)"
```

Hergebruikt de worktree die `/fwd:steps-plan` al maakte (`.trees/steps/<slug>/`) — of maakt 'm opnieuw op een verse clone; je hoofd-checkout is al vrij en wordt niet geraakt. Kopieert ongetrackte gitignore'de `.env*` mee, print het absolute pad. **Vanaf nu is `<WT>` je werkmap**: lezen/schrijven in `<WT>/…`, gates via `cd "<WT>" && …`, `<WT>` als repo-root aan elke subagent. Faalt het script:

| Signaal | Actie |
|---|---|
| `no-plan` | Geen `steps/<slug>`-branch → eerst `/fwd:steps-plan`. Stop. |
| `dirty-main` | Zeldzaam (alleen bij een oud in-place plan of een handmatige switch): de hoofd-checkout staat zélf op `steps/<slug>` met ongecommitte wijzigingen — het script kan ze niet veilig verplaatsen. Meld het exacte commando, stop; de gebruiker commit/stasht zelf. |

**Dan de preflight** (statusregels hierboven; her-draai `status.sh <slug>` nu de worktree bestaat — verse `dirty_tree`/`next_*`):

| Signaal | Actie |
|---|---|
| `corrupt-state` (exit 3) | Meld het, toon het pad, stop — niet zelf repareren zonder de gebruiker. |
| `pending_autonomous_commit=yes` | Autonome run brak af met opgestapeld, ongecommit werk → *Hervatten van een onderbroken autonome run*. |
| `dirty_tree=yes` (en `pending_autonomous_commit=no`) | → *Hervatten met een klaarstaande stap*. |
| `status=done` | Alles af — verwijs naar eindrapport / merge-keuze, stop. |
| `next=none` | Alle stappen done/skipped maar status niet `done` → eindrapport (stap 9). |

**Hervatten met een klaarstaande stap.** Eén scenario past hierbij: een eerdere sessie bouwde de eerstvolgende `todo`-stap in de worktree, stopte vóór het akkoord. `dirty_files` passen bij die stap → gate (`cd "<WT>"`) én reviewer her-draaien (de tree kan intussen aangeraakt zijn), stap-rapport opnieuw tonen, gemarkeerd "(stond al klaar)". Zo nee → eerlijk melden wat er ligt, opties geven (wegcommitten buiten het plan om / stashen / inspecteren), stop.

**Hervatten van een onderbroken autonome run.** `pending_autonomous_commit=yes` = opgestapeld, ongecommit werk van een `auto`-run die naar attended brak. De done-maar-ongecommitte stappen staan al op `done` in `state.json` (via `--no-commit`) — **herbouw ze nooit**. Twee wegen: **afronden** → meteen de autonome eindreview (sectie 9a), na `ok` één commit via `finalize-autonomous.sh`; **doorgaan** → autonome loop (sectie 6a) vanaf de eerstvolgende `todo`-stap. **Break-out-finalize-guard:** dit werk nooit committen via het attended `record-step.sh` van een losse stap — diens `git add -A` veegt álle opgestapelde stappen in één stap-commit met de verkeerde message. Eerst finaliseren, dan pas een attended `ok` op een nieuwe stap.

### 1. Brief

Lees uit `<WT>/.claude/steps/<slug>/`: `plan.md` (DoD, eindbeeld, seams — én de sub-bullets van deze stap: een stap kan meerdere gedragingen bundelen, elk met eigen bewijs) en de stap uit de status-injectie (`next_*`). **Lees élk rule-bestand uit `next_rules` vóór de eerste regel code** — regels zijn bindend en vuren niet vanzelf bij nieuwe bestanden.

### 2. Rood

Werk **per gedraging** van de stap: schrijf de falende test(s) voor díe gedraging — 1-3 tests per gedraging, uitsluitend op de in `plan.md` afgesproken seams — draai ze gericht, **leg de letterlijke falende uitvoer vast** voor het rapport, en maak groen (stap 3) vóór je aan de volgende gedraging begint. Testkwaliteit:

- Verwachte waarden komen uit een onafhankelijke bron (de spec, het eindbeeld, een uitgewerkt voorbeeld) — nooit narekenen zoals de productiecode het doet (schijntest).
- Publieke interface, geen interne details — de test overleeft een refactor.
- Alleen de tests van déze stap — geen tests vooruit schrijven voor latere stappen.

Bij commando-bewijs (vooraf zo gemarkeerd in het plan: `next_criterion_type=command`, of een sub-bullet met `commando → verwacht`): sla rood over voor precies díe gedraging en noteer dat in het rapport; het bewijs is straks het commando met zijn verwachte resultaat.

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

De **volledige gate** draait één keer per stap, ná de laatste gedraging, in de worktree (`cd "<WT>" && <gate=>` uit de injectie) tot alles groen is — niet alleen de nieuwe tests; de gate is de regressiedetectie. Tussendoor volstaan per gedraging de gerichte tests uit stap 2.

### 4. Vers oordeel

Spawn de reviewer (Agent tool, `subagent_type: fwd:steps-reviewer`). Prompt bevat **alleen**: worktree-pad `<WT>` (z'n repo-root — daar staat de code), stap-titel + álle gedragingen (bundel: de sub-bullets), per gedraging het klaar-criterium, gate-commando, rule-paden. **Niet** de diff, je code of je redenering — de reviewer trekt alles zelf op (`rtk git diff`): bespaart tokens, voorkomt doorvertel-bias.

Verwerk het JSON-verdict:

- `gate.passed=false` → terug naar stap 3; fix, reviewer opnieuw.
- `test_quality` of een rule `passed=false` → fixen vóór het rapport (geen meningen); tenzij aantoonbaar onjuist → gemotiveerd open punt in het rapport.
- Over-engineering, mee eens → toepassen, gate opnieuw, rapporteren als "toegepast".
- Niet mee eens → open punt, één regel waarom niet.

### 5. Stap-rapport → stop de beurt

Render exact dit sjabloon (±25 regels, Nederlands, technische termen Engels, titels bóven de tekst — nooit ernaast — en geen code-snippets: die zitten achter `m`):

```
── Stap <N>/<M> — <titel> ──────────────────────────────

In één zin: <wat er nu kan en wat er bewust nog niet is — het gedrag in
gewone taal, geen opsomming van onderdelen>

Vóór je ok geeft — dit vraagt je oordeel:
• <één bullet per open punt: elke bewuste deferral ("<wat> — bewust
  uitgesteld, oppakken zodra <wanneer>") en elke open reviewer-vondst
  ("<vondst> — <in één regel waarom open>; ok = zo laten");
  geen open punten → één regel "geen: niets uitgesteld, reviewer zonder
  bezwaren", zonder bullets>

Veranderd (per map)
1. <map>/ — <wat er nieuw of anders is en wat het doet, in gewone taal;
   noem per map het aantal bestanden>
2. <max 4 genummerde punten: groepeer bestanden per map, losse
   root-bestanden samen onder "root"; toegepaste reviewer-vondsten
   horen hier gewoon tussen>

Waarom je dit kunt vertrouwen
<2-4 zinnen: eerst rood — de letterlijke falende testregel (bundel: één
voorbeeld + "zo voor alle <n> gedragingen"; commando-bewijs: "commando →
verwacht resultaat" i.p.v. rood) — daarna <n> nieuwe tests en gate <X/X>
groen, en dat de reviewer de gate zelf herdraaide en testkwaliteit en
rules keurde; sluit af met de narrative-zin van de reviewer tussen
aanhalingstekens>

Volgende:   stap <N+1>/<M> — <titel>    (of: dit was de laatste stap)
── ok = commit & door · auto = autonoom afmaken · m = meer detail · stop = pauze · of typ correctie/vraag ──
```

**Stop hier.** De volgende beurt is aan de gebruiker.

### 6. Gate-protocol (de reactie van de gebruiker)

- **`ok` / `y`** — commit en door (in de worktree; `record-step.sh` commit met `git add -A` op de plan-branch):

  ```
  echo '{"deferrals":[…]}' | ( cd "<WT>" && bash "${CLAUDE_SKILL_DIR}/scripts/record-step.sh" <slug> <step-id> "<conventional message>" )
  ```

  De message beschrijft het gedrag (`feat(auth): wachtwoord-reset e-mail met 1u-expiry`), zonder stap-codes. Uitvoer: `interim_review=due` → tussenbalans (sectie 7), beurt stopt · `status=done` → eindrapport (sectie 9), zelfde beurt · anders → volgende stap (terug naar stap 1), eindig bij háár rapport.
- **`auto` / `autonoom`** (geldig overal waar `ok` mag) — resterende stappen autonoom afmaken: **Autonome modus** (sectie 6a).
- **`m` (more)** — uitgebreide uitleg van dezelfde stap: per bestand de kernwijziging mét snippet, volledige reviewer-bevindingen, overwogen alternatieven, waarom deze vorm. Afsluiten met de gate-voetregel; **niet committen**.
- **`stop`** — niets committen. Meld: het werk van de klaarstaande stap staat in de working tree; hervatten kan altijd met `/fwd:steps-run <slug>` (stap wordt her-geverifieerd en opnieuw gepresenteerd).
- **Vrije tekst** — classificeer:
  - *Correctie* → toepassen, gate én reviewer opnieuw, kort delta-rapport (alleen de verandering + vers oordeel), opnieuw wachten.
  - *Vraag* → beantwoorden, niets wijzigen; de stap blijft klaarstaan voor `ok`.
  - *Planwijziging* ("voeg een stap toe", "schrap S12", "splits S9") → `plan.md` + `state.json` bijwerken; de teller herrekent zichzelf (afgeleid uit de statussen). Geen onafgeronde stap-code in de tree → direct committen (`chore(steps): plan bijgesteld — <wat>`); anders mee met de eerstvolgende `ok`-commit. Nieuwe telling melden.

### 6a. Autonome modus (`auto`)

Bij `auto` (of `autonoom`): resterende stappen afmaken **zonder per stap te stoppen**. Per stap exact dezelfde rigor — brief, rood, groen, volledige gate, vers oordeel — maar **er wordt niets op de branch gecommit tot de eindreview** (sectie 9a); het werk stapelt ongecommit op in de worktree.

**De loop, per resterende stap:**

1. **Snapshot vóór.** `SNAP_VOOR="$( cd "<WT>" && bash "${CLAUDE_SKILL_DIR}/scripts/snapshot-worktree.sh" <slug> )"` — legt de huidige (opgestapelde) worktree vast als isolatie-ref; muteert niets.
2. **Bouw de stap** — brief, rood, groen, volledige gate — als de attended stappen 1–3.
3. **Snapshot ná.** `SNAP_NA="$( cd "<WT>" && bash "${CLAUDE_SKILL_DIR}/scripts/snapshot-worktree.sh" <slug> )"`.
4. **Vers oordeel met range.** Reviewer als stap 4, maar met diff-range `SNAP_VOOR SNAP_NA` i.p.v. de default `HEAD`: niets is gecommit, een `HEAD`-diff zou de hele opgestapelde berg tonen — de snapshots isoleren déze stap, inclusief nieuwe untracked bestanden. Snapshot-ná valt vóór `record-step.sh` ⇒ geen `.claude/steps/**`-churn in de range: de reviewer ziet alleen de deliverable. Verdict verwerken als stap 4.
5. **Registreer zonder commit.** `record-step.sh --no-commit <slug> <step-id> "<message>"` — stap done, plan.md getikt, `approved_mode=autonomous`, geen commit.
6. **Lees de uitvoer.** `interim_review=due` → tussenbalans (sectie 7; doubt-agents diffen zelf ongecommit-inclusief tegen de base-branch, geen snapshot meegeven): verdict "niets aanpassen" → automatisch door, concreet voorstel → break-out. `status=done` → eindreview (sectie 9a). Anders → volgende stap.

**Break-out naar attended** — beurt stopt, niets gecommit, de gebruiker beslist — bij:
- een **vastgelopen stap** (sectie 8);
- een **gate die rood blijft** na een redelijke fix-poging;
- een **reviewer-FAIL** (gate, test-quality of een rule) die niet vanzelf oplost;
- een **doubt-agent met een concreet voorstel** in de tussenbalans.

Toon het "vastgelopen"-rapport (sectie 8) of de tussenbalans (sectie 7); de beurt is weer aan de gebruiker. Opgestapeld werk blijft ongecommit in de worktree; hervatten kan altijd (sectie 0). **"Nooit groen faken" geldt onverkort** — ook een autonome run rapporteert vastlopen eerlijk en stopt.

### 7. Tussenbalans (elke 4 goedgekeurde stappen)

Getriggerd door `interim_review=due` uit `record-step.sh`. Spawn **beide doubt-agents parallel** (één bericht, twee Agent-calls, `subagent_type: fwd:steps-doubt`). Elke prompt bevat alleen: worktree-pad `<WT>` als repo-root, de slug, de zojuist goedgekeurde stappen, en **één** vraag verbatim:

1. `What are you least confident about right now?`
2. `What's the biggest thing I'm missing about the situation right now? What don't I realize?`

De agents antwoorden caveman-stijl (ultrakort, met bewijs-verwijzingen). **Jij consolideert — nadrukkelijk níet in caveman-stijl**: helder Nederlands, volle zinnen, geen jargon, bewijs-verwijzingen vertaald naar gewone taal. Verdict: onderbouwd "niets aanpassen", óf een concreet voorstel (stap toevoegen/bijstellen, deferral naar voren halen, eindbeeld herijken).

```
── Tussenbalans na stap <N>/<M> ────────────────────────

Minst zeker over
<2-3 volle zinnen, met concrete verwijzing>

Grootste blinde vlek
<2-3 volle zinnen, met concrete verwijzing>

Verdict
<wat dit betekent en wat ik voorstel — of waarom er niets hoeft te
veranderen>

── ok = door met stap <N+1>/<M> · of typ wat je hiervan vindt ──
```

**Stop de beurt** — de tussenbalans verdient een eigen leesmoment. Vrije tekst hierop volgt het gate-protocol (een voorstel overnemen = meestal een planwijziging).

### 8. Vastlopen binnen een stap

Niet groen te krijgen zonder de test te verzwakken of buiten de stap te treden → stop met bouwen; rapporteer eerlijk in plaats van het stap-rapport: wat je probeerde, waar het precies klemt, 2-3 concrete opties (een richting die jij voorstelt / de stap herformuleren / het plan bijstellen). Gate open; de gebruiker kiest. Geen circuit breaker — er zit een mens bij.

### 9. Eindrapport (na de laatste `ok`)

`record-step.sh` zette `status=done`. Render:

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

De code staat in de worktree op branch `<branch>` (`<WT>`).
Hoe verder: mergen (`rtk git switch <base> && rtk git merge <branch>`) / eerst zelf spelen in `<WT>` / parkeren met reden — zeg het maar.
```

**Elke "Zelf draaien"-regel is vooraf door jou in `<WT>` uitgevoerd en werkend bevonden** — geen ongeteste instructies. De merge-keuze is expliciet aan de gebruiker; deze skill merget nooit zelf.

### 9a. Autonome eindreview + commit-gate

Laatste stap klaar (`status=done` uit `record-step.sh --no-commit`) of onderbroken run afronden → er is nog **niets gecommit**. Eerst de eindreview — het opgetelde beeld naast het eindbeeld uit `plan.md` — en commit pas na `ok`:

```
── Autonome run klaar: stap <a>→<b>/<M> zonder tussenstop ────────

Gebouwd (nog niets gecommit):
  <id>  <titel>            +<x>/-<y>   <bestanden>
  … (één regel per autonome stap)
  Totaal: <n> stappen · +<X>/-<Y> · <k> bestanden

Gate:            <X/X> groen (na elke stap herdraaid)
Reviewer:        <n>/<n> stappen schoon
Doubt (na <id>): <verdict — "niets aanpassen" of wat er speelde>
Deferrals:       <alle deferrals uit state.json; leeg → "niets">
Open punt(en):   <reviewer-punten die open bleven, of "geen">

Zelf zien:       cd <WT> && rtk git diff <base>   ·   <gate-commando>

── ok = commit alles (1 commit) & klaar · message aanpassen? zeg 't · stop = niets committen ──
```

- **`ok`** → `finalize-autonomous.sh <slug> "<message>"`: **één commit** van al het opgestapelde werk. Message bijsturen mag; per-stap splitsen kan niet (de `--no-commit`-accumulatie liet geen commit-grenzen na). Uitvoer: `status=done` → eindrapport (sectie 9); `status=in_progress` (deel-finalize na een eerdere break-out) → meld wat gecommit is en welke stappen open staan.
- **`stop`** → niets committen; het werk blijft in de worktree. Hervatten: `/fwd:steps-run <slug>` (sectie 0).

Brak de run halverwege uit → geen eindreview maar het "vastgelopen"-rapport (sectie 8) of de tussenbalans (sectie 7), zie *Break-out naar attended* (sectie 6a); het werk blijft ongecommit tot je later afrondt.

## Stijl

- Nederlands, technische termen Engels; schrijf afkortingen uit bij eerste gebruik.
- Het stap-rapport is gevraagde uitleg, geen ballast — daarbuiten geldt ponytail's uitvoerregel: code eerst, geen essays, geen feature-tours.
- Rapporteer uitkomsten trouw: falende gates met hun uitvoer, een niet-gedraaide reviewer als "niet gedraaid" — nooit aandikken.
