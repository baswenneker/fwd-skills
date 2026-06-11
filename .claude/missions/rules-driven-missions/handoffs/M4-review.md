# M4 — Scrutiny review (eerste ronde: gezakt op VC-20)

## In één oogopslag

M4 levert sterke documentatie maar mist één detail. VC-19 is solide: CLAUDE.md en README.md beschrijven de rules-gedreven werkwijze duidelijk, en de README-tabel spoort empirisch byte-voor-byte met alle 15 frontmatter-beschrijvingen (0 mismatches via Python-diff). VC-20 zakt: de audit-set vereist voor *elk* genoemd bestand een stijlblok of expliciete CONTEXT.md-stijlverwijzing, maar `agents/fwd-mission-reviewer.md` heeft die niet — het bevat alleen een verwijzing naar de *advisories*-vocabulaire-entry, niet naar het 'Schrijfstijl missions'-blok, terwijl die agent wél een `narrative`-rapport produceert dat onder dat blok valt. De F9-handoff beweert zelfs onterecht dat 'de reviewer-agent al de juiste verwijzingen had'; dat geldt alleen voor de coder-agent.

## VC-19 — geslaagd

**Beschrijving van de werkwijze.** CLAUDE.md (regels 55-59) heeft een 'Rules-driven missions'-blok: `.claude/rules/` als bron van waarheid, `/fwd:rules-audit` als bootstrap met golden examples + expliciete goedkeuring, en hoe de drie mission-skills regels consumeren. README.md (regels 59-61) heeft een gelijkwaardige sectie. **Tabel ↔ frontmatter:** Python-vergelijking van elke tabelcel tegen de frontmatter-`description:` gaf 0 mismatches over alle 15 rijen; de vier mission-skills matchen byte-voor-byte (rules-audit 406, mission-plan 576, mission-run 640, mission-run-parallel 1034 tekens).

## VC-20 — gezakt

**Criterium (a) — stijlblok of expliciete verwijzing per bestand.** Vijf van de zes bestanden slagen: `fwd:rules-audit/SKILL.md:131-133` (eigen '## Schrijfstijl'-sectie), `fwd:mission-plan/SKILL.md:191`, `fwd:mission-run/SKILL.md:201`, `fwd:mission-run-parallel/SKILL.md:334` (elk een 'Schrijfstijl'-bullet), en `agents/fwd-mission-coder.md:62`. Maar `agents/fwd-mission-reviewer.md` bevat géén stijlblok en géén stijlverwijzing — de enige CONTEXT.md-vermelding (regel 25) wijst naar de *advisories*-definitie, een ander concept. De agent levert wél een `narrative`-rapport (regel 34), dus het blok hoort van toepassing te zijn.

**Criterium (b) — geen onverklaarde afkortingen in nieuwe secties.** Houdt overal stand: domein-afkortingen (VC, PRD, Compliance-VC) zijn toegelicht in bestaande omringende tekst; overgebleven all-caps tokens zijn bestandsnamen of nadruk-woorden.

**Slotsom.** Criterium (b) slaagt overal, criterium (a) faalt voor de reviewer-agent → VC-20 zakt. De fix is klein: voeg een 'Schrijfstijl'-verwijzing toe aan `agents/fwd-mission-reviewer.md` (zoals de coder-agent die al heeft).

---

# M4 — Scrutiny review (hervalidatie, na remediatie)

**In één oogopslag.** M4 (de afronding) is in orde. De repo-documentatie beschrijft de rules-gedreven werkwijze nu correct in zowel `CLAUDE.md` als `README.md`, en — empirisch geverifieerd — spoort de README-tabel karakter-exact met de frontmatter-descriptions van alle 15 skills, inclusief de vier mission-skills. De schrijfstijl-verwijzing is overal toegepast: alle zes bestanden uit de auditset verwijzen expliciet naar het 'Schrijfstijl missions'-blok in `CONTEXT.md`, en de nieuw geschreven secties bevatten geen onverklaarde afkortingen. Beide VC's slagen.

## VC-19 — documentatie + tabel↔frontmatter (PASS)

`CLAUDE.md` (regels 55-59) en `README.md` (regels 59-61) beschrijven beide de rules-gedreven werkwijze: `/fwd:rules-audit` als fundament en de mission-familie die de regels consumeert. De tabel↔frontmatter-match is empirisch getoetst: per skill de frontmatter-`description` geëxtraheerd en karakter-exact vergeleken met de README-cel. Alle 15 rijen geven `MATCH`. Geen enkele afwijking gevonden.

## VC-20 — schrijfstijl overal toegepast (PASS)

**Clausule (a):** alle zes auditbestanden verwijzen expliciet: `fwd:rules-audit/SKILL.md:131-133` (eigen sectie), `fwd:mission-plan/SKILL.md:191`, `fwd:mission-run/SKILL.md:201`, `fwd:mission-run-parallel/SKILL.md:334`, `agents/fwd-mission-coder.md:62` en `agents/fwd-mission-reviewer.md:45` (de F9-remediatie). Het canonieke blok staat in `CONTEXT.md:5`. **Clausule (b):** in de mission-toegevoegde secties zijn de enige domein-afkortingen VC/VC-ID en PRD; beide worden verklaard in omringende tekst ('acceptance criteria (VC-IDs)'; 'a PRD, a validation contract'). Overige hoofdletter-tokens zijn bestandsnamen, tool-namen of nadruk-woorden. Beide clausules gelden voor elk genoemd bestand.
