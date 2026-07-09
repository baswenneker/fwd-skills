# CONTEXT.md

Shared vocabulary for the `fwd-skills` repo. Keeps terminology consistent across skills, READMEs, and future ADRs.

## Schrijfstijl missions

Regels voor alles wat missions en steps-runs produceren: plannen, rapporten, walkthroughs, stap-rapporten, handoff-narratieven.

- **Korte zinnen.** Eén gedachte per zin. Splits lange zinnen op.
- **Geen onverklaarde afkortingen.** De eerste keer dat een term of afkorting verschijnt, volgt een korte uitleg op dezelfde regel.
- **Rapporten beginnen met "In één oogopslag".** Dit is een alinea van maximaal 5 zinnen die de kern samenvat. De lezer weet daarna wat er is gedaan en waarom.
- **Schrijf in de taal van de gebruiker.** Is de gebruiker Nederlandstalig, schrijf dan Nederlands. Is de gebruiker Engelstalig, schrijf dan Engels.
- **Schrijf voor een mens die het moet doorvertellen.** De lezer moet jouw uitkomst aan een collega kunnen uitleggen. Toets vóór je iets oplevert: "kan ik dit aan een collega uitleggen?" Zo nee, herschrijf.
- **Vertaal interne codes; dump ze niet rauw.** Orkestratie-termen (VC-ID, milestone-id, gate-namen, DAG width, `state.json`-velden) en rauwe JSON horen thuis in de bestanden voor de agent-keten — niet onvertaald in wat de gebruiker leest. Noem in lopende tekst eerst wát het is, dan pas de code: "validatiecriterium VC-3 (…)".

## Codecommentaar (gegenereerde code)

Geldt voor alle gegenereerde code — door de mission-coder of door de hoofdsessie in een steps-run; broncode én tests, comments én docstrings. Dit is de doortrekking van de "Vertaal interne codes"-regel hierboven naar de code zelf: wat niet onvertaald op het scherm van de gebruiker hoort, hoort al helemaal niet in de committe deliverable.

- **Comments beschrijven wát de code doet en waaróm.** Zelfstandig leesbaar voor iemand die deze mission nooit heeft gezien. Niet wanneer, niet in welke volgorde, niet ten opzichte van wat eerder is gebouwd.
- **Nooit mission-interne codes in code.** Feature-IDs (`F1`, `F3`), milestone-IDs (`M1`), validatiecriteria (`VC-5`) en historie-verwijzingen ("pre-F4", "voor feature X", "stap 2 van de mission") horen nergens in committe code, comments, docstrings of commit messages. Het zijn orkestratie-codes; buiten de mission betekenen ze niets. Echte tokens die toevallig op zo'n code lijken — een flake8 `noqa: F401`, een hexwaarde — zijn geen mission-codes en blijven gewoon staan.
- **Test-docstrings beschrijven het geteste gedrag, niet het criterium-nummer.** Schrijf "Een cross-org file-ref gooit `ValueError` (fail-closed)", niet "VC-6: …".
- **Toets:** zou deze comment nog kloppen en nut hebben als de mission nooit had bestaan? Zo nee, herschrijf.

## Vocabulary

_Voeg een entry toe zodra een term op meer dan één plek wordt gebruikt en één canonieke definitie nodig heeft._

### advisory

Een niet-blokkerende vereenvoudigingsvinding van de reviewer ("kan dit simpeler?"). Een advisory staat los van het reviewvonnis en heeft nooit invloed op de validatiestatus.

### concern

Een vermoedelijk écht defect (categorie: bug, dataverlies of security) dat de reviewer vindt búiten het validatiecontract — het schendt geen enkele meegegeven VC letterlijk, maar zou de gebruiker wél storen. Harde regel: een gevonden gebrek als terzijde parkeren ("not a fail", "known limitation") is verboden — het is óf een FAIL van een passende VC, óf een concern. Een concern raakt validatiestatus noch circuit breaker, maar triggert één begrensde remediatiepas (dezelfde als bij een gefaalde VC). Een concern die de remediatiepas overleeft, landt verplicht in de walkthrough (sectie "Zorgen") en het eindrapport (tabel "Open punten"); een concern die in de remediatie gefixt wordt, verdwijnt (concerns worden per validatieronde vervangen, geen historie). Twijfel en smaak blijven een advisory.

### deferral

Een bewust-uitgestelde uitbreiding of verbetering in een steps-run, vastgelegd bij het stap-akkoord als `{note, when}`: wát is uitgesteld en bij welk signaal het alsnog moet gebeuren. In de code staat op die plek een zelfstandig leesbare comment met plafond + upgrade-pad; het eindrapport verzamelt alle deferrals.

### design budget

De limitatieve lijst in een missieplan van toegestane nieuwe afhankelijkheden en nieuwe abstracties. Het overschrijden van het design budget laat een review zakken.

### eindbeeld-anker

Het verplichte "zo ziet klaar eruit"-blok in een stappenplan: een letterlijk input→output-voorbeeld (CLI/API) of een ASCII-mockup/referentiescreenshot (UI). Smaak-eisen ("oogt strak") mogen alleen bestaan als ze naar dit anker verwijzen.

### gate-moment

Het stopmoment na elke stap in een steps-run. De gebruiker reageert plain text: `ok` (commit + door), `m` (meer detail), `stop` (pauze) of vrije tekst (correctie/vraag/planwijziging). Akkoord op het gate-moment is het enige dat een commit veroorzaakt.

### golden example

Een pad naar een bestaand, exemplarisch bestand in de repo dat een regel in de praktijk demonstreert. Agents en skills verwijzen naar een golden example in plaats van de regel opnieuw uit te leggen.

### rule-kandidaat

Een patroon dat tijdens de mission-finalisatiefase wordt gedestilleerd uit gevonden issues of lessons, en wordt voorgesteld als mogelijke nieuwe `.claude/rules/`-regel. De mens beslist; de runner schrijft zelf nooit regels.

### seam

De publieke interface waarop tests mikken (functie-, endpoint- of CLI-niveau), vooraf afgesproken in het stappenplan. Tests komen alléén op afgesproken seams, nooit op interne details — zo overleven ze refactors.

### stap-rapport

Het vaste rapport (±15 regels) na elke stap van een steps-run: wat kan er nu, waarom zo, bewijs (rood→groen + gate), vers reviewer-oordeel, bestanden, één zelf-zien-commando en de teller "Stap N/M".

### stappenbudget

Het aantal gate-momenten waarin `fwd:steps-plan` een klus snijdt. Eerste token van het argument (`/fwd:steps-plan 5 <doel>`): een getal = precies zoveel stappen, `auto` = fijnmazig (één gedraging per stap), default 3. Een stap bundelt dan meerdere gedragingen (sub-bullets in plan.md): rood→groen per gedraging, maar stap-rapport, reviewer, commit en gate één keer per stap. Bij een duidelijke mismatch doet de planner een tegenvoorstel in één zin — nooit een stilzwijgende wijziging van het aantal.

### tussenbalans

De tussentijdse review na elke 4 goedgekeurde stappen van een steps-run: twee doubt-subagents beantwoorden elk één vraag ("waar zijn we het minst zeker over?" / "wat is de grootste blinde vlek?") in caveman-stijl met bewijs-verwijzingen; de orchestrator consolideert in helder Nederlands mét verdict.

### walkthrough

Het leesbare rapport per mijlpaal (sjabloon gedocumenteerd in `skills/engineering/fwd:mission-run/REFERENCE.md`). Leesbaar in ±5 minuten. Begint altijd met "In één oogopslag".
