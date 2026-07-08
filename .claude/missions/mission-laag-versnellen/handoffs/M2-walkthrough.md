# Milestone M2 — Run-machinerie goedkoper

## In één oogopslag
De dure delen van een mission-run zijn goedkoper gemaakt. Het script dat elke feature-afronding wegschrijft (`record-feature.sh`) struikelt niet meer over het verse handoff-verslag en valideert nu zélf of de handoff compleet is — besliswerk dat eerst met de hand bij het hoofdmodel lag. En de walkthrough wordt voortaan gecompileerd door een goedkope, read-only scribe-agent op het Haiku-model; het hoofdmodel schrijft en commit alleen het resultaat. De reviewer krijgt bovendien de gate-uitslag plus commit-SHA mee, zodat hij een al-groen bewezen testsuite niet nog eens draait.

**Verdictbalans:** 1 gate (G1 shell-syntax) ✔ · 9 VC's, allemaal PASS ✔ · 0 zorgen · 0 advisories. Eén validatieronde, geen remediatie nodig.

## Leesvolgorde
1. `skills/engineering/fwd:mission-run/scripts/record-feature.sh` — de hardening (F2).
2. `agents/fwd-mission-scribe.md` — de nieuwe scribe-agent (F3).
3. `skills/engineering/fwd:mission-run/SKILL.md` — stap 2.5 rijgt scribe + gate-SHA aan elkaar.
4. `skills/engineering/fwd:mission-run/REFERENCE.md` en `CLAUDE.md` — scribe opgenomen in de agent-lijsten.

## Wat is er gebeurd, en waarom

**F2 — `record-feature.sh` gehard.** Twee dingen. De clean-worktree-check in de `done`-tak zondert nu untracked bestanden onder de mission-handoffs-map uit, zodat het verse narrative-verslag geen faalreden meer is; een *tracked* wijziging elders blijft wél falen, zodat echte vuiligheid niet verborgen raakt. Daarnaast valideert het script, alleen wanneer er echt een handoff-JSON binnenkomt, de vijf verplichte velden en (bij een feature met regels) een niet-lege `rules_applied` — met een foutmelding die het ontbrekende veld benoemt.
- *Bewijs VC-7:* `record-feature.sh` regels rond de `DIRTY`-check — de uitzondering `grep -vE "^\?\? \.claude/missions/$SLUG/handoffs/"`; de fixture "negative control tracked wijziging" gaf exit 1.
- *Bewijs VC-8:* de validatie-loop met melding `handoff missing required field: $field`; de reviewer draaide dit zelf (ontbrekend veld → exit 1 met veldnaam).

**F3 — Haiku-scribe + gate-bewuste reviewer.** Een nieuwe read-only plugin-agent (`model: haiku`, tools zonder `Write`/`Edit`) compileert de milestone-walkthrough en draait daarbij de volledige verificatiepas (elk pad tegen de diff, elk symbool gegrept, correctie bij mismatch, verplichte slotregel). De agent velt géén oordeel — dat staat expliciet in frontmatter, body en SKILL.md. In `SKILL.md` stap 2.5 is het compileren aan de scribe gedelegeerd (orchestrator schrijft/commit) en krijgt de reviewer-prompt de gate-uitslag + HEAD-SHA mee met het verbod de volledige suite op een ongewijzigde SHA te her-runnen.
- *Bewijs VC-9:* `agents/fwd-mission-scribe.md` frontmatter (`model: haiku`, geen Write/Edit); `SKILL.md` "delegate the compiling to fwd-skills:fwd-mission-scribe — never write it yourself".
- *Bewijs VC-10:* de scribe bevat de verificatiepas + de slotregel "Verificatie: <n> paden en <n> symbolen gecontroleerd tegen de diff."
- *Bewijs VC-11:* `SKILL.md` reviewer-spawn: "do not re-run the full test suite as long as that SHA is unchanged from the gate run".
- *Bewijs VC-12:* de scribe "never judges"; geen instructietekst delegeert een oordeel weg van het hoofdmodel.

## Zelf verifiëren
```
cd .trees/mission/mission-laag-versnellen
grep -n 'handoffs/' skills/engineering/fwd:mission-run/scripts/record-feature.sh          # untracked-uitzondering
grep -n 'handoff missing required field' skills/engineering/fwd:mission-run/scripts/record-feature.sh
grep -n 'model: haiku' agents/fwd-mission-scribe.md
grep -n 'Verificatie:' agents/fwd-mission-scribe.md
grep -n 'unchanged from the gate run' skills/engineering/fwd:mission-run/SKILL.md
```

## Zorgen
Geen.

## Nieuw t.o.v. het design budget
Eén toegestaan budget-item aangesproken: de plugin-agent `agents/fwd-mission-scribe.md`. Geen nieuwe dependency, geen nieuwe top-level map, geen nieuwe abstractie daarbuiten.

## Advisories
Geen.

Verificatie: 5 paden en 5 symbolen gecontroleerd tegen de diff.
