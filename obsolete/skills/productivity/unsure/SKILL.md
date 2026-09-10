---
name: unsure
description: Noem de 3 zaken waar je het minst zeker van bent — in een plan, ontwerp, diff, aanpak of in je eigen zojuist gegeven antwoord: wat wankelt, waarom, en wat het zou beslechten. Gebruik deze skill zodra iemand twijfel opvraagt of naar een zwakke plek zoekt: "waar ben je het minst zeker van", "wat is je zwakste aanname", "noem de zwakke punten hier", "hoe zeker ben je hiervan", "what are you least confident about", "poke holes in this", of /fwd:unsure. Ook wanneer de vraag terloops klinkt of geen plan noemt — de gebruiker wil dan nog steeds de eerlijke twijfellijst, geen geruststelling.
argument-hint: <bestand | leeg = meest recente plan/antwoord in het gesprek>
allowed-tools: Read, Bash, Glob, Grep
---

# Unsure

Noem 3 zaken waar je minst zeker van bent. Wat + waarom. Repareer niets — benoemen is hele opdracht.

## Doelwit

`$ARGUMENTS` leeg → meest recente plan, ontwerp, diff of antwoord in gesprek. Pad → `Read`. Anders → tekst zelf. Nooit vragen welke; pak voor de hand liggende, noem in kopregel.

## Twijfel vinden

Scan langs deze bronnen — dit zijn de plekken waar zekerheid meestal nep is:

- aanname gedaan, nooit nagekeken
- gok over gedrag van code/API die je niet las
- opdracht kent twee lezingen, jij koos er één
- bewijs dun: één voorbeeld, één run, één bron
- randgeval overgeslagen omdat hoofdpad werkte
- iets buiten je zicht: andermans systeem, productiedata, wat gebruiker weet en jij niet

## Filter

Twijfel moet vastzitten aan **dit** werk. Test: wijs bestand, regel, aanname of keuze aan. Lukt niet → generiek, schrappen. "Tests kunnen flaky zijn" past op elk project en zegt niks; "ik nam aan dat `record-step.sh` commit op schone tree, niet geverifieerd" is twijfel.

Mag je eigen keuze raken. Twijfel die niemand pijn doet is geen twijfel — dan zoek je te oppervlakkig.

## Uitvoer

```
Minst zeker over — <doelwit in paar woorden>

1. <wat — één regel, concreet>
   Waarom: <waarom vertrouwen laag: welke aanname, welk bewijs ontbreekt>
   Check: <het ene ding dat het beslecht — bestand lezen, commando draaien, vraag stellen>

2. ...
3. ...
```

Precies 3, duurste-als-fout eerst. Echt minder → zeg dat, vul niet aan met nep-twijfel. Eerste persoon: jouw vertrouwen, geen review van gebruiker. Onder 25 regels, taal van gesprek.
