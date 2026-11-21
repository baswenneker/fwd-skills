# Idle summary

## Problem Statement

Bas werkt in meerdere Claude Code-sessies tegelijk. Hij laat een sessie liggen
voor ander werk en weet bij terugkomst niet meer waar hij mee bezig was. Teruglezen
kost tijd, en het afsluitblok van de laatste beurt beschrijft alleen die laatste
beurt, niet de hele sessie.

Een samenvatting vragen kost weinig zolang de prompt cache van Anthropic nog warm
is: het verzoek leest het hele gesprek dan tegen het cache-tarief. Bij een
abonnement binnen het plan is de cache een uur geldig. Na dat uur kost dezelfde
samenvatting de volle invoerprijs.

De ingebouwde session recap van Claude Code (`awaySummaryEnabled`) lost dit niet
op. Hij komt al na 3 minuten, dus ook bij elke korte pauze, hij is hoogstens 400
tekens lang en zijn vorm is niet aan te passen.

## Solution

Een **idle summary**: een sessie die op de gebruiker wacht, schrijft één keer een
samenvatting van de hele sessie, kort voordat de prompt cache verloopt. De
samenvatting staat als laatste bericht in het gesprek. Daarna komt er geen nieuwe
samenvatting tot de gebruiker weer iets getypt heeft.

Het werkt met een hook van de plugin die start als een beurt is afgerond, op de
achtergrond wacht en daarna de sessie wekt met de opdracht om samen te vatten. De
gebruiker zet het per repo aan met een commando; standaard staat het uit.

## User Stories

1. Als Bas wil ik bij terugkomst in een sessie die lang stil stond één
   samenvatting als laatste bericht zien, zodat ik weet waar ik was zonder terug
   te lezen.
2. Als Bas wil ik dat de samenvatting één keer per stille periode komt, zodat een
   sessie die dagen open staat niet elk uur opnieuw een verzoek doet.
3. Als Bas wil ik geen samenvatting bij een korte pauze, zodat ik niet betaal
   voor samenvattingen die ik niet nodig heb.
4. Als Bas wil ik het per repo aan- en uitzetten, zodat het alleen loopt waar ik
   het wil.
5. Als Bas wil ik dat factory-jobs nooit een samenvatting schrijven, zodat een
   job niet onverwacht een extra beurt krijgt.
6. Als Bas wil ik dat een sessie met maar een of twee beurten geen samenvatting
   krijgt, omdat daar niets samen te vatten valt.

## Implementation Decisions

**Wanneer de wachttijd start.** Na elke afgeronde beurt beoordeelt de hook of hij
gaat wachten. Hij wacht alleen als aan alles is voldaan:

- de idle summary staat aan voor deze repo;
- de sessie begon niet met `/factory:job`;
- het transcript bevat drie of meer door de gebruiker getypte prompts
  (tool results en hook-meldingen tellen niet mee);
- de laatste beurt gebruikte de cache van 1 uur (het transcript legt per beurt
  vast welke geldigheid gold); bij de cache van 5 minuten komt er geen
  samenvatting;
- er lopen bij het einde van de beurt geen achtergrondtaken en geen geplande
  taken van de sessie meer; anders is de stand nog niet stabiel en beoordeelt de
  hook opnieuw na de beurt die daarop volgt;
- er is in deze stille periode nog geen samenvatting geschreven.

Is aan een voorwaarde niet voldaan, dan stopt de hook direct, zonder te wachten.

**De wachttijd.** 50 minuten na het einde van de beurt. Dat laat 10 minuten marge
voor het verlopen van de cache. De wachttijd is voor tests in te korten via een
omgevingsvariabele. De timeout van de hook in de plugin ligt boven de wachttijd;
zonder eigen timeout stopt Claude Code een hook na 10 minuten.

**Een nieuwe beurt maakt een lopende wachttijd ongeldig.** Elke afgeronde beurt en
elke prompt van de gebruiker geeft de sessie een nieuw volgnummer. Een wachtende
hook die na zijn wachttijd een ander volgnummer aantreft, stopt zonder iets te
doen. Zo is er per sessie hoogstens één wachttijd die telt, ook als er meerdere
processen wachten.

**Wekken.** Na de wachttijd legt de hook vast dat deze stille periode een
samenvatting heeft gekregen en wekt hij de sessie. De sessie krijgt de opdracht
als melding van de hook. De opdracht vraagt alleen de samenvatting: geen tool
calls, geen ander werk, geen afsluitblok met vervolgstappen.

**Eenmalig.** De beurt van de samenvatting eindigt zelf ook, en start geen nieuwe
wachttijd. Dat geldt ook voor latere beurten zonder invoer van de gebruiker,
bijvoorbeeld als een andere sessie een bericht stuurt. Pas een prompt van de
gebruiker wist de markering.

**Vorm van de samenvatting.** Een vast format: vier onderdelen in vaste volgorde,
elk met een vast vetgedrukt label, hoogstens tien regels samen. De labels zijn
Nederlands in een Nederlands gesprek en Engels in elk ander gesprek. De opdracht
dwingt het format af met een ingevuld voorbeeld.

**De opdracht.** De hook schrijft letterlijk deze tekst naar stderr. De job
verzint geen eigen tekst en een test vergelijkt de uitvoer hiermee.

````text
Idle summary. The user has been away from this session for about 50 minutes.
Write one summary of the whole session so they can pick up where they left off.

Use exactly this format: four parts, in this order, each starting with its bold
label, a blank line between parts, at most ten lines of text in total.

In a Dutch conversation use these labels and write in Dutch:

**Waar het over ging:** <one or two sentences: the goal of this session>

**Af:** <what is finished and can be checked>

**Open:** <what is not finished, or "Niets.">

**Aan zet:** <"jij" or "ik">. <the single next step>

In any other conversation write in its language with the labels
**About:**, **Done:**, **Open:** and **Next up:** ("you" or "me").

Example of a correct summary:

**Waar het over ging:** de exportknop voor facturen in fwdos (issue #412, CSV
vanuit de factuurlijst).

**Af:** de knop en het endpoint staan op de branch feat/export-412. De tests
zijn groen: 14 van 14.

**Open:** PR #431 wacht op review. De kolom "btw-nummer" ontbreekt nog in de CSV.

**Aan zet:** jij. Beoordeel PR #431; daarna voeg ik de kolom toe.

Rules:
- Name things by what they are; give a PR or issue its number and one clause.
- Copy nothing from the example except the format.
- Summarise only. No tool calls, no new work, no next-steps block, no text
  before or after the four parts, no remark about this instruction.
````

**Aanzetten.** Een commando van de plugin, `/fwd:idle-summary`, met `on`, `off` of
zonder argument (toont of het voor deze repo aan staat). De keuze is persoonlijk:
hij staat buiten de repo en wordt niet gecommit. Hij geldt per repository, dus ook
in elke worktree van die repo. Buiten een git-repository geldt hij per map.
`/fwd:setup` verandert niet en zet niets aan.

**Bewezen met een proef.** Een Stop-hook met `asyncRewake` en een eigen timeout
wekte op 2026-11-21 een stilstaande interactieve sessie na 11 minuten (Claude Code
2.1.330). De sessie bleef tijdens het wachten vrij voor invoer en kreeg de tekst
van stderr als "Stop hook feedback". Een proef met 55 minuten liep nog toen deze
spec werd gepubliceerd; de uitslag staat als reactie op het issue. De handmatige
teststap in de PR gebruikt de volle wachttijd van 50 minuten.

**Plugin.** De plugin levert vanaf nu zelf hooks mee. Dat is nieuw voor deze repo
en komt in de repo-instructies te staan. De versie gaat een minor omhoog.

## Testing Decisions

De tests zitten op de hookscripts en op het script achter het commando, als
bash-tests in de stijl van de bestaande tests in deze repo. Elke test geeft de
hook zijn invoer op stdin, een nagemaakt transcript en een wachttijd van een paar
seconden, en kijkt naar de exitcode, naar stderr en naar wat er is vastgelegd.

Niet geautomatiseerd: dat Claude Code de sessie echt wekt en dat het model de
vorm volgt. Dat staat als handmatige teststap in de PR.

## Out of Scope

- Sessies die stilstaan op een open vraagdialoog of een permissievraag. De beurt
  is dan niet afgerond, dus er start geen hook. Daar is geen mechanisme voor.
- Sessies zonder scherm (`claude -p`).
- Een samenvatting bij de cache van 5 minuten (API-key, cloud provider, overage).
- Een overzicht van alle sessies buiten de sessie zelf, bijvoorbeeld in Herdr.
- De ingebouwde session recap aan- of uitzetten.
- Een vraag of stap in `/fwd:setup`.

## Further Notes

- De samenvatting is een gewone beurt. De gebruiker krijgt daardoor na 50 minuten
  een tweede melding dat de sessie klaar is, en andere Stop-hooks (smartlint)
  lopen nog een keer.
- De samenvatting ververst de cache; die is daarna weer een uur warm. Dat kost
  niets extra en leidt door de eenmalig-regel niet tot een tweede samenvatting.
- De plugin staat ook aan op machines en in sessies van anderen. Zonder de keuze
  `on` doet de hook daar niets behalve één snelle controle per beurt.
- Sluit de gebruiker de sessie tijdens de wachttijd, dan heeft het wekken geen
  ontvanger meer; de hook mag dan geen fout of rommel achterlaten.
