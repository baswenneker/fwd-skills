# Stappenplan: Autonome modus voor fwd:steps-run

*Doel: een gate-optie `auto` waarmee steps-run de resterende stappen onbeheerd afmaakt en pas na één eindreview commit. Branch: `steps/steps-run-autonoom`. Base: `main`. Gate: `bash skills/engineering/fwd:steps-run/tests/run-tests.sh`. Regels: bewust geen (geen `.claude/rules/` in deze repo; het meeste werk is proza in één SKILL.md).*

## Definition of Done
1. Nieuwe gate-antwoordoptie `auto` (alias `autonoom`), geldig overal waar `ok` mag: maakt alle resterende stappen af zónder de beurt te stoppen, met per stap rood → groen → volledige gate → verse reviewer, en de doubt-tussenbalans elke 4 goedgekeurde stappen. Omdat er tijdens een autonome run niets gecommit is, krijgt de verse reviewer per stap een geïsoleerde diff via twee wegwerp-worktree-snapshots (vóór en na de stap) — zo ziet hij alleen de huidige stap; de doubt-agent diff't ongecommit-inclusief zodat het opgestapelde werk meetelt.
2. Tijdens een autonome run wordt niets op de branch gecommit; `state.json` + de `plan.md`-vinkjes worden per stap bijgewerkt maar blijven ongecommit tot het einde.
3. Autonoom onderbreekt zichzelf naar attended (beurt stopt, niets gecommit) bij: een vastgelopen stap, een gate die rood blijft, een reviewer-FAIL die niet vanzelf oplost, of een doubt-agent die een concreet voorstel doet.
4. Bij de laatste stap (of bij een onderbreking) verschijnt één eindreview-rapport: opgetelde diff-samenvatting + per-stap uitkomst + open reviewer-punten + deferrals. De commit landt uitsluitend na `ok` op dat gate — het opgestapelde werk gaat als **één commit** (de gebruiker geeft de message). Per-stap splitsen kan niet: de `--no-commit`-accumulatie laat geen commit-grenzen na.
5. Een onderbroken autonome run hervat schoon: herkent stappen die done-maar-ongecommit zijn, biedt "doorgaan of nu afronden", en herbouwt nooit een al-gedane stap — bewezen door het bash-testharnas over de scripts.

## Eindbeeld

Bij elk stap-gate staat de nieuwe optie in de voetregel:

```
Volgende:       stap 4/6 — Subtree-einde per clausule berekenen
── ok = commit & door · auto = autonoom afmaken · m = meer detail · stop = pauze ──
```

Na `auto` lopen de resterende stappen door zonder tussenstops en zonder commits. Aan het eind (of bij een onderbreking) verschijnt:

```
── Autonome run klaar: stap 4→6/6 zonder tussenstop ────────

Gebouwd (nog niets gecommit):
  S4  Subtree-einde per clausule       +31/-4    evaluate.py
  S5  Clausule-grenzen samenvoegen     +58/-12   evaluate.py · chunker.py
  S6  Overlap-guard op grenzen         +19/-6    evaluate.py
  Totaal: 3 stappen · +108/-22 · 2 bestanden

Gate:            88/88 groen (na elke stap herdraaid)
Reviewer:        3/3 stappen schoon · 1 open punt (S5, zie onder)
Doubt (na S4):   "niets aanpassen" — verdict onderbouwd
Deferrals:       S6 globale overlap-drempel — per-clausule zodra nesting knelt
Open punt (S5):  reviewer wilde helper X hergebruiken; niet gedaan omdat <reden>

Zelf zien:       cd <WT> && rtk git diff <base>   ·   uv run pytest -q

── ok = commit alles (1 commit) & klaar · message aanpassen? zeg 't · stop = niets committen ──
```

Onderbreekt autonoom halverwege (bijv. S5 loopt vast), dan verschijnt in plaats daarvan het gewone "vastgelopen"-rapport van S5 met opties en staat de beurt weer bij de gebruiker.

## Seams (testplekken)
- `record-step.sh [--no-commit] <slug> <step-id> "<msg>"` — stdout `recorded/progress/status/interim_review`; muteert state.json + plan.md; commit alleen zónder `--no-commit`.
- `finalize-autonomous.sh <slug> "<msg>"` (nieuw) — stdout `finalized/commit/status`; precies één commit van al 't opgestapelde werk.
- `snapshot-worktree.sh <slug>` (nieuw) — legt de volledige worktree (tracked + untracked) vast als off-branch commit-ref en echoot de SHA; wijzigt HEAD, branch noch working tree. Twee snapshots omsluiten precies één stap (per-stap isolatie voor de verse reviewer, zónder branch-commit).
- `status.sh <slug>` — key=value stdout, mét afgeleid `pending_autonomous_commit`.
- `tests/run-tests.sh` — plain-bash harnas; tevens de gate. (SKILL.md-proza wordt met grep-presence getoetst — bewust geen seam.)

## Stappen
- [x] S1 — Testharnas + gate: plain-bash harnas met assert-helpers + een wegwerp-git-fixture (mini steps-plan). Klaar als: `bash skills/engineering/fwd:steps-run/tests/run-tests.sh` → exit 0 (hiermee bestaat de gate voor S2+). Regels: geen
- [x] S2 — `record-step.sh --no-commit`: markeert stap done, tikt plan.md, zet `approved_mode=autonomous`, commit niet; `interim_review` vuurt nog elke 4e; attended-modus ongewijzigd. Klaar als: harnastest — na `--no-commit` is de stap done + plan.md getikt + HEAD onveranderd, en attended commit nog wél. Regels: geen
- [x] S3 — `finalize-autonomous.sh` (nieuw): commit alle ongecommitte wijzigingen als één commit; status=done als geen todo's resten, anders in_progress (deel-finalize bij break-out). Klaar als: harnastest — precies 1 nieuwe commit bevat al 't werk; status klopt in beide gevallen. Regels: geen
- [x] S4 — `status.sh` → afgeleid `pending_autonomous_commit`: yes als tree dirty én laatst-goedgekeurde stap `approved_mode=autonomous`, anders no. Klaar als: harnastest — beide gevallen. Regels: geen
- [x] S5 — steps-run SKILL.md gate-optie `auto`: `auto`/`autonoom` als antwoord in §6 + de voetregel in het stap-rapport (§5). Klaar als: grep vindt `auto` in de voetregel-template én een gate-bullet. Regels: geen
- [x] S6 — `snapshot-worktree.sh` (nieuw): legt de volledige worktree (tracked + untracked) vast als off-branch commit-ref, zonder HEAD/branch/working tree te wijzigen. Klaar als: harnastest — na een wijziging op een vuile tree toont `git diff <snap-voor> <snap-na>` precies die wijziging (incl. nieuw untracked bestand); HEAD en working tree onveranderd. Regels: geen
- [x] S7 — reviewer- + doubt-agent: optionele diff-range: `fwd-steps-reviewer` accepteert een optionele diff-basis (default `HEAD`; in autonoom de twee per-stap snapshots → ziet alleen de huidige stap); `fwd-steps-doubt` diff't ongecommit-inclusief zodat opgestapeld werk meetelt. Klaar als: grep — reviewer-agent noemt de optionele diff-basis/range, doubt-agent noemt de ongecommit-inclusieve diff. Regels: geen
- [x] S8 — steps-run SKILL.md sectie "Autonome modus": loop zonder stops via `--no-commit`; snapshot vóór+na elke stap → range aan de reviewer (negeert `.claude/steps/**`, oordeelt alleen de huidige stap); doubt elke 4 ongecommit-inclusief → auto-door bij "niets aanpassen", anders break-out; break-out-condities (vastgelopen / gate rood / reviewer-FAIL / doubt-voorstel → terug naar attended, beurt stopt). Klaar als: grep sectiekop + break-out-lijst + `--no-commit` + snapshot-verwijzing. Regels: geen
- [x] S9 — steps-run SKILL.md eindreview + commit-gate + hervat-proza: het eindreview-rapport (het eindbeeld), commit alleen na `ok` via `finalize-autonomous.sh` (één commit, message-keuze), `stop`=ongecommit laten. Hervatten bij `pending_autonomous_commit=yes` biedt doorgaan/afronden, herbouwt nooit een done-stap, én finaliseert het opgestapelde werk vóór een volgende attended `ok` — zodat `record-step.sh` (`git add -A`) nooit meerdere stappen in één commit veegt. Klaar als: grep rapport-template + finalize-verwijzing + hervat-tak + break-out-finalize-guard. Regels: geen
- [x] S10 — Docs-sync: steps-plan schema krijgt `approved_mode` (default `"attended"`) + 1-regel notitie dat steps-run een autonome `auto`-afronding kent; README steps-run-rij noemt `auto`. Klaar als: grep alle drie de plekken. Regels: geen
- [x] S11 — `fwd:skill-eval` shakedown van steps-run: de repo's eigen black-box skill-test als behavioral capstone (grep bewijst alleen dát de tekst er staat, niet dat-ie klopt). Klaar als: `/fwd:skill-eval` op steps-run → regressievrije tabel. Regels: geen
