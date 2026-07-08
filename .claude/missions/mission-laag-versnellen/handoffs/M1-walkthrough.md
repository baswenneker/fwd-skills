# Milestone M1 — Agent-definities zelfvoorzienend

## In één oogopslag
De vijf plugin-agents die missions en steps aandrijven verwezen naar `CONTEXT.md` als norm-autoriteit. Dat bestand bestaat alleen in fwd-skills, niet in de consumer-repo's waar de agents draaien — dus konden ze het niet vinden en gingen ze de hele schijf afzoeken (`find /`, tot 120s-timeout). Deze mijlpaal zet de benodigde normen inline in elk agent-bestand en voegt een gedragsverbod toe (geen rtk-pipes, `rtk git` voor git, nooit buiten de repo-root zoeken). Resultaat: de agents zijn zelfvoorzienend en de schijf-brede zoektochten kunnen niet meer voorkomen.

**Verdictbalans:** 1 gate (G1 shell-syntax) ✔ · 6 VC's, allemaal PASS ✔ · 0 zorgen · 1 advisory (niet-blokkerend). Eén remediatiepas was nodig: de eerste ronde liet VC-3 zakken (norm-drift), na de fix slaagde alles.

## Leesvolgorde
1. `agents/fwd-mission-coder.md` — grootste blok inline normen (comment-hygiëne + schrijfstijl) + gedragsverbod.
2. `agents/fwd-mission-reviewer.md` — comment-hygiëne + advisory/concern-definities + schrijfstijl + gedragsverbod.
3. `agents/fwd-steps-reviewer.md` — comment-hygiëne (naar steps-context) + gedragsverbod.
4. `agents/fwd-mission-user-tester.md` en `agents/fwd-steps-doubt.md` — alleen het gedragsverbod (deze twee gebruiken de comment/advisory/schrijfstijl-normen niet).

## Wat is er gebeurd, en waarom
**Normen inline (VC-1, VC-3).** Elke `CONTEXT.md`-verwijzing is vervangen door de norm zelf, geparafraseerd. Een agent die comments beoordeelt kreeg de comment-hygiëne-kern; een agent die verdicts schrijft kreeg de advisory/concern-definities en de schrijfstijl-kern. De twee agents die geen code reviewen en geen advisory/concern-oordeel geven (user-tester, doubt) kregen bewust géén overbodig blok — alleen het gedragsverbod.
- *Bewijs VC-1:* `grep -rn 'CONTEXT.md' agents/fwd-mission-*.md agents/fwd-steps-*.md` → geen treffers.
- *Bewijs VC-3:* het schrijfstijl-blok in `fwd-mission-reviewer.md` dekt nu alle bronnormen, inclusief de "In één oogopslag"-opening en "schrijf in de taal van de gebruiker" (die in de eerste ronde ontbraken).

**Gedragsverbod (VC-2).** Elk bestand kreeg een "Behavior prohibitions"-blok: nooit rtk-output in een tweede rtk pipen; `rtk git` voor git en gewone tools (`cat`/`grep`/`head`) voor inspectie; nooit buiten de repo-root zoeken (`find /` verboden) — een ontbrekend bestand meld je in je verdict, je gaat er niet naar zoeken.
- *Bewijs VC-2:* `grep -l 'Behavior prohibitions' agents/fwd-mission-*.md agents/fwd-steps-*.md` → alle 5.

**Binnen budget (VC-4, VC-5, VC-6).** De code-commits raken uitsluitend de 5 agent-markdown-bestanden — geen nieuwe dependency, map of abstractie. Commit messages zijn schoon (geen mission-jargon). Het bewijs bestaat uit grep-commando's tegen de echte bestanden, niet uit een nagebootste kopie.

## Zelf verifiëren
```
cd .trees/mission/mission-laag-versnellen
grep -rn 'CONTEXT.md' agents/fwd-mission-coder.md agents/fwd-mission-reviewer.md agents/fwd-mission-user-tester.md agents/fwd-steps-reviewer.md agents/fwd-steps-doubt.md   # verwacht: geen treffers
grep -l 'Behavior prohibitions' agents/fwd-mission-coder.md agents/fwd-mission-reviewer.md agents/fwd-mission-user-tester.md agents/fwd-steps-reviewer.md agents/fwd-steps-doubt.md   # verwacht: alle 5
grep -n 'oogopslag' agents/fwd-mission-reviewer.md   # verwacht: 1 treffer (de herstelde norm)
```

## Zorgen
Geen.

## Nieuw t.o.v. het design budget
Niets. Deze mijlpaal raakt alleen bestaande agent-bestanden; geen enkel budget-item (scribe-agent, schema v6-velden) is aangesproken.

## Advisories (niet-blokkerend)
- `agents/fwd-mission-coder.md` verwijst nog naar `skills/.../REFERENCE.md` voor het handoff-schema. Dat is een schema-pointer, geen norm, dus buiten deze mijlpaal. Overweeg later het kern-schema inline te zetten of de externe referentie bewust te documenteren.
- Overweeg het schrijfstijl-blok van reviewer en coder op één plek gelijk te houden om toekomstige drift tussen de twee inline kopieën te voorkomen.

Verificatie: 5 paden en 6 symbolen gecontroleerd tegen de diff.
