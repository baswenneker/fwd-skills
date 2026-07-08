# Eindrapport — mission-laag-versnellen

## In één oogopslag
De missie is **done**: alle 6 features klaar, alle 3 milestones geslaagd, 25 validatiecriteria groen, 0 openstaande zorgen. Het doel was de mission-laag merkbaar sneller en goedkoper maken zonder kwaliteitsverlies — dat is op vier fronten gebeurd: de agent-definities zijn zelfvoorzienend (geen schijf-brede zoektochten meer), de handoff-administratie zit in het script en op een goedkope scribe, en het plan snijdt features groter en legt afhankelijkheden vast. Eén milestone (M1) had een echte remediatiepas nodig (een inline norm was onvolledig overgenomen); na de fix was alles groen.

## Belofte naast wat er staat
| Beloofd eindbeeld (uit mission.md) | Geleverd |
|---|---|
| Geen `find /`-zoektochten of rtk-pipe-timeouts in agents | 5 agents zelfvoorzienend + gedragsverbod inline; `grep -rn CONTEXT.md agents/` leeg |
| Handoff-afhandeling goedkoper | `record-feature.sh` valideert de handoff zelf + tolereert het narrative; walkthrough via Haiku-scribe |
| Max 1 volledige suite-run per milestone op gelijke code | reviewer-prompt krijgt gate-uitslag + SHA met her-run-verbod |
| Features ~30–45 min; kleine units samenvoegen | sizing-regel in `fwd:mission-plan` stap 3 + grill-toets |
| Geblokkeerde feature blokkeert alleen echte afhankelijken | `depends_on` + `pick-next-unit` passeert geblokkeerde features; plan-lint |

## Per milestone
| Milestone | Status | Walkthrough |
|---|---|---|
| M1 — Agent-definities zelfvoorzienend | ✔ passed | `handoffs/M1-walkthrough.md` |
| M2 — Run-machinerie goedkoper | ✔ passed | `handoffs/M2-walkthrough.md` |
| M3 — Plan-laag: minder spawns, slimmere spawns | ✔ passed | `handoffs/M3-walkthrough.md` |

Validatie: 25/25 criteria `true`, 0 `false`, 0 onbewezen (`null`). F1 op 2 pogingen (remediatie), de rest op 1.

## Open punten
| Type | Locatie | Omschrijving | Beslissing |
|---|---|---|---|
| handoff-vondst | `scripts/pick-next-unit.sh` (exit-conventie) | Nieuwe **exit 3** = "vastgelopen achter geblokkeerd werk", onderscheiden van exit 0 = "alles done". Callers die "lege output = klaar" aannemen moeten exit 3 apart afvangen. | Bij merge: controleer dat de orchestrator-flow (SKILL.md 2.1 → finalize) exit 3 respecteert. |
| handoff-vondst (proces) | coder-spawns | Twee coders committen eerst op `main` i.p.v. de mission-worktree; de orchestrator herstelde via cherry-pick en zette `main` terug. | Les gelogd; zie rule-kandidaat 1. |
| advisory | `agents/fwd-mission-coder.md` (~r.94) | Verwijst nog naar `skills/.../REFERENCE.md` voor het handoff-schema — een schema-pointer, geen norm. | Optioneel: kern-schema inline of bewust extern documenteren. |
| advisory | `fwd-mission-reviewer.md` vs `fwd-mission-coder.md` | Twee inline kopieën van het schrijfstijl-blok kunnen opnieuw uit elkaar lopen (dit was M1's faalpad). | Optioneel: gelijk houden / centraliseren. |
| advisory | `scripts/pick-next-unit.sh` (cycle-guard) | Bij een cykel geeft de guard de accumulator terug i.p.v. te falen; onschadelijk want `validate-artifacts.sh` vangt cykels al bij plan-time af. | Optioneel: één regel commentaar dat op de plan-lint wordt vertrouwd. |

## Niet gedaan (bewust)
- `fwd:mission-plan/REFERENCE.md` is niet gewijzigd voor `reading_list`/`size`: dat bestand bevat alleen de markdown-artefact-templates, niet het `state.json` feature-schema (dat staat in `fwd:mission-run/REFERENCE.md`). Consistent met hoe `rule_paths` eerder is behandeld.

## Onbewezen criteria
Geen — alle 25 criteria zijn `true`.

## Zelf bekijken (kijkinstructie)
Er is geen bootbare app (skills-plugin). Volg `handoffs/RUNBOOK.md`; kort:
1. `cd .trees/mission/mission-laag-versnellen`
2. `find skills agents -name '*.sh' -print0 | xargs -0 -n1 bash -n` → exit 0.
3. `grep -rn 'CONTEXT.md' agents/` → geen treffers.
4. `grep -n 'model: haiku' agents/fwd-mission-scribe.md` → aanwezig, read-only.
5. `bash .../pick-next-unit.sh mission-laag-versnellen` → leeg, exit 0 (alles done).

## Wat nu?
Drie routes — jij beslist (ik push niet, ik merge niet):

**1. Accepteren & mergen.** De code + mission-state staan op branch `mission/mission-laag-versnellen`.
```
cd /Users/bas/Development/HeadingFWD/fwd-skills
rtk git stash push .claude/lessons/LESSONS.md   # main heeft een lopende lessons-wijziging
rtk git checkout main
rtk git merge --no-ff mission/mission-laag-versnellen
rtk git stash pop
```
Let op: de merge brengt ook de `.claude/missions/…`-artefacten mee (bewust op de branch gecommit). Wil je alleen de code, cherry-pick dan de code-commits (agents + skills) en laat de `chore(mission):`-commits liggen.

**2. Eerst zelf proberen.** Volg `handoffs/RUNBOOK.md` — de demo-stappen zijn read-only en lokaal.

**3. Afwijzen met reden.** Noteer waarom; die reden gaat als les mee naar de volgende `/fwd:mission-plan`.

## Rule-kandidaten (mens beslist; de runner raakt `.claude/rules/` niet aan)
1. **Coder committeert op de mission-branch, nooit op main.** Twee coders schreven/committen deze missie eerst in de hoofd-checkout op `main`. Kandidaat-regel: een coder verifieert `rtk git rev-parse --abbrev-ref HEAD` == de mission/steps-branch vóór elke commit. Hoort in `.claude/rules/` omdat het een terugkerende, kostbare fout is die stille schade op `main` oplevert.
2. **Inline-parafrase van een norm: bullet-voor-bullet, niets weglaten.** M1 zakte omdat een inline schrijfstijl-blok twee bronnormen liet vallen. Kandidaat-regel: bij het inline overnemen van een norm elke bullet tegen de bron aftikken en meerdere kopieën identiek houden. Hoort in `.claude/rules/` omdat "sneller" hier "slordiger" werd — precies wat de regel moet voorkomen.
