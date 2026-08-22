# Lessons

Persistent learnings from prior sessions. Append-only, newest at the bottom.

## Format

````
### YYYY-MM-DD | <type> | <scope>
**Context**: ...
**Observation**: ...
**Lesson**: ...
````

- **type**: correction | insight | rule-gap | deviation
- **scope**: free-form — skill (e.g. `fwd:git-commit`), area (`engineering`), or `general`

## Entries

<!-- new entries appended below -->

### 2026-06-02 | rule-gap | fwd-skills
**Context**: Building the fwd:mission-* skills, which are the repo's first to ship subagents (coder, reviewer, user-tester).
**Observation**: CLAUDE.md documented only `skills/` — nothing about how a plugin ships agents, so the convention had to be re-derived from the Claude Code docs.
**Lesson**: Plugin subagents live at the plugin root in `agents/<name>.md`, are auto-discovered (NOT listed in `plugin.json`), and are referenced via `subagent_type` as `fwd-skills:<name>`. Plugin agents ignore `hooks`/`mcpServers`/`permissionMode` (stripped on load). Scope read-only agents with a `tools` allowlist (omit `Write`/`Edit`). Now documented in CLAUDE.md "## Agents".

### 2026-06-03 | insight | fwd:mission-run
**Context**: The mission scripts passed every milestone test in a scratch repo, but a branch review found they broke in real use.
**Observation**: Tests ran scripts from the MAIN checkout, while the skill runs them after cd-ing into the worktree — where `git rev-parse --show-toplevel` returns the worktree and doubles derived paths. Separately, a "did the coder commit?" check used `git rev-list --count`, which counts metadata checkpoint commits and false-passes a no-op coder.
**Lesson**: Test a script from the cwd it actually runs in (the worktree, not just main). Resolve the main repo via `--git-common-dir` so scripts are cwd-independent. To prove real work happened, diff for code changes (excluding metadata paths), never count commits.

### 2026-06-09 | insight | fwd:grill-me
**Context**: fwd:grill-me almost always asked 11–12 questions regardless of how complex the grilled plan was. The skill instructed the model to "estimate the total number of questions" upfront and prefix each as `Question N/~total:`, and the QUESTION_FORMAT.md template hardcoded the example `Question 3/~12:`.
**Observation**: A hardcoded example number in a skill template acts as an anchor — the model reproduced ~12 every time it consulted the template — and the "estimate the total upfront" instruction turned that estimate into a self-fulfilling contract the model padded to reach. Together they converted an open-ended interview into a "fill the quota" exercise.
**Lesson**: Keep illustrative templates count-free, and don't make a skill commit to a quantity before it knows the work. For open-ended/iterative skills, state termination as a goal ("until every branch is resolved / nothing material is ambiguous"), not a number, and add explicit "few … many more" range cues to break any residual anchor. Applies to any skill in this repo that embeds example counts.

### 2026-06-10 | insight | fwd:mission-run
**Context**: First live mission run (parallel-mission-runner), recording features per SKILL.md step 2.4
**Observation**: record-feature.sh's clean-tree check rejects exactly what the documented flow produces: the untracked handoffs/<fid>.md the orchestrator writes before recording, and the state.json left dirty on purpose by log-decision.sh — even though the script itself stages .claude/missions/<slug> right after the check
**Lesson**: Either exclude .claude/missions/<slug>/ from the clean check in record-feature.sh, or document that the orchestrator must commit handoff + decision writes as a chore(mission) commit before calling record-feature.sh (current workaround)

### 2026-06-10 | insight | fwd-skills/scripts
**Context**: Writing the parallel-runner scripts and harness (mission parallel-mission-runner, M2)
**Observation**: Two recurring traps: rtk git emits literal ok lines on quiet/clean operations so any porcelain/output parser must filter them (grep -vx ok), and bare rtk git resolves the repo from cwd so scripts invoked from outside a git tree silently hit the wrong repo
**Lesson**: In fwd-skills bash helpers, always filter rtk ok lines when parsing git output and pass -C <path> (or cd in a subshell) for every git op that must target a specific worktree

### 2026-06-11 | insight | rules-driven-missions
**Context**: F9 coder self-verified VC-20 with a grep for CONTEXT.md mentions across the six audit files and reported 6/6 present; the adversarial reviewer failed the milestone because the reviewer agent's only CONTEXT.md mention pointed at the advisories vocabulary entry, not the required Schrijfstijl block
**Observation**: A loose proxy grep (any CONTEXT.md mention) false-passed a compliance check that required a specific marker (a Schrijfstijl missions reference)
**Lesson**: When self-verifying per-file compliance criteria, grep for the specific required marker verbatim (e.g. Schrijfstijl), never a broad proxy like the filename being referenced — and treat each clause of a multi-file VC as its own check per file

### 2026-06-11 | rule-gap | fwd:mission-run
**Context**: Orchestrating mission jip-janneke-skill per SKILL.md: write handoff narrative, log decisions, then record-feature.sh
**Observation**: record-feature.sh's clean-worktree check rejects the pre-written handoff narrative AND the state.json edit made by log-decision.sh (its exclusions cover only .env*/boot artifacts, not .claude/missions/<slug>), yet the script itself git-adds that dir at commit time — the documented orchestrator order trips the recorder
**Lesson**: Record first with a clean tree (commit_sha stays the coder's commit), then write the narrative / re-log decisions and amend the checkpoint commit; or fix the scripts to exclude .claude/missions/<slug> from the dirty check

### 2026-06-26 | rule-gap | fwd:mission-* (coder/reviewer comments)
**Context**: A real mission worktree (sandbox-usecase-prototype) shipped code whose test docstrings and comments referenced mission-internal codes — `# VC-4a: …`, `"""Tests voor F3 … (VC-5)"""`, and even `# … in de pre-F4 implementatie zat`.
**Observation**: The coder receives the VC-IDs/feature-IDs verbatim as the feature's "definition of done" and naturally threads them into comments as requirement-traceability. CONTEXT.md's "Vertaal interne codes; dump ze niet rauw" rule covered only reports/walkthroughs/handoffs, never code comments — so nothing forbade it, and the reviewer had no VC to fail it on.
**Lesson**: Comments must describe what/why and read standalone — never mission-internal codes (F#/M#/VC-IDs) or history references ("pre-F4"). Fixed in three places: CONTEXT.md's new "Codecommentaar" block (the norm), the coder agent (told the IDs are internal-only input), and a standing comment-hygiene scrutiny-VC that mission-plan generates per milestone so the reviewer fails violations hard. General pattern: when an agent is handed internal identifiers as input, state explicitly whether they may appear in its output.

### 2026-07-03 | insight | fwd:steps-* (skill-ontwerp)
**Context**: Bouw van de steps-familie (attended tegenhanger van missions). Bas scherpte tijdens de bouw twee eisen aan: "ik wil nog een check of je echt goed naar ponytail hebt gekeken — ik vind eenvoudige code erg belangrijk", en een tussenbalans na elke 4 stappen met twee zelftwijfel-vragen via caveman-subagents.
**Observation**: Een eenvoud-discipline als samenvatting opnemen ("gebruik de Lazy Ladder") is voor Bas te dun; hij wil de volledige discipline aantoonbaar verwerkt. Periodieke twijfel-momenten ("What are you least confident about?" / "What am I missing?") wil hij als vast ritme in attended loops, niet ad hoc.
**Lesson**: Bij code-genererende skills: neem eenvoud-regels letterlijk en volledig op (ladder verbatim, oorzaak-boven-symptoom, geen ongevraagde abstracties, saai boven slim, safety floor) — niet parafraseren. En bouw periodieke zelftwijfel-reviews in: deterministische trigger in bash (done % 4), oordeel bij verse read-only subagents, consolidatie in helder Nederlands bij de orchestrator.

### 2026-07-03 | insight | fwd:mission-run (reconcile/record-feature)
**Context**: Tranche 3 voegde een concern-remediatiepas toe die mid-milestone een feature opnieuw laat coderen + committen. Een adversariële verificatie-workflow vond dat `reconcile.sh` en `record-feature.sh` de "frontier" (laatste vastgelegde code) berekenden als `[.features[].commit_sha] | last` — de array-volgorde-laatste, niet de git-nieuwste.
**Observation**: Die aanname (features committen in array-volgorde) breekt zodra een remediatie een niet-laatste feature opnieuw vastlegt: diens commit_sha schuift vóór de array-laatste, maar de frontier blijft achter. Gevolg: bij de volgende /loop-tick zag `reconcile.sh` de remediatie-commit als "un-recorded code" en adopteerde een ongebouwde volgende feature als `done`. Crashloos reproduceerbaar aan de milestone-grens.
**Lesson**: Een "laatste vastgelegde commit"-frontier moet de git-nieuwste zijn (max over `rtk git rev-list --count <sha>`), nooit array-volgorde, zodra een record out-of-order kan gebeuren. Fixture: multi-feature milestone, remediatie op een niet-laatste feature → reconcile moet no-op zijn; én de normale adopt-case moet intact blijven. Bij elke nieuwe pas die code committeert: leg die commit meteen vast via `record-feature.sh` (verzet frontier, hoogt attempts op) — anders krimpt het crash-adoptievenster niet mee.

### 2026-07-08 | insight | fwd:steps-run (worktree) / general
**Context**: fwd:steps-* omgebouwd zodat de uitvoering in een worktree draait (op verzoek van Bas, voor parallel werk). `status.sh` moest plannen enumereren over `steps/*`-branches; ik gebruikte `rtk git branch --list 'steps/*' --format='%(refname:short)'`.
**Observation**: rtk mangelt de output van `git branch` — de `--format` wordt genegeerd en je krijgt de gedecoreerde branch-lijst terug (`* ` / `  steps/x`), waardoor slug-parsing (`${br#steps/}`) faalt en elk plan als "corrupt-of-onleesbaar" verscheen. `list-missions.sh` deed het daarom al met `for-each-ref`.
**Lesson**: Voor een machinaal leesbare branch-lijst onder rtk: gebruik `rtk git for-each-ref --format='%(refname:short)' 'refs/heads/<prefix>/*'` (schone output), nooit `git branch --list --format`. Steps-ontwerp: worktree ≠ subagent — de hoofdsessie kan prima zelf in `.trees/steps/<slug>/` schrijven; missions gebruiken een coder-subagent voor context-hygiëne bij lang onbeheerd werk, niet vanwege de worktree. Getest via wegwerp-repo (init→plan→setup-worktree→status, plus resume-na-verwijderde-worktree).

### 2026-07-08 | insight | mission-laag-versnellen
**Context**: F1 verplaatste normblokken uit CONTEXT.md inline naar 5 agent-definities.
**Observation**: Het hand-gecondenseerde schrijfstijl-blok in fwd-mission-reviewer.md liet twee bronnormen vallen (In-een-oogopslag-opening en taal-van-de-gebruiker); de reviewer ving dit als VC-3-fail.
**Lesson**: Bij het inline zetten van een norm: vergelijk bullet-voor-bullet tegen de bron en laat geen enkele regel vallen — parafrase mag, weglaten niet. Houd meerdere inline kopieen van dezelfde norm identiek.

### 2026-07-08 | insight | mission-laag-versnellen
**Context**: fwd-mission-coder kreeg een worktree-pad met de instructie erin te cd'en en te committen.
**Observation**: Twee coders schreven/committen toch in de hoofd-checkout op main i.p.v. de mission-worktree (F3 zelf hersteld, F4 belandde als losse commit op main en moest met cherry-pick naar de mission-branch worden verplaatst).
**Lesson**: De orchestrator moet na elke coder-handoff verifieren dat HEAD van de WORKTREE is opgeschoven (niet main); zo niet, cherry-pick de commit naar de mission-branch en reset main. Overweeg de coder-spawn-prompt te verscherpen: verifieer 'rtk git rev-parse --abbrev-ref HEAD' == mission-branch voor de commit.

### 2026-07-09 | insight | fwd:steps-plan (discover-gates)
**Context**: End-to-end verificatie van het stappenbudget: vier parallelle wegwerp-repo-runs (default/5/auto/1), elk een Node/bash-repo met een `tests/`-map maar zonder Python.
**Observation**: Alle vier de runs kregen valse gates terug: `discover-gates.sh` regel 45 behandelt `-d tests` als Python-signaal en bood `python3 -m pytest -q`, `ruff check .`, `mypy .` aan — strijdig met de script-header "Only emits commands that actually resolve". De plain-text gate-bevestiging in de flow ving het op, maar een letterlijke uitvoerder die "kies het testcommando als gate" blind volgt pint een altijd-falende gate.
**Lesson**: `-d tests` is geen taal-signaal. Laat de Python-tak alleen vuren op échte Python-markers (pyproject.toml/setup.py/pytest.ini of *.py aanwezig), of verifieer elke kandidaat-gate met een droge run vóór hij "oplosbaar" heet. Bugfix bewust uitgesteld (buiten scope stappenbudget-wijziging); dit is de reproductie.

### 2026-07-09 | insight | fwd:steps-run (scripts stdout-contract)
**Context**: Baseline-skill-eval van de steps-run-scriptsurface (181 deterministische checks) vóór de tekstcompactie.
**Observation**: `record-step.sh` (attended-tak, regel 75) en `finalize-autonomous.sh` (regel 31) vervuilen hun gedocumenteerde key=value-stdout met één rtk-samenvattingsregel ("ok 3 files changed, …") doordat `rtk git add -A` daar niet naar stderr is omgeleid; `snapshot-worktree.sh` doet het wél goed (`>&2`). Functioneel onschadelijk, maar strikte stdout-parsers breken. 179/181 checks verder groen.
**Lesson**: In fwd-skills-scripts hoort élke rtk-git-aanroep die niet zelf het contract-antwoord is naar stderr (`>&2`). Fix is 2× één redirect; bewust uitgesteld (compactie-sessie raakt geen scripts). Herdraaibare checkset: scratchpad eval-steps-run/e1..e13.sh van 2026-07-09.

### 2026-07-09 | insight | fwd:git-commit (pre-flight risky-scan)
**Context**: A/B-instrumenttest van fwd:skill-eval tegen fwd:git-commit; de B-run ontwierp een subdir-probe die de A-run als "not tested" had gelaten.
**Observation**: `pre-flight.sh` leest `rtk git status --porcelain` zónder `-uall`; een untracked directory wordt dan samengevat als `?? dir/`, waardoor een risky file erin (`config/.env.production` in een nieuwe map) alle naam-checks passeert én door `git add -A` gestaged wordt (reproduceerbaar: alleen die file in een nieuwe map → `ok` + gestaged).
**Lesson**: Porcelain-parsers die per bestand oordelen hebben `-uall`/`--untracked-files=all` nodig — zelfde val die fwd:plan's check-modus al documenteert (map-collapse). Fix-kandidaat voor pre-flight.sh: `--porcelain -uall`; bewust uitgesteld (sessie-scope raakte geen scripts), reproductie in de B-run-matrix van 2026-07-09.

### 2026-07-24 | correction | fwd:steps-run (stap-rapport)
**Context**: Eerste echte steps-run in een consumer-project (skilleval); Bas beoordeelde het allereerste stap-rapport aan het gate-moment.
**Observation**: Het twee-koloms sjabloon (label links, tekst rechts met hangende inspringing) las slecht en raakte verminkt bij wrappen/kopiëren; bestanden als losse paden en telegramstijl maakten de stap moeilijk te beoordelen ("ik vind het erg onduidelijk lezen").
**Lesson**: Gate-rapporten zijn beslis-eerst: "In één zin", dan de open punten die het akkoord raken (deferrals + open reviewer-vondsten), dan "Veranderd (per map)" genummerd in gewone taal, dan "Waarom je dit kunt vertrouwen". Titels bóven de tekst, nooit ernaast; bestanden per map gegroepeerd (max 3-4 regels). Doorgevoerd in sectie 5 + 7 van fwd:steps-run/SKILL.md; door Bas gekozen uit drie voorstellen.

### 2026-07-24 | deviation | fwd:mission-run
**Context**: Een reviewer meldde twee git-anker-bugs in `record-feature.sh`/`reconcile.sh`. Bug 1: de "echte code sinds vorige feature?"-check ankerde op de base-branch-*tip* (`PREV="$BASE"`) zolang nog geen feature een commit_sha had — liep `main` door ná het aftakken, dan telde main's eigen code mee (vals-positief `done` bij record, foute adoptie bij reconcile). Bug 2a: `commit_sha` kwam blind uit `rev-parse HEAD`, dus een losse metadata-commit ná de coder-commit werd de vastgelegde SHA. Bug 2b (root cause): de dirty-check weigerde een tracked `state.json` onder `.claude/missions/<slug>/` (log-decision.sh laat die dirty achter, waarna regel 113 die dir tóch zelf commit) — precies wat lessen 10-06 en 11-06 al voorspelden ("record first with a clean tree ... of fix the scripts to exclude .claude/missions/<slug>").
**Observation**: De merge-base-fix bouwt voort op de frontier-les (03-07): PREV is nu óf de git-nieuwste vastgelegde commit, óf — als er nog geen is — het echte aftakpunt (`rtk git merge-base "$BASE" HEAD`), nooit een verschoven branch-naam. `commit_sha` pakt nu de nieuwste niet-metadata-commit in `PREV..HEAD` (`rtk git log -1 --format=%H ... ":(exclude).claude/missions/<slug>"`), met `rev-parse HEAD` als fallback. De dirty-check negeert nu élke wijziging onder de mission-metadata-dir (`^.. \.claude/missions/<slug>/` — superset van de oude smalle `?? .../handoffs/`-uitsluiting). Bewust buiten scope: `reconcile.sh`'s `reset --hard`-opruiming (geen dirty-refuse, ongemoeid) en de upstream-backport (handmatig per CLAUDE.md).
**Lesson**: Anker een "sinds vorige feature"-diff altijd op een commit-SHA (aftakpunt of vastgelegde frontier), nooit op een branch-naam die kan verschuiven; laat een recorded `commit_sha` altijd naar echte code wijzen, niet naar een checkpoint/metadata-commit. Geverifieerd met wegwerp-harnas (3 scenario's) + negatieve controle: alle drie de bug-cases falen aantoonbaar op de oude code en zijn groen op de nieuwe. rtk-detail dat de fallbacks veilig maakt: alleen `git status` wordt ge-"ok"'t; `git log`/`diff`/`merge-base` zijn pass-through (lege output of exit≠0 bij leegte, geen extra grep-parsing nodig).

### 2026-07-29 | correction | general (plugin naming)
**Context**: `/fwd:steps-run <slug>` en `/fwd-skills:steps-run <slug>` gaven allebei "Unknown command"; alleen `/fwd-skills:fwd-steps-run` werkte. Alle 180 doorverwijzingen in de skills (o.a. "Start met: `/fwd:steps-run <slug>`" aan het eind van steps-plan en mission-plan) wezen dus naar niet-bestaande commando's.
**Observation**: Claude Code registreert een plugin-skill als `/<plugin-naam>:<skill-naam>` en vervangt een `:` in de skill-naam door een `-`. Met plugin `fwd-skills` en skill-naam `fwd:steps-run` werd dat `/fwd-skills:fwd-steps-run` — "fwd" dubbel. De `fwd:`-prefix hoorde nooit in de skill-naam thuis; die kwam al uit de plugin.
**Lesson**: De namespace komt van de **plugin**, niet van de skill. Plugin heet nu `fwd` (in `plugin.json` én `marketplace.json`); skill-mappen en frontmatter-`name` dragen géén prefix (`skills/engineering/steps-run/`, `name: steps-run`); agents idem (`agents/mission-coder.md` → `fwd:mission-coder`). Daarmee klopt `/fwd:steps-run` weer zoals overal gedocumenteerd. Zet nooit een `:` in een skill- of agent-naam. Naamswijziging van de plugin vereist eenmalig herinstalleren (`/plugin uninstall fwd-skills@headingfwd` + `/plugin install fwd@headingfwd`).

### 2026-08-22 | insight | fwd-skills (sessie-analyse als methode)
**Context**: Alle 692 Claude Code-transcripts doorzocht op fwd-skills-gebruik om verbeterpunten per skill/agent te oogsten (rapport: `docs/reviews/2026-08-22-skills-sessie-review.md`).
**Observation**: Twee dingen bleken structureel. (1) Zoeken op `fwd:<naam>` in transcripts geeft honderden valse positieven — elke sessie herhaalt de volledige skill-lijst in zijn systeemprompt. Alleen filteren op *uitgevoerde* skill-scripts (`record-step.sh`, `init-mission.sh`, …), geïnjecteerde SKILL.md-body's en `subagent_type`-spawns scheidt echt gebruik van vermelding: 517 ruwe treffers werden 56 echte sessies. (2) Sessie-mining vindt per definitie alleen wat gedraaid heeft. `mission-coder`, `mission-reviewer` en `mission-user-tester` kregen nul bevindingen — niet omdat ze goed zijn, maar omdat ze minder vaak draaien; directe lezing van diezelfde bestanden leverde daarna vijf hoog-impactpunten op, waaronder een compleet outputkanaal (`advisories`) dat nergens landt.
**Lesson**: Bij een sessie-gedreven audit: filter op uitvoeringssporen, nooit op naamvermelding. En sluit altijd af met een expliciete blinde-vlek-pas over de onderdelen die géén bevinding kregen — de stilte is een steekproefartefact, geen kwaliteitsoordeel. Verifieer elke bevinding daarna tegen de huidige repo: van 86 kandidaten uit juni–juli waren er 83 nog actueel, maar van de 27 gaten uit het juli-review waren er 20 al dicht.

### 2026-08-22 | correction | general (communicatie) + jip-janneke
**Context**: Bas: "je praat heel vaak echt poep tegen me". Een 18-agent-workflow analyseerde 33 verduidelijkingsmomenten in 12 gesprekken sinds juli, plus online research naar output styles, klare taal en stijlnaleving.
**Observation**: Top-faalpatronen: onverklaard jargon (19×), zelfbedachte labels als naam — "H4", "#6", "wereld 2", "seam" (14×), muur-van-tekst waar een diagram hoorde (11×), devops-voorkennis verondersteld (10×), abstractie zonder concreet voorbeeld (10×). HTML-explainers/gerenderde mermaid-diagrammen kregen als enige vorm vijf keer expliciete lof. Twee structurele gaten: de mens-eerst output style stond alleen in dít project aan (settings.local.json), en skill-/subagent-rapporten (steps-run gate-rapporten, codex-ernstlabels) vallen buiten elke output style — "in gewone taal" in een sjabloon werkt aantoonbaar niet, alleen een expliciete verbodslijst + telbare check.
**Lesson**: Verwijs met de inhoud, nooit met een zelfbedacht label; elk abstract begrip binnen twee zinnen een concreet geval; bied bij elk proces proactief een diagram/explainer aan en render hem echt vóór oplevering. Doorgevoerd in `~/.claude/output-styles/mens-eerst.md` (herschreven, met permanente verboden-woordenlijst — nu: "seam") en `skills/productivity/jip-janneke/SKILL.md` (Rules B2/E, meetbare Rule D, natel-Step 5). Zelfde dag op Bas' "fix regels 1 tm 3" ook: output style op gebruikersniveau gezet (~/.claude/settings.json), het blok `## Gedeelde taalregel` byte-identiek in de 5 rapport-producerende agents + steps-run/codex-review-skills (bewaakt door check-agent-norms.sh, derde check), sjabloon-jargon in steps-run vertaald ("gate <X/X> groen" → "de volledige testrun <X>/<X> groen"), en de nieuwe skill `/fwd:explainer` (vaste explainer-opbouw met renderplicht) geregistreerd.

### 2026-08-22 | correction | fwd:git-commit + fwd:setup (uitgestelde bugs afgesloten)
**Context**: Doorvoeren van de eerste tien punten uit `docs/reviews/2026-08-22-skills-sessie-review.md`.
**Observation**: De risky-scan-bug van 2026-07-09 (`pre-flight.sh` zonder `-uall`) is met een wegwerprepo gereproduceerd én weerlegd-na-fix: oude vorm antwoordt `ok` en stageert `config/.env.production`, nieuwe vorm blokkeert hem. Diezelfde sessie bracht een tweede stille destructie aan het licht: `setup/scripts/lib/merge-json.sh` overschreef zonder `jq` de complete `settings.local.json` met een snippet van drie regels en gaf exit 0, terwijl `OUTPUT.md` waarschuwingen alleen bij exit ≥2 toont — de gebruiker zag dus niets. Beide zijn nu gefixt (`--untracked-files=all`; niet schrijven zonder `jq`, exit 2).
**Lesson**: Een tak die nog nooit in productie is afgegaan (de risky-scan blokkeerde in geen enkele sessie) is niet "kennelijk in orde" maar ongetest — reproduceer hem in een wegwerprepo mét negatieve controle op de oude code. En een fallback die bij ontbrekend gereedschap tóch schrijft is altijd fout: niet schrijven en luid falen. Nog wél open uit de 2026-07-09-reeks: `discover-gates.sh:45` (`-d tests` als Python-signaal, in steps-plan én mission-plan) en de stdout-vervuiling in `finalize-autonomous.sh:31`.
