# Mission: Rules-gedreven missions

## In één oogopslag

Missions leveren goede code die lastig te controleren is. We lossen dat op met drie ingrepen: vaste regels in `.claude/rules/` die elke coder aangereikt krijgt (consistentie), een leesbare walkthrough na elke milestone (controleerbaarheid), en een design budget plus eenvoud-oordeel (KISS). Alles in eenvoudige taal. De wijzigingen zijn additief: bestaande missies blijven geldig, de serial en parallel runner blijven uitwisselbaar.

## Probleem

Wie er last van heeft: de gebruiker, als enige reviewer van missie-output.

- Elke coder-agent start blanco en herontdekt zelf de conventies — feature 3 lost hetzelfde probleem anders op dan feature 7.
- De missie-artifacts (`state.json`, JSON-handoffs) zijn gebouwd voor de orchestrator, niet voor een mens — er is geen leespad door wat er gebouwd is.
- Niemand bewaakt eenvoud: de coder is lokaal voorzichtig, de reviewer toetst alleen de acceptatiecriteria. Complexiteit stapelt ongezien op.

Kosten: reviewtijd per missie is hoog, en het vertrouwen om te mergen ontbreekt zonder diepe duik.

## Doelen en meetpunten

**Hoofddoel**: missie-output die je in minuten kunt begrijpen en vertrouwen, omdat dezelfde regels overal zijn toegepast.

Meetpunten:
- Elke coder-spawn bevat de regels die voor die feature gelden; elke handoff verantwoordt per regel hoe die is toegepast (`rules_applied`).
- Elke afgeronde milestone heeft een walkthrough die in ±5 minuten leesbaar is, beginnend met "In één oogopslag".
- Elk missieplan bevat een design budget (limitatieve lijst nieuwe dependencies en abstracties); overschrijding faalt de review.
- Geen onverklaarde afkortingen in missieplannen, rapporten en walkthroughs.

## Acceptatiecriteria

Volledig uitgewerkt als VC-1 t/m VC-20 in [validation-contract.md](validation-contract.md). Samengevat:

- `/fwd:rules-audit` bootstrapt `.claude/rules/` interactief, met golden examples, en schrijft pas na akkoord (VC-1, VC-2).
- Schema v3 is additief gedocumenteerd en `validate-artifacts.sh` bewaakt het `rules_manifest` (VC-3 t/m VC-5).
- Schrijfstijl en vocabulaire staan canoniek in CONTEXT.md (VC-6).
- mission-plan ziet regels bij de start (`!`-inventaris), dwingt een bewuste keuze af zonder regels, en genereert design budget + simplicity grill + compliance-criteria (VC-7 t/m VC-12).
- Coder volgt gepinde regels en legt verantwoording af; reviewer toetst naleving en adviseert niet-blokkerend over eenvoud (VC-13, VC-14).
- Beide runners pinnen de regels per feature, dwingen `rules_applied` af, compileren een walkthrough per milestone en rapporteren rule-kandidaten bij finalize (VC-15 t/m VC-18).
- Repo-documentatie klopt weer en de stijl is overal toegepast (VC-19, VC-20).

## Strategy & Design Budget

1. **`.claude/rules/` is de bron van waarheid.** Nieuwe skill `fwd:rules-audit` zet die regels op, interactief, met per regel een *golden example* (verwijzing naar een echt, voorbeeldig bestand).
2. **Expliciet aanreiken, niet hopen op auto-load.** Empirisch geverifieerd (2026-06-10): rules worden wél auto-geïnjecteerd (ook in worktrees, zelfs dubbel), maar alleen bij het *lezen* van een matchend bestand — bij nieuw aan te maken bestanden dus precies niet. Daarom berekent het plan per feature welke regels gelden (`rule_paths`, uit de file-by-file-tabel × rule-globs) en pint de runner die als verplichte leeslijst in de coder-spawn.
3. **Naleving is contract, geen hoop.** Het plan genereert compliance-criteria (VC's) uit de regels; de reviewer toetst ze blocking. Eenvoud-oordeel ("kan dit simpeler?") is een apart, **niet-blokkerend** `advisories`-veld — subjectieve oordelen mogen geen attempts opbranden.
4. **Additief schema (v3).** Nieuwe optionele velden: `rules_manifest` (top-level, pad+hash per regel-bestand), `features[].rule_paths`, `milestones[].walkthrough_path`, handoff-veld `rules_applied`. Oude plannen blijven overal geldig; runner-switching blijft veilig.
5. **Minimaal script-oppervlak.** Eén nieuw script (`list-rules.sh`), één gewijzigd (`validate-artifacts.sh`). `record-feature.sh` slaat handoffs al integraal op (geverifieerd: geen veld-whitelist) — geen wijziging nodig. De rest is SKILL.md-, REFERENCE.md- en agent-tekst.

**Design budget van deze missie zelf:** géén nieuwe dependencies (bash + jq blijven de enige tooling); géén nieuwe scripts behalve `list-rules.sh`; géén nieuwe agent-bestanden; géén schema-veldhernoemingen — uitsluitend optionele toevoegingen.

**Te volgen patronen:** de bestaande SKILL.md-opbouw (frontmatter → principes → Quick start → Flow → Boundaries), de scriptconventies uit `.claude/lessons/LESSONS.md` (rtk-`ok`-regels filteren, `-C <path>` voor git-operaties buiten cwd, atomic `state.json.tmp.$$`-writes), en de cross-skill-referentieregel uit CLAUDE.md.

## File-by-file

| Bestand | Wijziging | Reden |
|------|--------|-------|
| `skills/engineering/fwd:rules-audit/SKILL.md` | nieuw | interactieve rules-bootstrap met golden examples |
| `.claude-plugin/plugin.json` | aangepast | nieuwe skill registreren |
| `README.md` | aangepast | rij voor `fwd:rules-audit`; descriptions synchroon houden |
| `skills/engineering/fwd:mission-run/REFERENCE.md` | aangepast | schema v3 + `rules_applied` in handoff-tabel + walkthrough-template |
| `skills/engineering/fwd:mission-plan/scripts/list-rules.sh` | nieuw | compacte rules-inventaris voor het `!`-statement |
| `skills/engineering/fwd:mission-plan/scripts/validate-artifacts.sh` | aangepast | `rules_manifest`-check (bestanden bestaan, hashes kloppen; afwezig = ok) |
| `skills/engineering/fwd:mission-plan/SKILL.md` | aangepast | `!`-inventaris, geen-regels-keuze, design budget, simplicity grill, compliance-VC-generatie |
| `skills/engineering/fwd:mission-plan/REFERENCE.md` | aangepast | PRD-/contract-templates: budget, "In één oogopslag", plain-language VC-regel |
| `agents/fwd-mission-coder.md` | aangepast | regels bindend; `rules_applied` verplicht; eenvoudige taal in narrative |
| `agents/fwd-mission-reviewer.md` | aangepast | compliance-VC's toetsen; `advisories[]` retourneren |
| `skills/engineering/fwd:mission-run/SKILL.md` | aangepast | leeslijst pinnen, `rules_applied` afdwingen, advisories verwerken, walkthrough compileren, rule-kandidaten bij finalize; `Write` in allowed-tools |
| `skills/engineering/fwd:mission-run-parallel/SKILL.md` | aangepast | zelfde wijzigingen gespiegeld (stap 3.4 en 3.7) |
| `CONTEXT.md` | aangepast | canoniek "Schrijfstijl missions"-blok + vocabulaire |
| `CLAUDE.md` | aangepast | rules-conventie + nieuwe skill documenteren |

## Testing & Verification

Geen bootbare app (skills-repo) — alle criteria zijn `scrutiny-review`; user-testing blijft leeg. Gates: G1 bash-syntaxcheck over alle scripts, G2 plugin-manifest-check (alle geregistreerde paden bestaan), G3 de hermetische `smoke-waves.sh` als regressietest op de gedeelde machinerie (we raken `validate-artifacts.sh` en leunen op het handoff-doorgeefgedrag van `record-feature.sh`).

## Security

Geen secrets in het spel; `fwd:rules-audit` schrijft uitsluitend markdown onder `.claude/rules/`; bestaande risky-scan en nooit-pushen-regels blijven onverkort gelden.
