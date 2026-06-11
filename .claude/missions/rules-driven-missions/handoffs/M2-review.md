# M2 — Scrutiny review

## In één oogopslag

M2 (features F4, F5) levert precies wat het contract eist: een nieuw `list-rules.sh`-script dat de regelsinventaris compact print, een verplichte regelskeuze vóór de flow, een "Strategy & Design Budget"-sectie met limitatieve lijsten, een simplicity-grill vóór de approval gate, een beschreven compliance-VC-generatie, en "In één oogopslag"-/één-regel-samenvatting-eisen in de templates. Ik heb het script empirisch getest (geen regels, leeg, niet-md, inline `paths:`, block-style `paths:`, geen heading, vanuit een subdir) en alle takken gedragen zich correct. Alle kruisverwijzingen (schema v3 `rules_manifest`/`rule_paths` in `fwd:mission-run/REFERENCE.md`, het "Schrijfstijl missions"-blok in CONTEXT.md) bestaan en kloppen. Alle zes beweringen slagen.

## VC-7 — regelsinventaris-statement (PASS)

Het `` !`bash "${CLAUDE_SKILL_DIR}/scripts/list-rules.sh"` ``-statement staat op SKILL.md:24, vóór `## Flow` (regel 37) — dus vóór de flow. Empirische test: per regelbestand print het script `<pad>\t<scope>\t<eerste kopregel>`; inline `paths: [...]` én block-style `paths:`/`- glob` worden allebei correct geparseerd, een bestand zónder `paths:` levert scope `repo-wide`, een bestand zonder heading `(geen heading)`. Bij ontbrekende/lege `.claude/rules/` of alleen niet-`.md`-bestanden print het exact één regel `geen regels gevonden — .claude/rules/ is leeg of afwezig` en exit 0. Werkt ook vanuit een subdir (repo-root via `rtk git rev-parse --show-toplevel`).

## VC-8 — bewuste keuze zonder regels (PASS)

SKILL.md:41-51, "Stap 1.0 — Regelskeuze (verplicht, vóór alle scopingwerk)": bij geen regels stelt de flow via `AskUserQuestion` keuze (a) stop en draai eerst `/fwd:rules-audit`, óf (b) ga expliciet verder zónder regels met vastlegging in `mission.md` ("Bewust gestart zonder `.claude/rules/`…"). De zin "stilzwijgend doorgaan is geen optie" staat er letterlijk; keuze (b) eist vastlegging in `mission.md` sectie *Aannames en afwijkingen*.

## VC-9 — Strategy & Design Budget (PASS)

REFERENCE.md:43-57: de strategiesectie heet "Strategy & Design Budget" en bevat een limitatieve lijst "Toegestane nieuwe dependencies (limitatief — niets buiten deze lijst is toegestaan)", een limitatieve lijst "Toegestane nieuwe abstracties (…)", én een lijst "Geldende regelbestanden" met pad + scope (repo-breed of glob). Afsluitende zin: overschrijden laat een review zakken.

## VC-10 — simplicity grill (PASS)

SKILL.md:125-133, "### 4.5. Simplicity grill (vóór de approval gate)", staat vóór §5 Approval gate en toetst exact de drie vereiste vragen: (1) kunnen features samengevoegd, (2) welke component is speculatief, (3) wat is het eenvoudigste ontwerp dat het contract haalt.

## VC-11 — compliance-generatie (PASS)

SKILL.md:115-121, "Compliance-VC-generatie (verplicht wanneer `.claude/rules/` niet leeg is)": file-by-file-paden per feature → gematcht tegen `paths:`-globs (regelbestand zónder `paths:` is repo-breed en matcht altijd) → matchende regels als `rule_paths` in `features[]` van state.json → per match een compliance-assertion in Layer B → bij materialisatie wordt top-level `rules_manifest` met `[{path, sha256}]` gevuld. De gerefereerde velden bestaan als schema v3 in `fwd:mission-run/REFERENCE.md` (`rules_manifest` regel 76-77, `rule_paths` regel 104).

## VC-12 — één-oogopslag + één-regel-samenvatting (PASS)

REFERENCE.md:22-24: het mission.md-template opent met "## In één oogopslag" met expliciete eis van maximaal 5 zinnen (en verwijst naar het "Schrijfstijl missions"-blok in CONTEXT.md, dat bestaat). REFERENCE.md:87-93: het contract-template eist per VC "a one-line plain-language summary" via het `· *cursief*`-patroon, voorgedaan in de VC-1..VC-3-voorbeelden.
