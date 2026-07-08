# Milestone-review M1 — Agent-definities zelfvoorzienend

## In één oogopslag
De milestone doet grotendeels wat beloofd is, maar één inline normblok mist twee bronnormen. Alle verwijzingen naar `CONTEXT.md` zijn weg (grep exit 1) en elk van de 5 agent-bestanden heeft het gedragsverbod met de `find /`-regel. De code-commit raakt precies de 5 agent-bestanden, zonder nieuwe dependencies, mappen of abstracties, en de commit message is schoon.

## Faalpunt (VC-3)
Het schrijfstijl-blok in `agents/fwd-mission-reviewer.md` laat twee bronnormen vallen uit `CONTEXT.md` "Schrijfstijl missions": de opening met "In één oogopslag (max 5 zinnen)" en "schrijf in de taal van de gebruiker". De coder behield beide in `fwd-mission-coder.md` (regels 42-43); de reviewer-versie heeft ze niet (`grep 'language|oogopslag'` op reviewer geeft 0 treffers). Dat is norm-drift door weglating — precies wat VC-3 moet vangen.

## Verdicts
- VC-1 PASS — geen CONTEXT.md-refs; normen inline waar nodig; user-tester/doubt-weglating verdedigbaar.
- VC-2 PASS — gedragsverbod met drie bullets in alle 5, `find /` in elk.
- VC-3 **FAIL** — norm-drift in reviewer schrijfstijl-blok (twee normen weg).
- VC-4 PASS — commit message schoon, geen mission-code leak in comments.
- VC-5 PASS — grep-bewijs draait echte bestanden, onderscheidt echt, niet tautologisch.
- VC-6 PASS — alleen 5 agent-bestanden, geen budget-overschrijding.

## Advisories (niet-blokkerend)
- `fwd-steps-reviewer.md` comment-hygiene-blok laat de test-docstring-bullet weg; overweeg toevoegen.
- Trek het reviewer-schrijfstijlblok gelijk met het coder-blok om toekomstige drift tussen de twee inline kopieën te voorkomen.
