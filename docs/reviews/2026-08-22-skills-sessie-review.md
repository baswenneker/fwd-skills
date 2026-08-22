# Verbeteringen fwd-skills — geoogst uit echte sessies

*Datum: 22 augustus 2026 · Scope: alle 19 skills en 6 agents in deze repo · Bron: 56 Claude Code-sessies uit 14 projecten (juni–augustus 2026)*

## In 't kort

- **Stand van zaken (22 augustus):** de tien punten uit deel 1 zijn doorgevoerd en geverifieerd, plus de vijf hoog-impactpunten op de mission-agents in deel 3. De rest ligt er nog.
- **115 verbeterpunten** — 82 per skill, 19 per agent, 14 repo-breed. Elk sessiepunt heeft een citaat uit een echte run, elk repo-punt een `bestand:regel`. Alles is geverifieerd tegen de huidige repo; ruim de helft is een tekstwijziging van één tot drie zinnen.
- **De grootste risico's zijn klein te repareren**: een read-only reviewer die `git stash` doet op je onbeoordeelde werk, een geheim dat door de commit-scan glipt, en een setup-wizard die ongevraagd getrackte bestanden in een klantrepo aanpast.
- **Het juli-review is grotendeels ingelopen**: 20 van de 27 gaten dicht, 7 deels — die zeven zitten bijna allemaal in `fwd:mission-run`.
- **De drie mission-agents waren een blinde vlek.** Ze kregen geen enkele sessiebevinding, simpelweg omdat ze minder vaak draaien. Bij directe lezing leverden ze vijf hoog-impactpunten op, waaronder een compleet outputkanaal (`advisories`) dat nergens landt.
- **Vier skills worden nooit gebruikt** (`fwd:skill-eval`, `fwd:explain`, `fwd:handoff`, `fwd:premortem`) en één is niet eens aanroepbaar (`plan-with-doc` staat niet in `plugin.json`). Dat is een aparte beslissing: repareren of schrappen.
- **Terugkerend patroon**: hand-gekopieerde tekstblokken lopen uiteen, en `check-agent-norms.sh` bewaakt maar twee blokken over vijf van de zes agents.

---

## Hoe dit rapport tot stand kwam

Alle 692 sessietranscripts in `~/.claude/projects/` zijn gefilterd op daadwerkelijk gebruik van deze plugin — niet op vermeldingen, maar op uitgevoerde skill-scripts, geladen SKILL.md's en gespawnde agents. Dat leverde 56 sessies op, verdeeld over `fwd-skills` zelf en dertien andere projecten (res-193, res-211, poc-contract-clause-chunking, Lely-repos, life-os, fwd-voice-control).

Zes verkenners hebben die sessies per skill-familie uitgeplozen op frictie: gebruikerscorrecties, mislukte scripts, herhaalde handmatige workarounds, en momenten waarop de skill iets deed wat zijn eigen tekst verbiedt. Elke bevinding is daarna adversarieel getoetst tegen de huidige repo — de opdracht was om hem te weerleggen. Van de 86 kandidaten overleefden er 85 (83 nog actueel, 2 deels opgelost, 1 weerlegd).

Daarnaast zijn drie dingen los onderzocht: de status van de 27 gaten uit het juli-review, de repo-consistentie (registratie, frontmatter, cross-skill-verwijzingen, scripts, testdekking — alles met een commando gecontroleerd), en de drie agentbestanden die geen enkele sessiebevinding kregen.

**Leesinstructie per tabel:** *Impact* is hoe erg het is als het misgaat, *Werk* is hoe groot de wijziging is (klein = een paar zinnen, middel = een script aanpassen plus een test, groot = ontwerpkeuze).

**Wat dit rapport niet is:** geen oordeel over of een skill nuttig is. Een skill die nul keer draaide krijgt hier een diagnose van *waarom* hij niet draaide, geen advies om hem weg te gooien — op `plan-with-doc` na, die aantoonbaar kapot en onbereikbaar is.

---

## Deel 1 — De eerste tien · **doorgevoerd op 22 augustus 2026**

Tien punten waar risico en kleine moeite samenvallen. Alle tien zijn uitgevoerd; de laatste kolom zegt wat er precies is veranderd en hoe het is nagelopen.

Geverifieerd na afloop: `scripts/check-agent-norms.sh` groen (drie gedeelde blokken identiek), de steps-testsuite groen (7/7, met drie nieuwe assertions), `bash -n` op elk gewijzigd script, en drie live proeven in wegwerprepo's — de commit-scan, de setup-wizard zonder `jq`, en de setup-wizard in een repo met getrackte bestanden.

| # | Wat | Waarom het uitmaakte | Wat er nu staat |
| --- | --- | --- | --- |
| 1 | De read-only reviewer draait `git stash` op je onbeoordeelde werk | Crasht de agent tussen stash en pop, dan staat het werk van de gebruiker in een stash die niemand zoekt | ✅ `agents/steps-reviewer.md` — twee bullets bij *Behavior prohibitions*: elke schrijfoperatie op tree of index verboden, en wie code wil weglaten om een effect te isoleren doet dat op een kopie in `$TMPDIR` |
| 2 | De commit-scan ziet een geheim in een nieuwe map niet | `git status --porcelain` vouwt een nieuwe map samen tot `?? config/`, dus `config/.env.production` passeert alle naamchecks en wordt door `git add -A` gestaged | ✅ `pre-flight.sh` gebruikt nu `--untracked-files=all`. Bewezen met een wegwerprepo: de oude vorm antwoordde `ok` en stageerde `config/.env.production`, de nieuwe geeft `risky-files: config/.env.production — env-file` en stageert niets |
| 3 | `/fwd:setup` past getrackte bestanden aan in een gedeelde klantrepo, zonder dat te melden | In de Lely-repo schreef de wizard 29 regels HeadingFWD-instructies in `CLAUDE.md` en 12 in `.gitignore`; die liften mee in de volgende merge request | ✅ `apply-all.sh` sluit af met een `### tracked`-blok, `OUTPUT.md` heeft de verplichte sectie "Onder versiebeheer". Getest: in een repo met getrackte `CLAUDE.md` en `.gitignore` noemt het blok beide; buiten een git-repo blijft het leeg zonder te klappen |
| 4 | Ontbreekt `jq`, dan overschrijft de setup je hele `settings.local.json` — en je ziet het niet | `merge-json.sh` maakt een `.bak`, schrijft een snippet van drie regels over het bestand heen en geeft exit 0; het rapport toont waarschuwingen alleen bij exit 2 of hoger | ✅ `merge-json.sh` schrijft niets meer zonder `jq` en geeft exit 2 met een Nederlandse melding; `OUTPUT.md` toont een niet-lege `stderr` nu ook bij een ✓. Getest met een PATH zonder `jq`: settings ongewijzigd, geen `.bak` |
| 5 | De commit-agent zette `Co-Authored-By: Claude` in twee commits die al gepusht zijn | Het verbod staat als losse bullet middenin de berichtinstructie, niet in de `## Safety`-lijst waar alle andere harde verboden met NEVER staan | ✅ Twee regels bij `## Safety`: geen Claude/Anthropic-trailer in welke vorm dan ook, en alle git via `rtk git` — nooit kaal `git` |
| 6 | Een stap zonder codewijziging kan niet worden vastgelegd — de run loopt vast vlak vóór de finish | `record-step.sh` eist minstens één vies bestand; een pure validatiestap (alleen een commando draaien) haalt die check nooit | ✅ `record-step.sh` kent `--state-only`: schone tree toegestaan, alleen `.claude/steps/<slug>/` gecommit, en geweigerd zodra er code-wijzigingen buiten die map staan. Sectie 6 van `steps-run` roept hem aan. Drie nieuwe assertions in `test_record_step.sh`, suite 7/7 groen |
| 7 | "Nooit `--background`" is een belofte die de skill niet kan waarmaken | In 2 van de 2 runs zette de Codex-runtime de review tóch als achtergrondtaak weg; de sessie improviseerde een poll-lus die nergens beschreven staat | ✅ De bullet is in beide skills vervangen door een wachtroute met het poll-commando en een verbod op zelfbedachte `sleep`-lussen. `check-agent-norms.sh` bevestigt dat het blok byte-identiek bleef |
| 8 | Een geadopteerde feature slaat de milestone-validatie over en de missie gaat rechtstreeks naar finalize | `reconcile.sh` zet de feature op `done` maar raakt `milestones[].validation_status` niet aan; `pick-next-unit.sh` geeft dan niets meer terug en de flow leest dat als "alles klaar" | ✅ `mission-run/SKILL.md` draagt na een `adopted` op eerst de milestone-validatie te draaien als die adoptie de milestone sluit; de kop van `reconcile.sh` zegt nu expliciet dat adoptie de feature markeert en nooit de milestone |
| 9 | `plan-with-doc` is een kapotte kopie van `fwd:plan` die niemand kan aanroepen | Staat niet in `plugin.json` en niet in de README; een niet-afgesloten codeblok slikt `## Style` en de hele check-modus op; nul keer gebruikt | ✅ Verwijderd. Vooraf gecontroleerd: geen enkele verwijzing erheen buiten het bestand zelf. De dode `/fwd:write-doc`-regel in `fwd:explain` is meteen meegegaan |
| 10 | Subagents draaien zonder tijdsbudget; één twijfelagent deed er 66 minuten over | De agent besloot zelf de volledige validatie over 504 contracten te draaien; bij een sessieherstart kwamen agents terug als "automatically restarted" en moest de hoofdsessie twee keer uitleggen wat dat was | ✅ Secties 4 en 7 starten subagents blokkerend (parallel binnen één beurt mag, achtergrondtaak niet). De reviewer draait de gate één keer en geeft `passed: null` bij een te lange run; de doubt-agent leest en grept, maar draait geen dataset- of validatieruns |

---

## Deel 2 — Per skill

### `fwd:steps-run` — 12 punten

Meest gebruikte skill van de plugin (echte runs in poc-contract-clause-chunking, res-193, fwd-voice-control, Lely-repos). De rapportage werkt; de frictie zit in de randen van de uitvoering: gate, worktree en subagent-regie.

| Wat er misging | Waarom het uitmaakt | Wat te doen | Impact / Werk |
| --- | --- | --- | --- |
| Stap zonder codewijziging kan niet worden vastgelegd | De run loopt vast op de laatste stap; gebruiker moet het handmatig oplossen | `record-step.sh` → `--state-only`-vlag, aangeroepen als het klaar-criterium `command` is en de tree schoon | hoog / klein |
| Een al rode gate leest als een falende stap | `make dev` faalde al vóór het plan op een dekkingsgat; elke stap kreeg `gate.passed=false` en zowel de sessie als de reviewer moesten dat elke keer opnieuw uitleggen | Sectie 0: draai de gate één keer als nulmeting, schrijf `gate_baseline` in `state.json`, geef die mee aan de reviewer. Alleen een verslechtering dwingt terug naar stap 3 | hoog / middel |
| De verse worktree mist de ontwikkelomgeving | Geen `.venv` in de worktree, dus de gate draaide met de interpreter van de hoofd-checkout; alle "zelf draaien"-commando's in het eindrapport werden onoverdraagbare absolute paden | `setup-worktree.sh` → na de `.env*`-lus detecteren of `.venv`/`node_modules`/`vendor` in de hoofd-checkout bestaan en per stuk een `env-missing:`-regel naar stderr; sectie 0 meldt die vóór stap 1 | hoog / middel |
| Niemand merkt dat de basisbranch doorloopt | In twee runs liep `main` door met werk dat hetzelfde oploste: negen conflicterende bestanden bij de merge, één stap weggegooid en opnieuw gebouwd | `status.sh` → `base_ahead` en, bij overlap, het aantal overlappende bestanden; sectie 0 meldt het bij de start, sectie 9 herhaalt het bóven de merge-keuze | hoog / middel |
| De reviewer krijgt het plan niet | Hij vlagde het Judge-protocol als over-engineering terwijl de Definition of Done die seam juist eist — kostte een extra rapport en een lang verweer | Sectie 4 → `plan.md`-pad toevoegen aan de toegestane prompt-inhoud; `steps-reviewer.md` → een seam uit `plan.md` of de DoD mag nooit als `yagni` gevlagd worden, alleen de bouwwijze is te beoordelen | hoog / klein |
| Subagents zonder tijdsbudget | Zie deel 1, punt 10 | Blokkerend starten; per agent een expliciet plafond | hoog / klein |
| Reviewer wordt stilzwijgend overgeslagen bij commando-bewijs | Het stap-rapport zei "niet van toepassing — geen diff", terwijl de skill zegt: zonder reviewer-run geen rapport | `steps-reviewer.md` → lege diff is legitiem bij een `command`-criterium; return-contract krijgt `command_proof` met `test_quality` nullable | midden / klein |
| Bij vier stappen of minder vuurt de tussenbalans nooit | Een autonome run van 3 stappen kreeg geen enkel onafhankelijk twijfelmoment — juist daar waar geen mens tussen de stappen zit | `record-step.sh:89-90` → ook `due` bij de laatste stap van een niet-attended run zonder eerdere tussenbalans (nu vuurt hij feitelijk pas vanaf 5 stappen) | midden / klein |
| Na een autonome run mist een doorloop van wat er gebouwd is | De gebruiker vroeg er meteen om: het rapport is bewijs-eerst en vertelt niet hoe de onderdelen op elkaar staan | Sectie 9 → verplicht blok "Hoe het werkt, in opbouw": 5-7 genummerde punten in gewone taal. Geen scribe-agent bouwen; de hoofdsessie schreef de code zelf | midden / klein |
| Worktree opruimen ontbreekt in de afsluitende keuzes | In twee sessies moest de gebruiker er zelf om vragen | Sectie 9 → vierde optie met de exacte commando's, expliciet ná een geslaagde merge, plus de regel dat de skill dit nooit uit zichzelf doet | midden / klein |
| Nederlandse skill, Engelse voortgangsregels en subagent-prompts | De rapporten waren Nederlands, al het werkcommentaar ertussen Engels — dat is de helft van wat de gebruiker ziet | Taalregel van `## Stijl` naar de harde regels bovenaan; expliciet: alles wat de gebruiker ziet is Nederlands, prompts naar agents mogen Engels blijven | midden / klein |
| `git add -A` sleept build-rommel de stap-commit in | De reviewer signaleerde dat de verse worktree geen `.gitignore` had voor `__pycache__`; ad hoc gerepareerd, niets in de skill vangt het af | Lift mee op de gate-nulmeting: vergelijk untracked paden vóór en ná; als vangnet een waarschuwing in `record-step.sh` bij bekende artefactpatronen — waarschuwen, niet weigeren | midden / middel |

### `fwd:steps-plan` — 4 punten

| Wat er misging | Waarom het uitmaakt | Wat te doen | Impact / Werk |
| --- | --- | --- | --- |
| Gate wordt gepind zonder droge run, en de run installeerde daarna ongevraagd een globale tool | Het plan koos `pytest -q` in een repo zonder pytest; de run installeerde het als globale `uv`-tool en brak dagen later de testintegratie in VS Code van de gebruiker | `discover-gates.sh:45` → `-d tests` is geen Python-signaal, schrappen; droge verificatielus die exit 127 wegfiltert; `steps-run` → harde regel dat gereedschap buiten de repo installeren altijd een vraag is | hoog / middel |
| Een onderbroken planningssessie laat niets achter | Twee sessies liepen tot vlak vóór het akkoord en eindigden zonder iets op schijf; alles moest opnieuw | Goedkope helft: de afsluitregels van sectie 2 en 3a zeggen erbij dat er nog niets is vastgelegd. Wil je het echt bewaren: een `.concept.md` na het akkoord op sectie 2 — let dan op de belofte "deze skill schrijft alleen plan.md en state.json" | midden / middel |
| Het `state.json`-schema kent één gedrag per stap, terwijl de skill bundeling voorschrijft | Bij een vast stappenbudget is bundelen de regel, niet de uitzondering — maar `behavior` is één zin en `done_criterion` één object. De prozanoot lapt dat op door meerdere dingen in `value` te proppen, waardoor `steps-run` de reviewer-prompt niet rechtstreeks uit het schema kan vullen | Maak er een array van (`behaviors: [{behavior, done_criterion}]`) met de enkelvoudige velden als terugvalvorm, zoals `mission-run` dat met zijn schemaversies doet | midden / middel |
| Gate-ontdekking staat als sectie 4, maar sectie 3 heeft de gate al nodig | De klaar-criteria in sectie 3 verwijzen naar een gate die pas een sectie later wordt vastgesteld | Volgorde omdraaien, of in sectie 3 expliciet maken dat de gate voorlopig is | laag / klein |

### `fwd:mission-run` — 6 punten

| Wat er misging | Waarom het uitmaakt | Wat te doen | Impact / Werk |
| --- | --- | --- | --- |
| Geadopteerde feature slaat milestone-validatie over | Zie deel 1, punt 8 | Eén regel in `SKILL.md:86` + waarschuwing in de kop van `reconcile.sh` | hoog / klein |
| Doorgelopen basisbranch wordt nergens gesignaleerd | `main` liep door voorbij het aftakpunt; dat maakte de "is er echte code?"-check vals-positief en de gebruiker moest zelf om een merge vragen. De ankerfix van juli dekt alleen het geval zónder frontier | Alleen signaleren, geen nieuwe plumbing: `rev-list --count merge-base..base` na sectie 1, melden in het tick-verslag, vastleggen via `log-decision.sh`, tonen in `status.sh`. Automatisch mergen blijft bewust uit de autonome modus | hoog / klein (deels opgelost) |
| Geen herstelprocedure na een foutieve registratie | De orchestrator moest vier scripts lezen en daarna `state.json` met de hand patchen | Geen nieuw script — `record-feature.sh` kan al opnieuw vastleggen. Wel: sectie 2.8 "Correctie na een foutieve adoptie", en corrigeer `REFERENCE.md:251` naar wat `reconcile.sh` echt doet | midden / klein |
| De "accepteren & mergen"-route is een leeg sjabloon | Het eindrapport gaf een cherry-pick terwijl `main` hetzelfde bestand had aangeraakt; gebruiker moest twee keer bijsturen. Bovendien stond er kaal `git` in plaats van `rtk git` | `REFERENCE.md:429-430` → conditioneel recept: geen drift → cherry-pick, wel drift → merge plus waarschuwing; altijd afsluiten met worktree- en branch-opruiming; overal `rtk git` | midden / klein |
| `reconcile.sh` gooit een ongecommitte `state.json` weg met `reset --hard` | Logt een coder een beslissing en crasht de tick daarna, dan is die beslissing zonder waarschuwing weg | Dezelfde filterregel toevoegen die `record-feature.sh:66` al heeft; daarna de LESSONS-notitie van 24 juli bijwerken naar opgelost | laag / klein |
| Missie-administratie belandt ongevraagd op `main` | Na de merge stond de complete `.claude/missions/<slug>/` op main; de orchestrator moest achteraf aanbieden het weg te halen | `REFERENCE.md:32` bevat een aantoonbaar onjuiste claim over wat `finalize.sh` doet — herschrijven naar `rtk git rm -r --cached` ná de merge, en die regel in het "Wat nu?"-sjabloon zetten waar hij gelezen wordt | laag / klein |

### `fwd:mission-plan` — 5 punten

| Wat er misging | Waarom het uitmaakt | Wat te doen | Impact / Werk |
| --- | --- | --- | --- |
| Geen omvang-poort | In een leeg Lely-project stelde de skill twaalf keuzevragen en concludeerde toen zelf dat een missie overkill was. Er kwam nooit een branch, PRD of contract | Nieuw blok "0. Poort — omvang en regels (blokkerend)" boven stap 1: schat de omvang, en onder ~3 features of ~2 uur werk één keuze: mission / steps-plan / direct bouwen | hoog / klein |
| De verplichte regelkeuze werd overgeslagen | De inventaris meldde "geen regels gevonden"; van de veertien keuzevragen ging er geen enkele over regels | Til stap 1.0 uit stap 1 naar diezelfde poort en zet erbij: stel geen andere vraag voordat deze beantwoord is | midden / klein |
| Geen bovengrens aan het aantal keuzevragen | Veertien `AskUserQuestion`-rondes voordat er één regel plan op papier stond — spiegelbeeld van de grill-me-les van 9 juni | Vierde regel bij Vraaghygiëne: bundel verwante keuzes in één aanroep en geef na maximaal vier rondes eerst een korte tussenstand | midden / klein |
| De grens met de steps-familie staat niet in de mission-skills zelf | De gebruiker vroeg rechtstreeks "wat is nu het verschil met mission?"; het antwoord staat in CLAUDE.md en in de steps-skills, maar niet waar de keuze gemaakt wordt | Spiegelzin in de description van beide mission-skills, plus drie regels onder de Quick start over wie de code schrijft en wat er bij tegenslag gebeurt | midden / klein |
| De plan-lint controleert niet of een gate-commando oplost | De gekozen gate was een testscript dat nog geschreven moest worden: exit 127 bij de eerste run | Vijfde faalpatroon bij stap 4.6: droge check per gate; een gate die pas later bestaat mag, maar wordt genoteerd als "wordt groen vanaf F*n*" — en dan moet F*n* ook echt de eerste feature zijn | laag / klein |

---
### `fwd:codex-review-plan` en `fwd:codex-review-implementation` — 8 punten

Drie echte runs. De skills werken, maar drie beloftes in de tekst kloppen niet met wat er gebeurt.

| Wat er misging | Waarom het uitmaakt | Wat te doen | Impact / Werk |
| --- | --- | --- | --- |
| "Nooit `--background`" houdt nooit stand | Zie deel 1, punt 7 | Bullet vervangen door een wachtroute mét het poll-commando. Zit in het bewaakte blok: byte-identiek in beide bestanden, daarna `check-agent-norms.sh` draaien | hoog / klein |
| Bevindingen in jargon; de gebruiker haakte af | Een tabel van 8 rijen met "normatieve instructie" en "gedragscontract" leverde op: *"je moet dit beter uitleggen dit snap ik niet, normatief? wtf"* — het hele rapport moest opnieuw | Bullet bij `## Style`: vertaal Codex' vaktermen, laat geen Engels review-jargon staan. Plus een beslis-eerst-sjabloon in Step 5 (buiten het bewaakte blok, dus per skill vrij) | hoog / middel |
| De resolver kiest een afgeronde, weggegooide mission als reviewscope | De gebruiker wees op verse working-tree-wijzigingen; de resolver koos een mission van twee maanden terug zonder branch en zonder worktree. Vandaag nog reproduceerbaar in deze repo | `resolve-plan-artifact.sh` → `status` en `branch_exists` meegeven; afgeronde artefacten overslaan of terugmelden met exit 3; beide skills krijgen een exit-3-tak die terugvalt op de working tree | hoog / middel |
| De branch-diff faalt als de branch al opgeruimd is | Dat is het normale eindstadium na een merge, en er is geen alternatief beschreven | Drie takken in plaats van twee: worktree bestaat / `show-ref` slaagt / `show-ref` faalt → melden en terugvallen op de working tree | hoog / klein |
| Het promptsjabloon eist ingesloten planinhoud, maar stuurt in de praktijk een pad | De slotregel "report only findings you can support from the plan content given above" is dan betekenisloos, en het werkt alleen zolang Codex dezelfde repo kan lezen | Tweerijige tabel in Step 3: plan ligt als bestand in deze repo → geef het pad en pas de slotregel aan; geplakte tekst of een plan op een niet-uitgecheckte branch → inhoud verplicht insluiten. Geldt alleen voor de *plan*-inhoud; de diff-scope is bewust "zoek het zelf op" | midden / middel |
| De skill stelde een vraag met een verboden tool | `AskUserQuestion` staat niet in `allowed-tools` en wordt door de zusterskill expliciet verboden; direct erna onderbrak de gebruiker de sessie en er kwam geen review | Platte-tekstlijn uitschrijven, direct na de exit-2-regel: "Ik heb *X* gevonden, maar die is afgerond / heeft geen branch meer. Zal ik in plaats daarvan de working tree reviewen? ja / nee / geef een `--base <ref>`" | midden / klein |
| "Structureel niets kunnen bewerken" klopt niet | `Bash` staat wél in `allowed-tools`; in dezelfde sessie werden bestanden weggeschreven met een heredoc — óók het plan zelf | Herformuleer de bullet naar wat waar is, en voeg aan het gedeelde blok een toetsbaar verbod toe: geen `>`, `>>`, `tee` of heredoc naar een bestand | midden / klein |
| Staleness ontbreekt voor de pad- en plaktekst-tak | Het model verzon een basiscommit en greep de commit die `/fwd:git-commit` één beurt eerder had gemaakt | Twee bullets erbij: pad → `rtk git log -1 --format=%H -- <pad>` als basis; geplakte tekst → letterlijk "Staleness: onbekend (plan is niet vastgelegd in de repo)" | laag / klein |

### `fwd:rules-audit` — 5 punten

Eén echte run (Lely myfarm-demo). De skill dóet iets anders dan zijn eigen documentatie zegt.

| Wat er misging | Waarom het uitmaakt | Wat te doen | Impact / Werk |
| --- | --- | --- | --- |
| De skill gebruikt Bash terwijl frontmatter en Boundaries dat uitsluiten | Scande met `find`, `ls`, `cat` en `grep -rn`; zodra een harness `allowed-tools` echt afdwingt valt de scan om | `Bash` toevoegen aan `allowed-tools` en de Boundaries-bullet herschrijven naar wat je écht wilt uitsluiten: geen eigen scripts, Bash alleen lezend, schrijven uitsluitend via `Write` naar `.claude/rules/` | midden / klein |
| De "Selectie"-optie is niet uitvoerbaar | `AskUserQuestion` kent geen vrije tekst, dus het model verzon een vaste deelverzameling; de eerste aanroep sneuvelde bovendien op een JSON-parsefout | Vervang door een platte-tekstvraag met gate-regel in de stijl van `steps-run`: `── ok = alles · R1,R3 = alleen die · aanpassen: <wat> · stop ──` | midden / klein |
| Geen route voor een lege of greenfield repo | Er valt niets te scannen en geen enkel golden example te vinden; de aanroepende skill loste dat zelf op | Pre-check vóór stap 1: minder dan ~10 broncodebestanden of geen git → in één zin melden, audit ná de eerste werkende versie adviseren, stoppen. Eén zinsnede in de description zodat aanroepers het weten | midden / klein |
| De schrijfstijl-norm staat achter een verwijzing die niemand volgt | `CONTEXT.md` is in de enige echte run nooit geopend. Sterker: het aangewezen blok heet "Schrijfstijl **missions**" en scopet zichzelf tot missions en steps-runs — rules-audit valt er niet onder | Zet de zes bullets inline, bullet-voor-bullet, en breid `check-agent-norms.sh` uit met een derde bewaakt blok (het script kan dat al aan) | midden / klein |
| Geen lichte variant — de skill wordt als "overkill" weggewuifd | Waar een andere skill de keuze voorlegt, staat rules-audit als de dure optie en wordt niet gekozen | Snelle modus documenteren: mét focus-argument maximaal 2-3 conventies en geen brede scan. Eén zin in de description, en laten `mission-plan` en `steps-plan` die variant noemen in hun keuzevraag | midden / middel |

### `fwd:git-commit` — 10 punten

Meest gedraaide skill (ongeveer 15 runs, meestal als subagent). Werkt, maar het eindbericht wijkt in élke run af van het voorgeschreven formaat.

| Wat er misging | Waarom het uitmaakt | Wat te doen | Impact / Werk |
| --- | --- | --- | --- |
| `Co-Authored-By: Claude` in twee gepushte commits | Zie deel 1, punt 5 | Verplaats het verbod naar `## Safety` | hoog / klein |
| Risky-scan mist `-uall` | Zie deel 1, punt 2 | `--untracked-files=all`; regressietest toevoegen — deze tak is nog nooit in productie afgegaan | hoog / klein |
| Onbegrensde `rtk git diff --staged` | Bij een grote wijziging leverde het blok 81 KB op; de harness gaf het model alleen de eerste 2 KB en het schreef het bericht blind, zonder te weten dat het blind was | Diff begrenzen (`--stat` + `head -c 20000`) en één zin toevoegen: zie je `<persisted-output>`, lees dan eerst het genoemde bestand in stukken | hoog / klein |
| `git add -A` stageert alles vóór enige beslissing | Zodra de gebruiker wil splitsen, improviseert de agent met `git reset` — in één run 11 tool-calls in plaats van 1 | Niet het ontwerp omgooien; wel twee zinnen: alles is nu gestaged, gebruik `rtk git restore --staged <pad>` (nooit `git reset`) en noem elk teruggezet pad in het eindrapport | hoog / klein |
| Argumenten worden volledig genegeerd | Aangeroepen met "commit alles, twee logische groepen, X blijft buiten scope" verzon het model een werkwijze: twee commits, elf tool-calls, vrij-vorm verslag | Leg de goedkope kant vast: deze skill maakt altijd precies één commit van de hele werkboom; meegegeven tekst is hooguit een hint voor type/scope/description, nooit om te splitsen | midden / klein |
| Onderwerpregel van 402 tekens | Eén `-m` met een heredoc zonder witregel plakt de body aan het onderwerp vast; de 72-tekengrens werd 5,5× overschreden zonder dat iets het merkte | Twee losse `-m`-vlaggen voorschrijven, nooit één `-m` met heredoc | midden / klein |
| Beslistabel dekt een mislukt pre-flight-blok niet | Toen het script niet op het verwachte pad stond, zag de gebruiker een kale bash-fout en moest zelf `/reload-plugins` draaien | Fallback in het blok (bij een falend script `preflight-failed` echoën) en een vijfde tak: onbekende eerste regel → commit niets, citeer letterlijk wat er stond | midden / klein |
| Setup-artefacten vallen buiten het gitignore-blok dat setup zelf schrijft | `.claude/hooks/`, `settings.local.json` en `lessons/` staan untracked; draait `/fwd:git-commit` daar, dan committeert `add -A` persoonlijke hooks in een gedeelde repo | Drie regels toevoegen aan `setup/scripts/gitignore/payload/entries` | midden / klein |
| Gekopieerde risky-scan in mission-run is al gedrift | `risky-scan.sh` belooft dezelfde patronen als `pre-flight.sh` maar mist de log-bestandcheck; een `*.log` passeert daar wél | `LOG_EXT` toevoegen; ook de kleinere drift meepakken (`$base` versus `$pathpart`). Een gedeeld patronenbestand is pas nodig bij een derde kopie | midden / klein |
| Het eindbericht wijkt in elke run af | Elke run begint met proza en eindigt met een niet-gedocumenteerde `Hash:`-regel; één run beweerde bovendien iets onwaars | Neem de formulering van `fwd:setup` letterlijk over ("geen inleiding, geen nabeschouwing") en geef de hash een gedocumenteerde plek in het sjabloon. Idem: één regel in `## Safety` dat alle git via `rtk git` loopt — in één run ging alles met kaal `git` | laag / klein |

### `fwd:setup` — 4 punten

Twee echte runs. Beide renderden het rapport anders, en één schreef in een gedeelde bedrijfsrepo.

| Wat er misging | Waarom het uitmaakt | Wat te doen | Impact / Werk |
| --- | --- | --- | --- |
| Wijzigt getrackte bestanden zonder waarschuwing | Zie deel 1, punt 3. De run vond plaats één bericht ná *"Let op, geen destructieve acties doen zonder mijn toestemming."* | `apply-all.sh` → `rtk git ls-files` na de installatie; `OUTPUT.md` → verplichte sectie "Onder versiebeheer" | hoog / middel |
| Waarschuwing bij exit 0 is onzichtbaar, inclusief een destructieve fallback | Zie deel 1, punt 4 | `merge-json.sh` → exit 2 en niet schrijven zonder `jq`; `OUTPUT.md` → niet-lege stderr ook tonen bij ✓ | hoog / klein |
| Het rapportsjabloon spreekt zijn eigen voorbeeld tegen | De invulregel zegt "de laatste `→`", maar bij smartlint is dat `settings.local.json` terwijl het voorbeeld de hooks-map toont; beide runs weken af, elk anders | Maak het mechanisch: derde kolom "vaste trailing-tekst" in de slug→label-tabel, en schrap de "laatste pijl"-regel | laag / middel |
| Stop-hook krijgt `timeout: 180000` | Claude Code rekent hook-timeouts in seconden — dat is ruim 50 uur, dus een vastgelopen lint wordt nooit afgebroken | `hooks.json` → `180`, en de eenheid noemen in de kop van `install.sh`. Verifieer de eenheid eerst tegen de actuele documentatie; dit is een verdenking op basis van de docs, geen waargenomen schade | laag / klein |

---
### `fwd:plan` — 7 punten

Eén echte run in het hele archief (res-193). Die ene run legde meteen zeven dingen bloot.

| Wat er misging | Waarom het uitmaakt | Wat te doen | Impact / Werk |
| --- | --- | --- | --- |
| Bewijsregels worden verzonnen, nooit gedraaid | 2 van de 5 bewijsregels klopten niet: één grep matchte de geïnjecteerde fake in plaats van een echte aanroep, één verwees naar een testnaam die niet bestond. Beide staan nog in het contractbestand | Twee zinnen bij de bewijsregel-bullet: een commando over de huidige boom draai je één keer vóór het pinnen en zet je uitkomst erachter als nulmeting; noem geen identifier die nog niet bestaat | hoog / klein |
| "Skim alle rule-bestanden" wordt niet afgedwongen | Van vier regelbestanden werd er één geopend, waarna de skill beweerde er drie te hebben gelezen en er twee inhoudelijk citeerde. Die claims belanden ongecontroleerd in het contract | Vervang de skim-opdracht door `list-rules.sh` (cross-skill verwijzing, patroon bestaat al) plus een Read op elk teruggegeven bestand, en neem "Regels gelezen: <paden>" op in het contract | hoog / klein |
| 160 regels in één beurt met het advies onderaan | De gebruiker moet door drie volledige planblokken en wijzigingstabellen van 12-17 rijen scrollen voordat hij ziet wat wordt aangeraden — precies wat de beslis-eerst-les van 24 juli in `steps-run` heeft opgelost | Verplicht kopje "In 't kort" van 3-5 regels vóór alles; Style-bullet met een grens van ~120 regels en uitklappen op verzoek | hoog / klein |
| Basis-commit gaat uit van een exclusieve checkout | Halverwege bleek een tweede sessie in dezelfde repo bestanden te hebben aangeraakt én op dezelfde branch te hebben gecommit; de diff-toets is dan waardeloos | Leg bij het pinnen ook de toestand van de werkboom vast ("schoon" of "*n* bestanden al gewijzigd — paden") en trek die vooraf-vieze bestanden in de check-modus af | midden / klein |
| Het contract wordt nooit afgesloten | De check-modus is in het hele archief nul keer gedraaid; geen enkel contract heeft ooit een toets-uitslag gekregen. De correcties op de foute bewijsregels bleven in de chat hangen | Het contract moet zichzelf afdwingen: opdracht bóven de afvinklijst ("Draai `/fwd:plan check <slug>` vóór je commit"), plus een vierde checklistregel voor bewijsregels die tijdens de bouw niet bleken te deugen | midden / klein |
| "Eerst stress-testen" is een circulaire optie | Op dat punt bestaat er nog geen plan, alleen een Definition of Done; premortem weigert dan met "No plan found — run /fwd:plan first". Kiezen voor die optie gooit bovendien al het stap-1-onderzoek weg | Laat in 2c alleen grill-me staan, en verplaats de premortem-uitnodiging naar het einde van stap 4, náást de plan-keuze — daar ligt er wél een plan | midden / klein |
| README-beschrijving wijkt af van de frontmatter | Claude Code kijkt alleen naar de frontmatter; de skill vuurde niet op een verzoek dat inhoudelijk een planvraag was en de gebruiker typte zijn hele bericht opnieuw over met `/fwd:plan` erachter | Trek de rijkere README-tekst terug ín de frontmatter (die richting bedoelt de conventie) en zorg dat de echte triggerzinnen erin staan: "maak een plan", "hoe zou je dit aanpakken", "welke opties heb ik" | laag / klein |

### `fwd:grill-me` — 3 punten

| Wat er misging | Waarom het uitmaakt | Wat te doen | Impact / Werk |
| --- | --- | --- | --- |
| Een oude persoonlijke kopie overschaduwt de plugin-skill | De enige echte grill-sessie laadde `~/.claude/skills/grill-me` — een verouderde kopie zonder genummerde opties, zonder `QUESTION_FORMAT.md` en zonder het verbod om vragen te tellen. De sessie nummerde de vragen tóch, precies het gedrag dat op 9 juni is weggehaald | Opruimen: `rm ~/.claude/skills/grill-me` (en `caveman`). Plus één regel in CLAUDE.md: check bij het spiegelen uit `fwd-claude-code` of de naam al onder `~/.claude/skills/` bestaat | hoog / middel |
| Geen positie over `AskUserQuestion` | Alle twaalf vragen verschenen dubbel — eerst als markdown-kop, dan als dialoog met een andere formulering. Het gedocumenteerde `y`-antwoord bestond niet meer | Kies en schrijf het uit. Aanbeveling: dialoog toestaan, maar één vraag per aanroep, geen prozakop die hem herhaalt, en elke optie draagt zelf zijn uitleg | midden / klein |
| Geen eindcontract en geen tool-beperking | De skill maakte van de laatste vraag een procesvraag, kreeg "bouw het nu" terug en begon zelf productiecode te schrijven — terwijl de sessie met `/fwd:mission-plan` was begonnen | `allowed-tools` zonder `Write`/`Edit` (zoals premortem dat heeft), plus een slotsectie: samenvattingstabel van de keuzes, één regel over de logische vervolgstap, en stoppen | midden / klein |

### `fwd:jip-janneke` — 4 punten

Twee echte aanroepen, allebei in res-211. Beide keren werkte het resultaat, maar de skill werd genegeerd waar hij het meest nodig was.

| Wat er misging | Waarom het uitmaakt | Wat te doen | Impact / Werk |
| --- | --- | --- | --- |
| De triggers missen de manier waarop echt om gewone taal gevraagd wordt | *"ik snap er geen reet van wat je zegt"* en *"ik heb geen idee waar dit nou over gaat"* laadden de skill niet; het model schreef handmatig een uitleg of bouwde een HTML-pagina | Klachttriggers toevoegen aan de description, plus één zin in de stijl die `fwd:unsure` al heeft: ook als de gebruiker alleen klaagt dat hij het niet volgt, ís dat het verzoek | hoog / klein |
| `$ARGUMENTS` staat in een tabelkop en een kopregel | Bij invulling wordt de kolomkop een hele Nederlandse zin en heet de sectie "Empty ..." ineens naar het argument zelf; de instructie die het model leest is verminkt | Gebruik `$ARGUMENTS` alleen waar de invulling leesbaar blijft. Raakt ook `explain`, `unsure` en `premortem` | midden / klein |
| Vrije tekst wordt naar een codebase-grep gestuurd | Beide aanroepen gaven een beschrijvende zin mee; de resolutietabel stuurt dat naar "grep de codebase" terwijl het doelwit in het gesprek stond. Het model negeerde de tabel — het ging goed, maar toevallig | Eén rij toevoegen vóór de laatste: een zin die naar iets in het gesprek verwijst → pak dat blok uit de conversatie, geen grep. Zelfde rij in `explain` | midden / klein |
| Regel D werd met 66% overschreden | De herschrijving van een issue van 2.780 tekens werd 4.612 tekens, terwijl de skill belooft in te korten | Maak regel D toetsbaar in stap 4: tel regels van bron en herschrijving; is de herschrijving langer, schrap dan eerst toegevoegde tabellen en diagrammen — die tellen mee | laag / klein |

### `fwd:unsure` — 3 punten

| Wat er misging | Waarom het uitmaakt | Wat te doen | Impact / Werk |
| --- | --- | --- | --- |
| Geen tak voor "niets in het gesprek" | De enige echte aanroep was het eerste bericht van een verse sessie. De skill zocht plannen in de repo, zette ze in een tabel en vroeg "welke bedoel je?" — precies wat zijn eigen regel verbiedt | Eén zin bij `## Doelwit`: niets in het gesprek en geen pad → zeg in één regel dat er niets is om over te twijfelen en vraag om het plan. Niet zelf in de repo zoeken | hoog / klein |
| Trigger-kwaliteit is nooit gemeten | De optimizer draaide 20 testvragen, alle 20 scoorden 0 — ook de letterlijke match. De uitkomst is dus niet "goed" maar "onbekend": de testopstelling draait elke vraag in een lege sessie, terwijl deze skill juist over iets eerder in het gesprek gaat | Leg de fixture-variant vast (eerst plan plakken, dán de triggervraag) — in CLAUDE.md of als extra categorie in `skill-eval` — en draai hem eenmalig voor `unsure` en `jip-janneke` | laag / middel |
| README-rij loopt achter op de frontmatter | De bewust toegevoegde slotzin over de terloopse vraag staat wel in `SKILL.md`, niet in de README — terwijl CLAUDE.md voorschrijft dat die elkaar spiegelen | README aanvullen (één edit). Een `check-readme-descriptions.sh` in de vorm van `check-agent-norms.sh` is optioneel | laag / klein |

### `fwd:explain`, `fwd:caveman`, `fwd:handoff`, `fwd:premortem` — 8 punten

Deze vier zijn in de onderzochte sessies nul of één keer gebruikt. Zie ook deel 5.

| Wat er misging | Waarom het uitmaakt | Wat te doen | Impact / Werk |
| --- | --- | --- | --- |
| **explain** — nul keer geladen; de gebruiker vroeg twee keer om een HTML-explainer | Het chat-menu (`next` / `more` / `full` / `done`) is niet de vorm waarin uitleg wordt afgenomen | Klein en nu: triggers aanvullen ("maak een explainer", "leg uit wat X doet", "ik snap niet wat dit doet"). Apart te beslissen: na stap 3 de keuze tussen chatvorm en één uitlegpagina als Artifact | midden / middel |
| **explain** — dode verwijzing naar `/fwd:write-doc` plus een afgekeurde afbakeningsregel | Die skill bestaat niet meer, en zulke afbakeningsregels heeft de gebruiker eerder al uit `fwd:unsure` laten schrappen als ruis | Regel schrappen. Idem het afbakeningsblok in de body van `jip-janneke` — in de description mag het blijven, daar heeft het triggerwaarde | laag / klein |
| **explain + jip-janneke** — de gekopieerde resolutietabel is gedrift | `explain` mist de "nothing resolves"-rij, `jip-janneke` mist de stack-trace-rij, foutmeldingen verschillen, en `explain` gebruikt kaal `git diff` waar de repo-conventie `rtk git` eist | Doe nu de onbetwiste fix: `explain` regel 25 → `rtk git diff`. De-driften daarna, en alleen over deze twee — `premortem`'s tabel is géén kopie en zou een byte-identieke check meteen laten falen | midden / middel |
| **caveman** — dekt alleen antwoordstijl, niet "comprimeer dit document" | De gebruiker vroeg letterlijk om caveman toe te passen op een skillbestand; de skill werd niet geladen en het model verzon zelf de afbakening. Was hij wél geladen, dan had de Persistence-clausule de hele sessie op caveman gezet | Description uitbreiden met Nederlandse en document-triggers; onder `## Persistence` twee zinnen die de twee gebruiken scheiden: gespreksmodus is persistent, een aangewezen tekst comprimeren is eenmalig | midden / middel |
| **handoff** — geen doelwit-, uitvoer- of lengtecontract, en schrijft naar `/tmp` | Nul keer gebruikt, ook niet in de twee meerdaagse sessies waar wel handmatig werd overgedragen. Een overdrachtsdocument in `mktemp -t` bereikt de volgende sessie niet | Schrijf naar `.claude/handoffs/<slug>.md` (reist mee naar de volgende clone) of de scratchpad; triggerzinnen toevoegen; een vast beslis-eerst-sjabloon met lengtegrens | midden / middel |
| **handoff** — `mktemp -t handoff-XXXXXX.md` levert helemaal geen `.md`-bestand op | Op macOS neemt `mktemp -t` een prefix en plakt daar zelf een suffix achter; de X'en worden niet vervangen. Getest: het resultaat heet `handoff-XXXXXX.md.UJQ0ho4NW9`. Het enige artefact van deze skill heet dus letterlijk XXXXXX en eindigt niet op `.md` | Vervang door een vorm die wél een `.md` oplevert (`mktemp -d` plus een vaste naam erin). Schrap "read the file before you write to it" — `Write` op een nieuw pad volstaat — en laat de skill het absolute eindpad rapporteren | midden / klein |
| **caveman** — geen taalregel, terwijl alle compressieregels Engels-specifiek zijn | De regels dragen op Engelse lidwoorden en filler ("just/really/basically") te schrappen; alle voorbeelden zijn Engels. De modus blijft actief bij élk antwoord, dus hij bepaalt de uitvoertaal van de hele sessie — terwijl de standaard Nederlands is | Sectie "Language": caveman volgt de taal van de gebruiker; in het Nederlands vervallen de/het/een en gewoon/eigenlijk/even op dezelfde manier. Eén Nederlands voorbeeld naast de twee Engelse | midden / klein |
| **premortem** — nul keer gebruikt, en de enige route ernaartoe loopt vast | De skill wordt alleen aangeboden in `fwd:plan` 2c, op het moment dat er nog geen plan is om te premortemen | Voer de plan-fix door (uitnodiging naar het einde van stap 4). De openingszin is skill-afbakening in plaats van instructie — hooguit inkorten | laag / klein |

---
### `fwd:skill-eval` — 3 punten

| Wat er misging | Waarom het uitmaakt | Wat te doen | Impact / Werk |
| --- | --- | --- | --- |
| Nul aanroepen in de hele historie | De evaluaties die in dit project wél zijn gedaan, liepen als losse bash-checksets in de scratchpad — dus zonder pre-flight, zonder experimentmatrix, zonder undo. LESSONS noteert zelfs: *"Herdraaibare checkset: scratchpad eval-steps-run/e1..e13.sh"* | Kies expliciet. **(a)** Triggers verbreden naar wat er echt gezegd wordt ("test dit script", "draai een checkset op X", "controleer of de scripts nog doen wat de SKILL.md belooft") plus een lichte modus: 3-5 checks, geen matrix vooraf, geen dirty-tree-weigering. **(b)** Of schrappen en de checkset-praktijk als kort recept in CLAUDE.md vastleggen. (a) heeft pas zin als de twee punten hieronder ook gefixt zijn | hoog / groot |
| De pre-flight blokkeert zijn eigen tweede run | `tmp/eval/` wordt aangemaakt, maar de dirty-check weigert te starten bij een vuile tree. In elke repo waar `tmp/` niet gitignored is, is de sandbox van run 1 precies wat run 2 tegenhoudt — en de tree blijft vuil voor `git-commit`, `steps-run` en `mission-run` | Let op: `grep -v '^?? tmp/eval/'` werkt níet, want git vouwt de map samen tot `?? tmp/`. Filter op `^?? tmp/$` erbij, of gebruik `--untracked-files=all`. Zelfde filter in `cleanup.sh`. Plus één regel bij Prerequisites: `tmp/` moet gitignored zijn | midden / klein |
| Gedocumenteerde exit-code 7 bestaat nergens | De skill preekt dat elke gedocumenteerde exit-code een claim is die moet kloppen; zijn eigen tabel noemt code 7 terwijl `cleanup.sh` onvoorwaardelijk 0 teruggeeft | Splits de tabel per script (preflight: 0/5/6; cleanup: 0) met de skill-uitkomst apart, en haal rij 7 weg — óf laat `cleanup.sh` echt `exit 7` doen bij een mislukte verwijdering. Goedkoopste test van de eigen leer van de skill | laag / klein |

---

## Deel 3 — Per agent

Zes agentbestanden. Drie patronen komen bij meerdere agents terug: **het voorbeeld verslaat de regel**, **read-only is een belofte die de toolset niet afdwingt**, en **de agentdefinitie kent zijn eigen invoer niet** (de orchestrator geeft meer mee dan het bestand beschrijft).

De drie mission-agents `coder`, `reviewer` en `user-tester` kregen geen enkele bevinding uit de sessies. Dat bleek een blinde vlek: bij directe lezing leverden ze vijf hoog-impactpunten op — ze zijn simpelweg minder vaak gedraaid dan de steps-agents.

**Doorgevoerd op 22 augustus:** alle punten met impact *hoog* in dit deel, plus enkele kleine die in dezelfde bewerking vielen (de fence-notitie in vijf agentbestanden, "nooit rood committen" bij de coder, de gate-resultaten in de invoerlijst van de reviewer, en een schrijfstijlsectie voor de user-tester). De punten met impact *midden* die daar niet bij zaten, staan nog open. Eén bevinding is inmiddels door ander werk ingehaald: `mission-scribe` heeft nu wél een taalnorm — het gedeelde blok `## Gedeelde taalregel` staat er, bewaakt over acht bestanden.

### `mission-coder.md`

| Wat er misgaat | Waarom het uitmaakt | Wat te doen | Impact |
| --- | --- | --- | --- |
| Vertrouwt op een `cd` die tussen Bash-calls niet standhoudt | De agent krijgt "`cd` into it first" en gebruikt daarna kale git-commando's. In deze harness wordt de cwd van een agent-thread tussen calls gereset, dus `rtk git add`/`commit` in een latere call landt in de hoofd-checkout. Dit is precies de fout die LESSONS 8 juli beschrijft (twee coders committeerden op `main`). `mission-reviewer` lost het correct op met `-C`, `steps-plan` met een subshell binnen één call — de coder is de enige die erop vertrouwt én de enige die schrijft | Alle git-commando's als `rtk git -C <WT> …`, alle paden absoluut, plus één verbod: "Never rely on a previous `cd` — every Bash call starts fresh" | hoog · ✅ doorgevoerd |
| Design budget en reading list ontbreken in "What you are given" | De orchestrator pint beide verplicht in de spawn-prompt, en de reviewer faalt een staande design-budget-VC hard op elke dependency of abstractie erbuiten. De coder wordt dus afgerekend op een contract dat zijn eigen specificatie niet noemt — sterker, stap 1 draagt juist een repo-brede scan op die de reading list moet voorkomen | Twee bullets toevoegen (design budget bindend, reading list als enige oriëntatiescope) en stap 1 herschrijven: lees precies de reading list; alleen als die ontbreekt, lees de relevante bestaande bestanden | hoog · ✅ doorgevoerd |
| Geen norm die verbiedt om rood te committen | Stap 4 zegt alleen "leg de exit codes vast — you report these"; stap 5 (committen) volgt onvoorwaardelijk. Een eerlijke coder mag dus `exit_code: 1` rapporteren *en* committen | Stap 4: "A non-zero exit code is a stop, not a note" — fixen, of niet committen en de fout in `left_undone` zetten | midden |
| `narrative` is verplicht in de agent maar ontbreekt in het handoff-schema | `REFERENCE.md` kondigt "the five core fields" aan en toont er zes; `narrative` staat er niet bij, terwijl de agent het als eerste verplichte veld voert | Rij toevoegen bovenaan de handoff-tabel en "five" corrigeren naar "six" op twee plekken | midden |

### `mission-reviewer.md`

| Wat er misgaat | Waarom het uitmaakt | Wat te doen | Impact |
| --- | --- | --- | --- |
| Het `advisories`-kanaal loopt dood | De reviewer moet advisories teruggeven en het eindrapport belooft ze te tonen, maar de payload naar `record-validation.sh` kent het veld niet en de scribe krijgt ze niet mee — terwijl zijn sjabloon wél een advisories-sectie heeft. Elke advisory van een Opus-reviewer verdampt na het schrijven van het reviewbestand | Kies één route en maak hem af: `advisories` in de payload (analoog aan `concerns`) plus in `REFERENCE.md`, óf verbatim in de scribe-prompt pinnen. Anders het veld uit de reviewer schrappen | hoog · ✅ doorgevoerd |
| Geen uitsluiting van de mission-metadata | `steps-reviewer` heeft die regel wél. De reviewer mag een `<base-sha>..<head-sha>`-bereik krijgen, en daarin zitten de checkpoint-commits van `record-feature.sh`. De staande comment-hygiëne-VC scant óók commit messages op feature-ID's — en de checkpoint heet letterlijk `chore(mission): checkpoint F1 done`. Die VC faalt dan gegarandeerd op het orkestratiewerk zelf | Dezelfde regel als in `steps-reviewer`, met het juiste pad: negeer alles onder `.claude/missions/**` en elke commit met `chore(mission):`. Geef de scribe dezelfde uitsluiting | hoog · ✅ doorgevoerd |
| "Structurally cannot modify code" is onwaar | De allowlist is `Read, Glob, Grep, Bash` — en Bash kan schrijven. CLAUDE.md noemt reviewer en user-tester "write-incapable validators"; dat is gedragsmatig, niet structureel | Herformuleer naar wat waar is, en overweeg `disallowedTools` voor het mutatie-oppervlak | midden |
| Verbod op stagen en committen ontbreekt | `steps-reviewer` verbiedt "modify, stage, or commit"; de mission-reviewer verbiedt alleen wijzigen. `rtk git add`/`commit` wijzigen geen bestanden en vallen dus buiten de letter — en `record-feature.sh` bepaalt de frontier aan de hand van commits | Trek de steps-formulering door naar alle drie de validators, bij voorkeur in het bewaakte gedeelde blok | midden |
| Gate-resultaten en het "niet opnieuw draaien"-bevel staan niet in de agent | De orchestrator pint beide verplicht in de prompt; de agentdefinitie noemt ze niet en zegt juist alleen dat gates apart draaien | Twee bullets bij "What you are given", en de regel expliciet maken: draai de volledige suite niet opnieuw zolang de SHA gelijk is; alleen gerichte tests bij concrete twijfel | midden |

### `mission-user-tester.md`

| Wat er misgaat | Waarom het uitmaakt | Wat te doen | Impact |
| --- | --- | --- | --- |
| Geen kanaal voor defecten buiten de meegegeven assertions | De reviewer heeft een harde regel dat een gevonden gebrek nooit als terzijde geparkeerd mag worden, en een veld om het in te leggen. De user-tester heeft alleen `narrative` en `verdicts`. Ziet hij een 500 op een niet-geasserteerd endpoint of een crash bij lege invoer, dan is de narrative de enige plek — precies het parkeren dat bij de reviewer verboden is. En de remediatiepas wordt daar niet door getriggerd | `concerns` toevoegen met dezelfde harde regel, opnemen in de payload (samengevoegd met de reviewer-concerns) en de remediatie-trigger uitbreiden | hoog · ✅ doorgevoerd |
| Playwright-artefacten maken de worktree vuil | `test-results/` en `playwright-report/` vallen buiten de schone-boom-filter van `record-feature.sh` en blokkeren dus de volgende feature | Regel toevoegen: schrijf elk artefact buiten de repo (`$TMPDIR`), laat de worktree achter zoals je hem aantrof. Eventueel als vangnet de twee mappen in de filter opnemen | midden |
| Geen worktree-discipline | De invoerlijst noemt het worktree-pad en stap 1 draagt op de smoke-commando's te draaien — die zijn vrijwel altijd relatief aan de projectroot. Nergens staat hoe de agent daar komt; met de cwd-reset draaien ze in de hoofd-checkout | "Elk commando draait binnen de worktree — prefix elke Bash-call met `cd <worktree> && …` in dezelfde call" | midden |
| Geen schrijfstijl- of taalnorm voor de narrative | `mission-coder` en `mission-reviewer` hebben elk een volledige stijlsectie; de user-tester heeft niets, terwijl zijn narrative rechtstreeks in het walkthrough belandt | Kopieer de sectie uit `mission-reviewer.md` verbatim, met QA-woordkeus | midden |

### `steps-reviewer.md` en `steps-doubt.md`

| Wat er misgaat | Waarom het uitmaakt | Wat te doen | Impact |
| --- | --- | --- | --- |
| De reviewer draait `git stash` op de live worktree | Onbeoordeeld werk van de gebruiker staat erin; crasht de agent tussen stash en pop, dan is het weg | Schrijfoperaties op tree en index expliciet verbieden; wil hij code weglaten om een effect te isoleren, dan naar een tmp-kopie buiten de worktree — precies wat een latere reviewer wél deed | hoog · ✅ doorgevoerd |
| De reviewer krijgt het plan niet en kraakt een seam die het plan eist | Kostte een extra rapport, een lang verweer en een begripsvraag van de gebruiker | Plan-pad toevoegen aan de prompt; een seam uit `plan.md` of de DoD mag nooit `yagni` krijgen — alleen de bouwwijze is te beoordelen | hoog · ✅ doorgevoerd |
| Geen slot voor commando-bewijs | Bij een lege diff heeft de agent geen opdracht en de orchestrator geen veld, dus improviseert het model "niet van toepassing" — tegen de eigen regel in | Lege diff is legitiem bij een `command`-criterium; `command_proof` toevoegen, `test_quality` nullable | midden |
| `steps-doubt` diff't in autonome runs tegen een bewegende branch-naam | Loopt de basisbranch door, dan telt vreemd werk mee als "de tranche". Exact de fout die LESSONS 24 juli beschrijft en die in `mission-run` wél is gefixt | Merge-base-anker, net als de attended variant in diezelfde regel al doet | midden |

### `mission-scribe.md`

| Wat er misgaat | Waarom het uitmaakt | Wat te doen | Impact |
| --- | --- | --- | --- |
| Geen taal- of schrijfstijlnorm | De walkthrough zat vol Dunglish ("de ophaaling", "gebrauikt", "227 lines"); de orchestrator herschreef alles — precies het werk dat de scribe zou overnemen. Draait op Haiku, dus juist daar is een expliciete norm nodig | Blok `## Schrijfstijl` met dezelfde regel als de siblings, Nederlandse vaktermen, spellingcontrole vóór teruggeven. Naar Sonnet tillen is een aparte, duurdere keuze | hoog · ✅ doorgevoerd |
| Levert de walkthrough dubbel op | Eerst als markdown-proza, daarna nog eens in een `json`-fence — de hele tekst twee keer over de lijn | Fence-fix plus een machinaal toetsbare regel: je laatste bericht begint met `{` en eindigt met `}` | midden |
| Valt buiten `check-agent-norms.sh` | Het script meldt tevreden "identiek over 5 bestanden" terwijl er zes agents zijn. De scribe voert dezelfde twee normen, maar geparafraseerd onder een andere kop — dus die kopie kan stilzwijgend afdrijven | Geef hem het echte blok verbatim en zet hem in de lijst. Beter: laat het script de agents zelf ontdekken, dan valt een nieuwe agent nooit buiten de bewaking | midden |

### Wat alle drie de JSON-agents delen

`mission-coder`, `mission-reviewer` en `mission-user-tester` zeggen alle drie "exactly one JSON object — no prose around it, no code fence" en zetten hun voorbeeld direct daarna in een ```` ```json ````-fence. Hetzelfde geldt voor `steps-reviewer`, `steps-doubt` en `mission-scribe`. In elk waargenomen geval won het voorbeeld van de regel.

**Twee maatregelen.** In de agentbestanden: presenteer het voorbeeld als geïndenteerde regels, of zet erboven "de fence hieronder is uitsluitend illustratie — jouw uitvoer begint met `{` en eindigt met `}`". In de orchestrator: strip een eventuele fence defensief vóór het parsen, en vraag bij ongeldige JSON één keer terug in plaats van het oordeel zelf in te vullen.

---

## Deel 4 — Repo-breed

### Vier structurele patronen

**1. Hand-gekopieerde blokken lopen uiteen.** `check-agent-norms.sh` bewaakt precies twee blokken en vijf van de zes agents. Alles daarbuiten is al gedrift: `mission-run/scripts/risky-scan.sh` belooft dezelfde patronen als `git-commit/scripts/pre-flight.sh` maar mist de log-bestandcheck; de resolutietabel van `explain` en `jip-janneke` verschilt op vijf punten, waaronder kaal `git` versus `rtk git`; `mission-scribe` draagt het gedeelde blok geparafraseerd onder een andere kop en valt daardoor buiten de controle. Het script kán meer blokken en bestanden aan zonder wijziging — het wordt er alleen niet op aangeroepen.

**2. Het voorbeeld verslaat de regel.** Zes agentbestanden zeggen "geen code-fence" en tonen hun voorbeeld in een fence. In alle waargenomen gevallen won het voorbeeld. Dezelfde klasse als de grill-me-anker-les van 9 juni: een hardgecodeerd voorbeeld werkt als anker, ook als de regel het tegendeel zegt.

**3. Read-only is een belofte, geen mechanisme.** `steps-reviewer`, `mission-reviewer`, `mission-user-tester` en de twee codex-skills claimen structureel niets te kunnen wijzigen. Alle vijf hebben `Bash`. In twee gevallen is het aantoonbaar misgegaan: een `git stash` op de live worktree, en een heredoc die een bestand overschreef. De belofte moet ofwel kloppen (via `disallowedTools`), ofwel anders geformuleerd worden.

**4. Bekende bugs blijven bewust liggen — en vallen daarna stil.** Drie bugs staan sinds 9 juli als "bewust uitgesteld" in `LESSONS.md` en zijn vandaag nog aanwezig:

| Bug | Waar | Sinds |
| --- | --- | --- |
| `-d tests` geldt als Python-signaal, dus `pytest`/`ruff`/`mypy` worden aangeboden in een Node-repo | `steps-plan/scripts/discover-gates.sh:45` én `mission-plan/scripts/discover-gates.sh:45` | 9 juli |
| `rtk git add -A` schrijft naar stdout en vervuilt het gedocumenteerde `key=value`-contract | `steps-run/scripts/record-step.sh:79`, `finalize-autonomous.sh:31` (`snapshot-worktree.sh:19` doet het wél goed met `>&2`) | 9 juli |
| Risky-scan mist `-uall` | `git-commit/scripts/pre-flight.sh:35` | 9 juli |

Overweeg een vaste regel: een "bewust uitgesteld"-notitie krijgt een eigenaar en komt terug op de eerstvolgende opruimronde, óf wordt bewust gesloten als "niet doen".

### Testdekking

Van de 40 scripts onder `skills/*/scripts/` worden er **6 door een test aangeraakt** — allemaal in `steps-run`. Alle 21 mission-scripts staan zonder test, inclusief de `state.json`-muterende jq-scripts (`record-feature`, `record-validation`, `reconcile`, `pick-next-unit`, `finalize`). Dat zijn precies de scripts waar het juli-review en LESSONS drie keer een stille corruptie hebben gevonden (frontier-volgorde, merge-base-anker, metadata-commit als `commit_sha`).

De bestaande harness draait groen (`tests: 7 · pass: 7 · fail: 0`). Trek `tests/lib.sh` door naar `mission-run/tests/`, te beginnen bij `record-feature.sh` en `reconcile.sh`.

### Registratie en documentatie

| Wat | Bewijs | Wat te doen |
| --- | --- | --- |
| `plan-with-doc` staat niet in `plugin.json` en niet in de README | 19 skillmappen, 18 registraties; de skill is niet aanroepbaar | Zie deel 1, punt 9. Halfweg laten staan is de slechtste van de twee opties |
| README-beschrijving van `fwd:plan` is volledig verouderd | Frontmatter is ingekort tot één regel, README draagt nog de oude versie van ~900 tekens. Claude Code triggert op de frontmatter | Kies welke van de twee de waarheid is; is de lange tekst de bedoeling, dan hoort die in `SKILL.md` |
| README mist stukken van `fwd:setup`, `fwd:unsure` en `fwd:jip-janneke` | Bij `unsure` ontbreekt de slotzin over de terloopse vraag; bij `jip-janneke` de drie afbakeningszinnen; bij `setup` een herformulering in plaats van een kopie | README-cellen letterlijk gelijkmaken aan de frontmatter |
| Dode verwijzing `/fwd:write-doc` in `fwd:explain` | Die skill bestaat niet meer in deze plugin | Schrappen (of vervangen als `plan-with-doc` blijft) |
| `marketplace.json` noemt de steps-agents niet | De mission-agents staan er wel in | Aanvullen of het veld weglaten — nu suggereert het een onvolledige set |
| `repo-structure.md` beschrijft een andere repo | Verwarrend voor wie de repo binnenkomt | Bijwerken of verwijderen |
| CLAUDE.md's naamconventie klopt niet met de helft van de skills | De regel schrijft `<veld-of-context>-<naam>` voor; `plan`, `setup`, `caveman`, `explain`, `handoff`, `premortem`, `unsure` en `jip-janneke` volgen dat niet | Conventie bijstellen naar de praktijk ("een samengestelde naam als er een familie is") in plaats van andersom |
| CLAUDE.md's regel "alle git via rtk" kent een niet-gedocumenteerde uitzondering | Machine-geparste reads gebruiken `grep -vx 'ok'`-workarounds; GAP-24 stelt voor daar plain `git` te gebruiken | Documenteer de uitzondering zodra GAP-24 wordt opgepakt |
| Drie scripts hebben geen `set`-opties, en er lopen twee conventies naast elkaar (`set -euo` en `set -uo`) | Alle andere scripts openen wel met een set-regel | Uniformeren en de keuze in CLAUDE.md vastleggen |
| Eén productiescript en alle tests staan op `644` | Niet uitvoerbaar zonder `bash <pad>` | `chmod +x` |
| Niets controleert registratie of README-rijen | `scripts/` bevat alleen `check-agent-norms.sh` | Optioneel `check-registration.sh` in dezelfde vorm. Doe de losse fixes eerst |

---

## Deel 5 — Wat nog open staat uit het juli-review

`docs/reviews/2026-07-02-mission-skills-review.md` telde 27 bevestigde gaten. Getoetst tegen de huidige repo: **20 dicht, 7 deels, 0 volledig open**. De zeven resterende zitten op één na allemaal in `fwd:mission-run`.

| Gat | Wat nog ontbreekt |
| --- | --- |
| GAP-12 / GAP-27 | `attempts` en `started_at` worden pas bij het vastleggen gezet, niet bij de spawn — een gecrashte poging blijft onzichtbaar. Voorstel: een apart events-bestand buiten de dirty-check, zodat de clean-worktree-eis intact blijft |
| GAP-13 | Geen "onbewezen"-verdict naast pass/fail; `status.sh` mist de rollup `verdicts: N pass / N fail / N onbewezen` en `list-missions.sh` laat onbewezen milestones stil uit de teller vallen. Ook de plan-kant mist de assertion-regel "verifieerbaar vanuit de worktree" |
| GAP-24 | Machine-geparste git-reads lopen nog via `rtk` met `grep -vx 'ok'`-workarounds; voorstel was plain `git` daarvoor, plus een uitzonderingsregel in CLAUDE.md |
| GAP-25 | `setup-worktree.sh` provisioneert geen draaibare omgeving. Ditzelfde gat is nu ook in `steps-run` waargenomen (de `.venv`-bevinding hierboven) — één fix dekt beide |
| GAP-26 | Geen `trap … EXIT` op tmp-schrijvende scripts, geen weigering van een lege `vc_results`-payload, geen regressieharnas voor de mission-run-scriptsuite |
| GAP-29 | Geen WIP-checkpoint-conventie die `reconcile.sh` kan onderscheiden van een feature-done-commit; de sizing-regel mist een splits-actie voor te grote features |

---

## Deel 6 — Skills die niemand gebruikt

Vier skills zijn in de onderzochte periode nul keer geladen, en dat is op zichzelf een bevinding.

| Skill | Wat er in plaats daarvan gebeurde | Gok waarom |
| --- | --- | --- |
| `fwd:skill-eval` | Evaluaties liepen als losse bash-checksets in de scratchpad | De triggerzinnen ("self-evaluate skill X", "shake down skill X") worden niet gebruikt, en de flow is zwaarder dan de ad-hoc check die in het werk nodig blijkt |
| `fwd:explain` | De gebruiker vroeg twee keer om een HTML-explainer en het model bouwde die zelf | Het chat-menu is niet de gewenste vorm; de triggers dekken "ik snap het niet" niet |
| `fwd:handoff` | In twee meerdaagse sessies werd handmatig overgedragen | Geen triggerzinnen in de description, en het document belandt in `/tmp` |
| `fwd:premortem` | Alleen aangeboden in `fwd:plan` 2c — op het moment dat er nog geen plan is | De enige route ernaartoe loopt vast op de skill zelf |

Dat is geen bewijs dat ze waardeloos zijn: het zijn vier verschillende oorzaken (verkeerde triggers, verkeerde uitvoervorm, geen instap, verkeerde opslagplek). Per skill is de keuze: repareren zoals hierboven beschreven, of schrappen. Ik zou `explain`, `handoff` en `premortem` repareren — het zijn kleine ingrepen — en over `skill-eval` een bewuste beslissing nemen, want dat is de enige met een grote ingreep.

---

## Deel 7 — Voorgestelde volgorde

Vier tranches. De eerste is een halve dag werk en haalt de scherpe randen eruit; de rest is te doen wanneer het uitkomt.

**Tranche 1 — veiligheid en blokkades (klein, doe dit eerst)**
`steps-reviewer` mag niet meer in de tree schrijven · `pre-flight.sh` krijgt `-uall` · `merge-json.sh` schrijft niet zonder `jq` · setup meldt getrackte bestanden · het trailer-verbod verhuist naar `## Safety` · `record-step.sh` krijgt `--state-only` · `mission-coder` krijgt `-C <WT>` in plaats van `cd` · `plan-with-doc` weg.

**Tranche 2 — beloftes die niet kloppen (klein, veel tekst)**
De `--background`-belofte · "structurally cannot modify" in drie bestanden · de fence-in-het-voorbeeld in zes agentbestanden · het doodlopende `advisories`-kanaal · de metadata-uitsluiting voor `mission-reviewer` · de dode `/fwd:write-doc`-verwijzing · de README-cellen gelijkmaken.

**Tranche 3 — gaten die werk kosten in een echte run (middel)**
Gate-nulmeting en `env-missing`-detectie in `steps-run` · drift-signalering op de basisbranch (steps én missions, één mechanisme) · `discover-gates.sh` zonder valse Python-gate · plan-inhoud versus pad in de codex-skills · de resolver die dode missions kiest · de omvang-poort in `mission-plan`.

**Tranche 4 — beslissingen, geen fixes**
Wat doen we met `skill-eval`? · Krijgt `explain` een Artifact-uitvoer? · Trekken we de testharnas door naar `mission-run`? · Laten we `check-agent-norms.sh` de agents zelf ontdekken? · Herzien we de naamconventie in CLAUDE.md naar de praktijk?

---

## Bijlage — waar het bewijs vandaan komt

De zwaarst gebruikte sessies, voor wie een bevinding wil natrekken:

| Project | Sessie | Wat erin zit |
| --- | --- | --- |
| poc-contract-clause-chunking | `762d1991` | Volledige attended steps-run van 6 stappen; bron van de `git stash`-, gate-basislijn- en 66-minuten-bevindingen |
| res-193-research-team | `a699c21f`, `ef1c416e` | Twee steps-runs met basisdrift, ontbrekende `.venv` en de globale pytest-installatie |
| res-193-research-team | `ab040edb` | Mission-run met adoptie, Dunglish-walkthrough en de merge die de administratie meenam |
| res-193-research-team | `efad0f6f` | De enige echte `/fwd:plan`-run — bron van alle zeven plan-bevindingen |
| Lely poc-hello-world-deployment | `677a4b40` | Mission-plan met veertien keuzevragen; ook de grill-me-schaduwkopie |
| Lely ai-prototyping | `27a95ea4` | `/fwd:setup` in een gedeelde bedrijfsrepo |
| res-211-context-compaction | `224e4565`, `997eb72c`, `50215ab2` | Codex-reviews en beide jip-janneke-aanroepen |
| poc-lely-knowledge-benchmark | `e3e4844d` | De codex-review-implementation die een dode mission als scope koos |

Transcripts staan in `~/.claude/projects/<project-slug>/<sessie-id>.jsonl`; subagent-transcripts in de gelijknamige submap onder `subagents/`.
