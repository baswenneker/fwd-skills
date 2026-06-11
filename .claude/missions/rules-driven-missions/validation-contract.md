# Validation Contract: rules-driven-missions

**In één oogopslag:** drie machinale gates (syntax, manifest, smoke-test) en twintig beoordeelde criteria, allemaal `scrutiny-review` — er is geen app om te booten. Elk criterium heeft naast given/when/then een één-regel-samenvatting in gewone taal (· *cursief*), zoals deze missie zelf gaat voorschrijven.

## Layer A — Gates (machine-checked, exit 0)

| ID | Name | Command |
|----|------|---------|
| G1 | bash-syntax | `find skills -name '*.sh' -print0 \| xargs -0 -n1 bash -n` |
| G2 | plugin-manifest | `jq -re '.skills[]' .claude-plugin/plugin.json \| while IFS= read -r p; do test -f "$p/SKILL.md" \|\| exit 1; done` |
| G3 | smoke-waves | `bash skills/engineering/fwd:mission-run-parallel/tests/smoke-waves.sh` |

## Layer B — Assertions (judged)

### M1 — Fundament

- **VC-1** (scrutiny-review): *Given* een repo zonder `.claude/rules/`, *when* de gebruiker `/fwd:rules-audit` draait, *then* beschrijft de skill een interactieve flow: codebase scannen → regels voorstellen met per regel minstens één golden example (pad naar een echt bestand) → pas wegschrijven na expliciet akkoord van de gebruiker. · *De skill stelt regels voor en schrijft pas na akkoord.* *(features: F1)*
- **VC-2** (scrutiny-review): *Given* de nieuwe skill, *when* je de artefacten bekijkt, *then* schrijft de flow uitsluitend markdown onder `.claude/rules/`, schrijft het SKILL.md een maximum van ~200 regels per regelbestand voor, gebruikt het `paths:`-frontmatter waar een regel maar voor een deel van de repo geldt, en is de skill geregistreerd in `.claude-plugin/plugin.json` én de README-tabel. · *Alleen kleine, gescopede regelbestanden, netjes geregistreerd.* *(features: F1)*
- **VC-3** (scrutiny-review): *Given* schema v3, *when* je `fwd:mission-run/REFERENCE.md` leest, *then* zijn `rules_manifest` ([{path, sha256}]), `features[].rule_paths` en `milestones[].walkthrough_path` gedocumenteerd als optionele velden, met de expliciete uitspraak dat plannen zonder deze velden (v1/v2) overal geldig blijven. · *Schema uitgebreid zonder iets te breken.* *(features: F2)*
- **VC-4** (scrutiny-review): *Given* een `state.json` met een `rules_manifest`, *when* `validate-artifacts.sh` draait, *then* faalt het met een duidelijke melding wanneer een gemanifesteerd bestand ontbreekt of de hash niet klopt, en passeert een `state.json` zónder `rules_manifest` ongewijzigd alle bestaande checks. · *Streng waar aanwezig, stil waar afwezig.* *(features: F2)*
- **VC-5** (scrutiny-review): *Given* de handoff-documentatie, *when* je de handoff-tabel in REFERENCE.md leest, *then* bevat die het veld `rules_applied` ([{rule, how}]) met de notitie dat `record-feature.sh` de handoff integraal opslaat en dit veld dus zonder scriptwijziging meereist. · *Het nieuwe handoff-veld staat gedocumenteerd.* *(features: F2)*
- **VC-6** (scrutiny-review): *Given* CONTEXT.md, *when* je het leest, *then* staat er een "Schrijfstijl missions"-blok (korte zinnen; geen onverklaarde afkortingen; rapporten beginnen met "In één oogopslag" van maximaal 5 zinnen; schrijf in de taal van de gebruiker) en vocabulaire-entries voor golden example, design budget, advisory, walkthrough en rule-kandidaat. · *Stijlregels en woordenlijst op één canonieke plek.* *(features: F3)*

### M2 — Plan-kant

- **VC-7** (scrutiny-review): *Given* `fwd:mission-plan/SKILL.md`, *when* de skill wordt geïnvoceerd, *then* staat er vóór de flow een `` !`...` ``-statement dat `list-rules.sh` aanroept, en print dat script per regelbestand het pad, de `paths:`-scope en de eerste kopregel — of een expliciete "geen regels gevonden"-regel als `.claude/rules/` leeg of afwezig is. · *De planner ziet de regels al bij de start.* *(features: F4)*
- **VC-8** (scrutiny-review): *Given* een repo zonder regels, *when* de planning start, *then* schrijft de flow een bewuste keuze voor (eerst `/fwd:rules-audit` draaien, óf expliciet zonder regels door — vastgelegd in mission.md) en is stilzwijgend doorgaan geen optie. · *Zonder regels alleen verder na een bewuste keuze.* *(features: F4)*
- **VC-9** (scrutiny-review): *Given* het PRD-template in `fwd:mission-plan/REFERENCE.md`, *when* je het leest, *then* heet de strategiesectie "Strategy & Design Budget" en bevat ze limitatieve lijsten voor nieuwe dependencies en nieuwe abstracties plus verwijzingen naar de geldende regelbestanden. · *Het budget begrenst wat nieuw mag zijn.* *(features: F5)*
- **VC-10** (scrutiny-review): *Given* de plan-flow, *when* je de stappen vóór de approval gate leest, *then* staat er een simplicity-grill-stap die toetst: kunnen features samengevoegd, welke component is speculatief, wat is het eenvoudigste ontwerp dat het contract haalt. · *Eenvoud wordt getoetst vóór goedkeuring.* *(features: F5)*
- **VC-11** (scrutiny-review): *Given* de plan-flow, *when* je de contract-stap leest, *then* beschrijft die de compliance-generatie: file-by-file-paden gematcht tegen rule-globs → per feature `rule_paths` in state.json én compliance-assertions in het contract, en wordt `rules_manifest` (pad + hash) gevuld bij materialisatie. · *Regels worden automatisch contractcriteria.* *(features: F5)*
- **VC-12** (scrutiny-review): *Given* de templates, *when* je ze leest, *then* opent het mission.md-template met een "In één oogopslag"-blok (maximaal 5 zinnen) en eist het contract-template per VC een één-regel-samenvatting in gewone taal. · *Elk plan en criterium is in één blik te snappen.* *(features: F5)*

### M3 — Run-kant

- **VC-13** (scrutiny-review): *Given* `agents/fwd-mission-coder.md`, *when* je het leest, *then* verklaart het gepinde regels bindend, eist het `rules_applied` ([{rule, how}]) in de handoff zodra de spawn-prompt rule-paden bevat, schrijft het bij conflict tussen regel en criterium de conservatieve keuze plus melding in `issues_discovered` voor, en eist het eenvoudige taal in de narrative. · *De coder volgt de regels en legt verantwoording af.* *(features: F6)*
- **VC-14** (scrutiny-review): *Given* `agents/fwd-mission-reviewer.md`, *when* je het leest, *then* toetst de reviewer compliance-VC's als gewone verdicts en retourneert hij daarnaast `advisories[]` (eenvoud-bevindingen met vindplaats), strikt gescheiden van de verdicts. · *De reviewer toetst naleving en adviseert over eenvoud.* *(features: F6)*
- **VC-15** (scrutiny-review): *Given* `fwd:mission-run/SKILL.md`, *when* je de coder-spawn-stap leest, *then* pint die per feature het design budget en de `rule_paths` als verplichte leeslijst, en telt een handoff zonder `rules_applied` (bij niet-lege `rule_paths`) als mislukte poging onder de bestaande attempt-regels. · *Geen verantwoording, geen geaccepteerde handoff.* *(features: F7)*
- **VC-16** (scrutiny-review): *Given* de milestone-validatie, *when* die afrondt, *then* schrijft de runner `handoffs/<milestone>-walkthrough.md` volgens het template (In één oogopslag, leesvolgorde, per feature wat/waarom + sleutelbestanden + zelf-verifiëren-commando's, advisories), zet `walkthrough_path` in state.json, en beïnvloeden advisories `validation_status` nooit. · *Elke milestone eindigt met een leesbare walkthrough; advies blokkeert niets.* *(features: F7)*
- **VC-17** (scrutiny-review): *Given* de finalize-stap, *when* de missie afrondt, *then* bevat het eindrapport rule-kandidaten (gedistilleerd uit `issues_discovered` en lessen) en staat expliciet dat de runner `.claude/rules/` nooit zelf muteert. · *De missie stelt regels voor, de mens beslist.* *(features: F7)*
- **VC-18** (scrutiny-review): *Given* `fwd:mission-run-parallel/SKILL.md`, *when* je stap 3.4 en 3.7 leest, *then* spiegelen die de pinning, `rules_applied`-afdwinging en walkthrough/advisories van de serial runner zonder gedeelde scripts te wijzigen, en blijft de interop-sectie (runner-switching veilig) kloppen. · *De parallel runner doet exact hetzelfde.* *(features: F8)*

### M4 — Afronding

- **VC-19** (scrutiny-review): *Given* de repo-documentatie, *when* je CLAUDE.md en README.md leest, *then* beschrijven die de rules-gedreven werkwijze (rules-audit als fundament, de mission-skill-familie) en spoort de README-tabel met alle gewijzigde frontmatter-descriptions. · *De repo-documentatie klopt weer.* *(features: F9)*
- **VC-20** (scrutiny-review): *Given* alle in deze missie gewijzigde SKILL.md's en agent-bestanden, *when* je ze naleest, *then* bevatten ze het schrijfstijl-blok of een verwijzing naar CONTEXT.md, en bevatten nieuw geschreven secties geen onverklaarde afkortingen. · *De stijl is overal toegepast — ook op onszelf.* *(features: F9)*

## App boot (user-testing)

Geen — dit is een skills-repo zonder bootbare app. Alle assertions zijn `scrutiny-review`; `user_testing` blijft leeg.
