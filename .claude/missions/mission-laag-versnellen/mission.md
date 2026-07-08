# Mission: Mission-laag versnellen

## In één oogopslag

Een gemeten mission-run (small-llm-clause-labeling, 5u58 actief) verloor ~2 uur aan proces rond 46 minuten echt bouwwerk. Deze missie haalt die overhead weg op vier fronten. Agents krijgen hun normen inline en stoppen met zoeken naar bestanden buiten de doelrepo. De handoff-administratie verhuist naar scripts en een goedkope schrijf-agent. Het plan snijdt features voortaan groter en legt afhankelijkheden expliciet vast.

## Problem Statement

Wie een mission draait, wacht onnodig lang en betaalt onnodig veel tokens. Gemeten in de run van 7 juli 2026 (transcript-analyse, hoofdsessie + 14 subagent-transcripts):

- Reviewers draaiden 3× ~2 minuten `find /` over de hele schijf, op zoek naar een `CONTEXT.md` die alleen in fwd-skills bestaat — de agent-definities verwijzen ernaar als norm-autoriteit.
- Drie rtk-pipe-constructies (`rtk cat … | rtk head`, `rtk git diff … | rtk head`, `rtk proxy grep`) hingen tot exact de Bash-timeout van 120s.
- 13 handoff-afhandelingen à gem. ~4m30 (≈ 58 min) op het dure hoofdmodel: JSON valideren, commit checken, state bijwerken, walkthrough schrijven.
- 37 volledige testsuite-runs in één avond, waarvan ~14 her-runs op ongewijzigde code (coder bewijst groen; orchestrator en reviewer draaien dezelfde suite opnieuw).
- Spawn-belasting: 9 coders besteedden samen 80 min aan oriëntatie (plan/contract/rules/codebase herlezen) en 63 min aan afronden, tegenover 46 min echt bouwen — de missie was met 8 mini-features te fijn gesneden.
- Eén geblokkeerde feature legt de facto de hele resterende rij stil, ook als opvolgers er niet van afhangen.

## Goals and Success Metrics

**Primary goal**: dezelfde missie draait merkbaar sneller en goedkoper zonder kwaliteitsverlies — het besliswerk blijft bij het hoofdmodel, de validatielaag blijft intact.

**Success metrics**:
- Geen `find /`-zoektochten of rtk-pipe-timeouts meer in agent-transcripts.
- Handoff-afhandeling per feature ≤ ~2 min (was ~4m30).
- Maximaal 1 volledige suite-run per milestone-grens op ongewijzigde code (was ~3 per feature-slot).
- Plannen produceren features van ~30–45 min bouwwerk; kleine verwante units worden samengevoegd.
- Een geblokkeerde feature blokkeert alleen features die er via `depends_on` van afhangen.

## Acceptance Criteria

1. De 5 agent-definities (`fwd-mission-coder/-reviewer/-user-tester`, `fwd-steps-reviewer/-doubt`) bevatten de normblokken (Codecommentaar-kern, advisory/concern-definitie, schrijfstijl-kern) inline en verwijzen nergens meer naar een bestand dat alleen in fwd-skills bestaat.
2. Alle 5 agent-definities bevatten het rtk-pipe-verbod: nooit rtk-output in een tweede rtk pipen; `rtk git` voor git, anders gewone tools (`cat`/`grep`/`head`); nooit het hele filesysteem afzoeken naar ontbrekende bestanden — ontbreekt een genoemd bestand, meld dat in het verdict.
3. `record-feature.sh` struikelt niet meer over een untracked handoff-narrative en valideert de handoff-JSON zélf (verplichte velden; `rules_applied`-plicht bij gevulde `rule_paths`), met duidelijke foutmelding en non-zero exit bij een ongeldige handoff.
4. Een nieuwe read-only plugin-agent `fwd-mission-scribe` (model haiku) compileert de milestone-walkthrough inclusief de verificatiepas; de orchestrator schrijft en commit alleen het resultaat. Oordelen (handoff accepteren, remediatie, unit-keuze) blijven bij het hoofdmodel.
5. De reviewer-spawn-prompt bevat de gate-uitslag + commit-SHA met de instructie: geen volledige suite her-runnen zolang de SHA gelijk is; alleen gerichte tests bij twijfel.
6. `fwd:mission-plan` bevat de feature-sizing-regel (een feature is ~30–45 min bouwwerk; kleiner → samenvoegen) inclusief het spawn-belasting-argument, en de grill (stap 4.5) toetst erop.
7. Schema v6 (additief): `features[].depends_on`; `pick-next-unit.sh` passeert een geblokkeerde feature wanneer de eerstvolgende niet-gedane feature er niet (transitief) van afhangt; `validate-artifacts.sh` lint `depends_on` (bestaande, eerdere features; geen cykels). Plannen zonder het veld gedragen zich exact als nu.
8. De coder-spawn-prompt bevat een per-feature reading-list en de rule-inhoud inline (fallback naar paden-lijst boven ~200 regels totaal), plus "lees alléén dit; scan de repo niet opnieuw". Model/effort-keuze naar featuregrootte is gedocumenteerd (`features[].size`, additief).

## Zo ziet klaar eruit

Before/after van één milestone-cyclus, met de cijfers uit de gemeten run:

```
NU:     F3 (10m) → F4 (15m) → F5 (33m) → 3× handoff à 4m30 (hoofdmodel)
        → review M2 draait de volledige suite opnieuw                      ≈ 81 min
STRAKS: F3+F4+F5 zijn bij het plannen samengevoegd tot 1–2 features
        → handoff-validatie in record-feature.sh (seconden)
        → walkthrough door de Haiku-scribe
        → reviewer vertrouwt de gate-uitslag op gelijke commit-SHA         ≈ 50 min
```

En in een reviewer-transcript komt dit nooit meer voor:

```
   120s  find / -name "CONTEXT.md" -path "*fwd*"     ← norm staat voortaan inline
   120s  rtk cat src/chunker/__init__.py | rtk head  ← verboden patroon
```

## Strategy & Design Budget

Alleen bestaande patronen: markdown-skills, bash-scripts in `scripts/`, plugin-agents in `agents/` — zoals de repo nu werkt. Serieel: eerst de agent-definities (M1, direct effect op elke run), dan de run-machinerie (M2), dan de plan-laag en het schema (M3). Alle schema-wijzigingen zijn additief; oude plannen blijven overal geldig.

**Toegestane nieuwe dependencies (limitatief — niets buiten deze lijst is toegestaan):**
- geen

**Toegestane nieuwe abstracties (limitatief — niets buiten deze lijst is toegestaan):**
- plugin-agent `agents/fwd-mission-scribe.md`
- `state.json`-velden `features[].depends_on`, `features[].reading_list`, `features[].size` (schema v6, additief)

**Geldende regelbestanden:**
- Geen `.claude/rules/` aanwezig — bewust gestart zonder regels.

Het overschrijden van dit design budget laat een review zakken.

## File-by-file

| File | Change | Reason |
|------|--------|--------|
| `agents/fwd-mission-coder.md` | modified | normblokken inline, CONTEXT.md-verwijzing eruit, rtk-pipe-verbod |
| `agents/fwd-mission-reviewer.md` | modified | idem |
| `agents/fwd-mission-user-tester.md` | modified | idem |
| `agents/fwd-steps-reviewer.md` | modified | idem (zelfde bug: draait in consumer-repo's) |
| `agents/fwd-steps-doubt.md` | modified | idem |
| `agents/fwd-mission-scribe.md` | new | Haiku, read-only; compileert walkthrough + verificatiepas |
| `skills/engineering/fwd:mission-run/SKILL.md` | modified | scribe-spawn in 2.5, gate-SHA in reviewer-prompt, reading-list + rules-inline + model/effort in 2.3, depends_on-semantiek in 2.1 |
| `skills/engineering/fwd:mission-run/REFERENCE.md` | modified | schema v6 (`depends_on`, `reading_list`, `size`), scribe in subagent-naming |
| `skills/engineering/fwd:mission-run/scripts/record-feature.sh` | modified | narrative-frictie + handoff-JSON-validatie |
| `skills/engineering/fwd:mission-run/scripts/pick-next-unit.sh` | modified | passeert geblokkeerde feature zonder afhankelijke opvolgers |
| `skills/engineering/fwd:mission-plan/SKILL.md` | modified | sizing-regel (stap 3 + grill 4.5), depends_on + reading_list + size bij materialisatie (stap 6) |
| `skills/engineering/fwd:mission-plan/REFERENCE.md` | modified | sizing-regel + depends_on in templates |
| `skills/engineering/fwd:mission-plan/scripts/validate-artifacts.sh` | modified | lint op depends_on (bestaand, eerder, acyclisch) — tolerant voor oude plannen |
| `CLAUDE.md` | modified | scribe-agent vermelden in de agents-sectie |

## Testing & Verification

- Gate G1: `bash -n` (syntaxcheck) over alle `*.sh` onder `skills/` en `agents/` — resolvet zonder nieuwe tooling.
- Gedragsbewijs per script-wijziging via een wegwerp-fixture-missie: een minimaal `state.json` + handoffs in een tijdelijke git-repo, waartegen `record-feature.sh`, `pick-next-unit.sh` en `validate-artifacts.sh` echt draaien (exit codes in `handoff.commands`).
- Backward-compat expliciet: een v1-`state.json` zonder nieuwe velden doorloopt dezelfde fixtures met ongewijzigd gedrag.
- De reviewer beoordeelt alle markdown-wijzigingen tegen de VC's (alles `scrutiny-review` — er is niets te booten).

## Security

Geen secrets geraakt. Scripts blijven lokaal-only (nooit pushen — bestaande grens). De scribe-agent is read-only via de tools-allowlist (geen `Write`/`Edit`); het hoofdmodel behoudt de schrijf- en beslisrol.

## Aannames en afwijkingen

- Bewust gestart zonder `.claude/rules/` — regels ontbreken in deze repo (keuze gebruiker, planning 8 juli 2026).
- Geen bootbare app: alle VC's zijn `scrutiny-review` — expliciete keuze, geen stille degradatie.
- F4 (sizing-planregel) heeft géén sad-path-VC — waiver door de gebruiker bevestigd: het is een documentatieregel zonder foute input.
- Parallelle uitvoering (waves, sub-worktrees, merge-scripts) is bewust GESCHRAPT na de kwaliteitsdiscussie: alleen de afhankelijkheids-informatie (`depends_on`) wordt vastgelegd; uitvoering blijft serieel. Vastgelegd als afspraak-VC.
- De rtk-pipe-hang zelf is een bug in de rtk-binary en wordt buiten deze missie gefixt; hier wordt alleen het patroon verboden.
