# CONTEXT.md

Shared vocabulary for the `fwd-skills` repo. Keeps terminology consistent across skills, READMEs, and future ADRs.

## Schrijfstijl missions

Regels voor alles wat missions produceren: plannen, rapporten, walkthroughs, handoff-narratieven.

- **Korte zinnen.** Eén gedachte per zin. Splits lange zinnen op.
- **Geen onverklaarde afkortingen.** De eerste keer dat een term of afkorting verschijnt, volgt een korte uitleg op dezelfde regel.
- **Rapporten beginnen met "In één oogopslag".** Dit is een alinea van maximaal 5 zinnen die de kern samenvat. De lezer weet daarna wat er is gedaan en waarom.
- **Schrijf in de taal van de gebruiker.** Is de gebruiker Nederlandstalig, schrijf dan Nederlands. Is de gebruiker Engelstalig, schrijf dan Engels.

## Vocabulary

_Voeg een entry toe zodra een term op meer dan één plek wordt gebruikt en één canonieke definitie nodig heeft._

### advisory

Een niet-blokkerende vereenvoudigingsvinding van de reviewer ("kan dit simpeler?"). Een advisory staat los van het reviewvonnis en heeft nooit invloed op de validatiestatus.

### design budget

De limitatieve lijst in een missieplan van toegestane nieuwe afhankelijkheden en nieuwe abstracties. Het overschrijden van het design budget laat een review zakken.

### golden example

Een pad naar een bestaand, exemplarisch bestand in de repo dat een regel in de praktijk demonstreert. Agents en skills verwijzen naar een golden example in plaats van de regel opnieuw uit te leggen.

### rule-kandidaat

Een patroon dat tijdens de mission-finalisatiefase wordt gedestilleerd uit gevonden issues of lessons, en wordt voorgesteld als mogelijke nieuwe `.claude/rules/`-regel. De mens beslist; de runner schrijft zelf nooit regels.

### walkthrough

Het leesbare rapport per mijlpaal (sjabloon gedocumenteerd in `skills/engineering/fwd:mission-run/REFERENCE.md`). Leesbaar in ±5 minuten. Begint altijd met "In één oogopslag".
