# Milestone-review M1 — Agent-definities zelfvoorzienend (na remediatie)

## In één oogopslag
Deze mijlpaal maakt de vijf agent-definities zelfvoorzienend: de normen (comment-hygiëne, advisory/concern, schrijfstijl) staan inline en er is een rtk/zoek-gedragsverbod toegevoegd. De inhoud dekt `CONTEXT.md` zonder betekenisverlies. Het eerdere faalpunt is verholpen — het schrijfstijl-blok in de reviewer bevat nu weer zowel de "In één oogopslag"-opening als "schrijf in de taal van de gebruiker". Alle 6 VC's slagen; geen zorgen.

## Verdicts (allemaal PASS)
- VC-1 — geen CONTEXT.md-refs; normkernen inline waar nodig; user-tester/doubt-weglating verdedigbaar.
- VC-2 — gedragsverbod met drie bullets in alle 5, `find /` verboden in elk.
- VC-3 — norm-drift verholpen (0551e9f); geen andere drift gevonden.
- VC-4 — commit messages schoon; mission-tokens komen alleen als voorbeeld binnen normtekst voor.
- VC-5 — grep-bewijs draait echte bestanden, niet tautologisch.
- VC-6 — alleen 5 agent-bestanden; geen budget-overschrijding.

## Advisory (niet-blokkerend)
- `agents/fwd-mission-coder.md:94` verwijst nog naar `skills/.../REFERENCE.md` voor het handoff-schema — een schema-pointer, geen norm, dus buiten VC-1. Overweeg bij volledige zelfvoorzienendheid het kern-schema inline te zetten of de externe referentie bewust te documenteren.
