# Milestone-review M3 — Plan-laag: minder spawns, slimmere spawns

## In één oogopslag
Alle tien criteria slagen. M3 is een strakke, additieve schema-v6-uitbreiding — twee scripts gewijzigd, vier docs, geen nieuwe bestanden, dependencies of mappen. De reviewer draaide de échte scripts tegen tmp-fixtures: `pick-next-unit.sh` levert een onafhankelijke feature terwijl een geblokkeerde blijft liggen, en meldt met exit 3 de blokkade als alles (transitief) vastzit; `validate-artifacts.sh` faalt non-zero op een onbekende referentie, een vooruit-verwijzing en een cykel (met naam van de overtreder) en laat een geldige diamant door. De coder-dieet-instructies staan volledig in `run/SKILL.md` stap 2.3 en `plan/SKILL.md` stap 6. Comment- en commit-hygiëne schoon; uitvoering blijft aantoonbaar serieel.

## Verdicts (allemaal PASS)
- VC-16 sizing-regel + grill-toets · VC-17 geblokkeerde feature passeren · VC-18 v1 backward-compat · VC-19 lint faalt op kapot plan · VC-20 reading_list + inline rules · VC-21 model/effort naar size · VC-22 serieel, geen parallelle machinerie · VC-23 comment/commit-hygiëne · VC-24 fixtures tegen echte scripts · VC-25 binnen design budget.

## Advisory (niet-blokkerend)
- `pick-next-unit.sh` cycle-guard geeft bij een cykel de accumulator terug in plaats van te falen; onschadelijk omdat `validate-artifacts.sh` cykels al bij plan-time afvangt. Eén regel commentaar dat de runner op die plan-lint vertrouwt, zou de aanname expliciet maken.
