# Plan-contract: Tijdlijn-analyse mission-run small-llm-clause-labeling

Basis-commit: 1ff5185  ·  Vastgelegd: 2026-07-07

## In één oogopslag
We ontleden de mission-run-sessie (513c158f…, 7 juli 16:56–einde, incl. 6 subagent-transcripts) tot een interactieve HTML-tijdlijn (Artifact): ingeklapt duren + wat er gebeurde, uitklapbaar tot tool-call-niveau, onderaan datagedreven versnellings-aanbevelingen. Af = Artifact-URL opent en elk gat > 2 min heeft een verklaring.

## Definition of Done
1. De volledige sessie is gereconstrueerd tot een tijdlijn: hoofdsessie + alle 6 subagent-transcripts, opgedeeld in blokken (orchestrator-werk, coder-runs, reviews, tool-calls) met per blok start, duur en samenvatting. Onverklaarde gaten > 2 minuten bestaan niet.
   — bewijs: analyse-uitdraai → som van alle blokken dekt ≥ 95% van de totale sessieduur
2. Interactieve HTML-pagina (Artifact) met de tijdlijn chronologisch: ingeklapt duur + wat er gedaan is; uitklappen toont de diepte (fase → agent → tool-call).
   — bewijs: Artifact-URL openen → blokken tonen duur ingeklapt, klikken klapt uit tot tool-call-niveau
3. Onderaan een aanbevelingen-sectie: maatregelen gerangschikt op geschatte tijdwinst, elk onderbouwd met gemeten cijfers uit déze sessie.
   — bewijs: pagina scrollen → elke aanbeveling noemt minuten winst + de meting
4. Faalgedrag: corrupte/niet-parseerbare transcriptregels breken de analyse niet — parser slaat over, telt, en de pagina toont "N regels overgeslagen".
   — bewijs: parser draaien op de echte transcripts → skip-teller zichtbaar in uitdraai én op de pagina

## Gekozen plan: Transcript-parser + interactieve tijdlijn-Artifact
Eén Python-parsescript in de scratchpad leest de hoofdsessie-JSONL + 6 subagent-transcripts, bouwt een geneste tijdlijn (fase → agent → tool-call, duren + verklaarde gaten) en genereert één self-contained HTML-pagina, gepubliceerd als Artifact, met onderaan aanbevelingen.

**Wijzigingen**

| File | Change | Reason |
|------|--------|--------|
| `<scratchpad>/parse_mission.py` | nieuw | JSONL-parser: tijdlijn, duren, gaten, skip-teller |
| `<scratchpad>/mission-timeline.html` | nieuw | interactieve tijdlijn + aanbevelingen; als Artifact |

## Toets na implementatie
Afvinkbare checklist — wie implementeert, vinkt dit af vóór oplevering (of draai `/fwd:plan check mission-timeline-analyse`):
- [ ] De diff sinds de basis-commit raakt precies de bestanden in de Wijzigingen-tabel (scratchpad valt buiten git — verwachting: géén repo-diff) — afwijkingen benoemd.
- [ ] Per DoD-criterium is de bewijsregel zélf gedraaid en de observatie genoteerd.
- [ ] Het faalcriterium (DoD-4, skip-teller) is aantoonbaar getest.
