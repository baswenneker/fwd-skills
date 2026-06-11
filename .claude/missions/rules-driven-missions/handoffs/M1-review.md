# M1 — Scrutiny review

## In één oogopslag

Alle zes de assertions slagen. De nieuwe skill `fwd:rules-audit` beschrijft een complete interactieve flow (scannen → voorstellen met golden examples → akkoord vragen → pas dan wegschrijven) en is netjes geregistreerd in zowel `plugin.json` als de README-tabel. De schema-v3-uitbreiding in `REFERENCE.md` documenteert alle drie de optionele velden plus `rules_applied`, met de expliciete uitspraak dat v1/v2-plannen overal geldig blijven. De `rules_manifest`-check in `validate-artifacts.sh` is empirisch getest: streng (exit 1 met duidelijke melding) bij ontbrekend bestand of hash-mismatch, en stil (exit 0, bestaande checks ongewijzigd) wanneer het veld afwezig of leeg is. `CONTEXT.md` bevat het stijlblok en alle vijf vocabulaire-entries.

## VC-1 — interactieve flow, pas na akkoord schrijven

PASS. `SKILL.md` stappen 1-4 (regels 27-137) beschrijven scan → voorstel → akkoord → wegschrijven. Golden example is gedefinieerd als pad naar een echt bestand (regel 16, 61: "Geen verzonnen paden"). De `AskUserQuestion`-poort (regels 66-81) heeft een "Annuleer"-optie die stopt zonder te schrijven; "Geen automatisch wegschrijven" staat ook in Boundaries (regel 133).

## VC-2 — alleen kleine, gescopede regelbestanden, geregistreerd

PASS, alle vier clausules. (a) Alleen markdown onder `.claude/rules/`: regel 115 "Uitsluitend markdown-bestanden onder `.claude/rules/`". (b) ~200 regels max: regel 113. (c) `paths:`-frontmatter alleen bij partiële regels: regels 92 + 111. (d) Geregistreerd in `plugin.json` (regel 12) én README-tabel (regel 70).

## VC-3 — schema uitgebreid zonder iets te breken

PASS. `rules_manifest` als `[{path, sha256}]` (regels 71-78, 163), `features[].rule_paths` (regels 100-104, 164), `milestones[].walkthrough_path` (regels 138-142, 165), elk gemarkeerd OPTIONAL/schema v3. Expliciete uitspraak op regel 162: "Plans without `rules_manifest`, `features[].rule_paths`, `milestones[].walkthrough_path`, or `handoff.rules_applied` (v1/v2 plans) remain valid everywhere — both runners, all scripts." herhaald op regel 75.

## VC-4 — streng waar aanwezig, stil waar afwezig

PASS, empirisch geverifieerd met wegwerp-fixtures. Ontbrekend bestand → exit 1, `rules_manifest: file missing: …`. Hash-mismatch → exit 1, `rules_manifest: hash mismatch for … (expected … got …)`. Geen `rules_manifest` → exit 0, alle bestaande checks ongewijzigd. Lege array → exit 0 (guard eist `length > 0`). Controle: een kapotte `depends_on` zonder manifest faalt nog steeds, dus de additieve logica verstoort de bestaande validatie niet.

## VC-5 — handoff-veld gedocumenteerd

PASS. Handoff-tabel rij `rules_applied | [{rule, how}][]` (regel 179) met de notitie: "`record-feature.sh` stores the handoff JSON integrally — no field whitelist — so this field travels into `state.json` without any script change."

## VC-6 — stijlregels en woordenlijst op één plek

PASS. `CONTEXT.md` heeft het blok "Schrijfstijl missions" (regels 5-12) met alle vier de regels: korte zinnen, geen onverklaarde afkortingen, rapporten beginnen met "In één oogopslag" (max 5 zinnen), schrijf in de taal van de gebruiker. Vocabulaire-entries aanwezig voor advisory (18), design budget (22), golden example (26), rule-kandidaat (30) en walkthrough (34).
