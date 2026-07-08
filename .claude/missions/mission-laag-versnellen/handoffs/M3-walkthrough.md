# Milestone M3 — Plan-laag: minder spawns, slimmere spawns

## In één oogopslag
De planfase snijdt features voortaan groter en slimmer, en één geblokkeerde feature legt niet langer de hele rij stil. Drie dingen: de sizing-regel (~30–45 min bouwwerk per feature, kleinere units samenvoegen) met een grill-toets; een additief `depends_on`-veld met een lint en een `pick-next-unit` die geblokkeerde features passeert; en een afgeslankte coder-spawn die de coder een gerichte leeslijst geeft in plaats van de hele repo te laten herlezen, met model/effort naar featuregrootte. Alle schema-wijzigingen zijn additief — oude plannen blijven overal geldig.

**Verdictbalans:** 1 gate (G1 shell-syntax) ✔ · 10 VC's, allemaal PASS ✔ · 0 zorgen · 1 advisory (niet-blokkerend). Eén validatieronde, geen remediatie nodig.

## Leesvolgorde
1. `skills/engineering/fwd:mission-plan/SKILL.md` — sizing-regel (stap 3) + grill-toets (stap 4.5) (F4); reading_list/size-generatie (stap 6) (F6).
2. `skills/engineering/fwd:mission-run/scripts/pick-next-unit.sh` — passeert geblokkeerde features (F5).
3. `skills/engineering/fwd:mission-plan/scripts/validate-artifacts.sh` — `depends_on`-lint (F5).
4. `skills/engineering/fwd:mission-run/SKILL.md` — afgeslankte coder-spawn (stap 2.3) (F6).
5. De twee `REFERENCE.md`'s — schema-v6-velden + Feature sizing.

## Wat is er gebeurd, en waarom

**F4 — sizing-regel.** `fwd:mission-plan` legt nu vast dat één feature ~30–45 minuten bouwwerk is; kleinere verwante units worden samengevoegd. De onderbouwing is de spawn-belasting: elke verse coder betaalt vaste oriëntatie- én afrondingstijd. De grill (stap 4.5) toetst expliciet op te fijn gesneden plannen.
- *Bewijs VC-16:* de sizing-regel in `plan/SKILL.md` stap 3 + de grill-toets in stap 4.5; de "Feature sizing"-sectie in `plan/REFERENCE.md`.

**F5 — `depends_on` + geblokkeerde features passeren.** Een additief `features[].depends_on`-veld. `pick-next-unit.sh` slaat een `blocked`-feature over en levert de eerstvolgende feature die niet (transitief) van niet-done werk afhangt; zit alles vast achter een blokkade, dan exit 3 met een melding (onderscheiden van "alles done" = exit 0). `validate-artifacts.sh` lint het veld (onbekende id, vooruit-verwijzing, cykel) en benoemt de overtreder. Uitvoering blijft strikt serieel — geen parallelle machinerie.
- *Bewijs VC-17:* fixture — A geblokkeerd, B onafhankelijk → B; alles afhankelijk van A → exit 3.
- *Bewijs VC-18:* de lint is gated op de aanwezigheid van `depends_on`; een v1-plan gedraagt zich identiek; `record-feature.sh` is niet gewijzigd.
- *Bewijs VC-19:* de lint-fixtures falen exit 1 op een kapot plan en slagen op een geldig.
- *Bewijs VC-22:* de diff bevat geen sub-worktree-/merge-scripts en geen parallel-spawn-instructie.

**F6 — coder-dieet.** De coder-spawn (`run/SKILL.md` stap 2.3) geeft de feature's `reading_list` mee als volledige oriëntatie-scope, met "lees alléén dit; scan de repo niet opnieuw", neemt gematchte rule-bestanden inline op onder ~200 regels (anders de paden-lijst), en kiest model/effort naar `features[].size` (S/M/L; ontbrekend veld = huidig gedrag). Het plan (`plan/SKILL.md` stap 6) leidt `reading_list` en `size` per feature af.
- *Bewijs VC-20:* de reading_list-instructie + <200-regels-inline-regel in `run/SKILL.md` stap 2.3 en de generatie in `plan/SKILL.md` stap 6.
- *Bewijs VC-21:* de "Model/effort by feature size"-richtlijn in stap 2.3.

## Zelf verifiëren
```
cd .trees/mission/mission-laag-versnellen
grep -n 'samenvoeg' skills/engineering/fwd:mission-plan/SKILL.md
grep -n 'Model/effort by feature size' skills/engineering/fwd:mission-run/SKILL.md
grep -n 'reading_list' skills/engineering/fwd:mission-run/REFERENCE.md
# lint een kapot plan (verwacht non-zero) — bouw een tmp-fixture met een depends_on-cykel
bash -n skills/engineering/fwd:mission-run/scripts/pick-next-unit.sh
bash -n skills/engineering/fwd:mission-plan/scripts/validate-artifacts.sh
```

## Zorgen
Geen.

## Nieuw t.o.v. het design budget
Twee toegestane budget-items aangesproken: de additieve `state.json`-velden `features[].depends_on`, `features[].reading_list` en `features[].size` (schema v6). Geen nieuwe dependency, geen nieuwe top-level map, geen andere abstractie.

## Advisories (niet-blokkerend)
- `pick-next-unit.sh` cycle-guard geeft bij een cykel de accumulator terug in plaats van te falen; onschadelijk omdat `validate-artifacts.sh` cykels al bij plan-time afvangt. Eén regel commentaar dat de runner op die plan-lint vertrouwt, zou de aanname expliciet maken.

Verificatie: 6 paden en 7 symbolen gecontroleerd tegen de diff.
