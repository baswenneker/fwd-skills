# M3 — Scrutiny review

## In één oogopslag

De run-kant (F6, F7, F8) is volledig en consistent. Alle zes assertions slagen op elke deelclausule. De diff raakt alleen vier `.md`-bestanden; geen enkel script is gewijzigd (bevestigd via `--name-only` en een gerichte script-pad-check), dus VC-18's harde eis 'geen gedeelde scripts gewijzigd' klopt. De coder verklaart gepinde regels bindend en eist verantwoording (`rules_applied`); de reviewer scheidt compliance-verdicts strikt van `advisories[]`; beide runners spiegelen de pinning, de `rules_applied`-afdwinging als mislukte poging, de walkthrough en de rule-kandidaten. Cross-consistentie is in orde: de coder-spawn-stap vraagt exact het veld dat het coder-agent verplicht stelt, en de reviewer-returnvorm (`verdicts` + `advisories`) matcht wat de runner verwerkt (advisories voeden de walkthrough, raken `validation_status` nooit).

## VC-13 — coder volgt regels en legt verantwoording af (PASS)

Vier clausules, alle in `agents/fwd-mission-coder.md`: (1) bindend — r16 'these rules are **binding**' + sectie *Pinned rules* r18-24 '**mandatory** — not suggestions'; (2) `rules_applied` [{rule,how}] verplicht zodra spawn-prompt rule-paden bevat — r60 met schema r54-57; (3) conflict → conservatieve keuze (criterium wint) + melding in `issues_discovered` — r24; (4) eenvoudige taal in narrative — r62 *Narrative style*, verwijst naar 'Schrijfstijl missions' in CONTEXT.md (dat blok bestaat, CONTEXT.md r5-12). Alle vier kloppen.

## VC-14 — reviewer toetst naleving en adviseert over eenvoud (PASS)

`agents/fwd-mission-reviewer.md` r24 toetst Compliance-VCs 'exactly like any other verdict — same PASS/FAIL rigor'; r25 + r39-42 + r46 retourneren `advisories[]` met verplichte `location` + `suggestion`, expliciet 'strictly separate from `verdicts`… never used to fail a VC, change validation status, or burn a retry attempt'. Beide clausules kloppen.

## VC-15 — geen verantwoording, geen geaccepteerde handoff (PASS)

`fwd:mission-run/SKILL.md` stap 2.3 (r99-100) pint per feature het design budget (verbatim uit mission.md) én de `rule_paths` als 'mandatory reading list… these rules are binding'. Stap 2.4 (r111) telt een handoff die bij niet-lege `rule_paths` geen niet-leeg `rules_applied` heeft als mislukte poging onder de bestaande attempt-regels. Beide clausules kloppen.

## VC-16 — elke milestone eindigt met een walkthrough; advies blokkeert niets (PASS)

Stap 2.5 r152 schrijft `handoffs/<milestone>-walkthrough.md` 'regardless of `validation_status`' volgens het REFERENCE.md-template; dat template (REFERENCE.md r250-283) bevat alle vereiste secties: 'In één oogopslag', 'Leesvolgorde', per-feature 'Wat/waarom' + 'Sleutelbestanden' + 'Zelf verifiëren'-commando's, en 'Advisories'. r154-160 zet `walkthrough_path` via atomaire jq-write. r143 stelt expliciet 'Advisories from the reviewer never influence `validation_status`'. Alle drie clausules kloppen.

## VC-17 — de missie stelt regels voor, de mens beslist (PASS)

Finalize-stap r186: eindrapport MOET een 'rule-kandidaten'-sectie bevatten, gedistilleerd uit `issues_discovered` over alle handoffs én uit lessen; en '**The runner never mutates `.claude/rules/` itself.**' Beide clausules kloppen.

## VC-18 — de parallel runner doet exact hetzelfde (PASS)

`fwd:mission-run-parallel/SKILL.md`: stap 3.4 (r127-128) spiegelt design-budget + `rule_paths`-pinning; de `rules_applied`-afdwinging zit in stap 3.5 (r160-162: re-spawn of blocked) — direct naast 3.4; stap 3.7 (r198 advisories-clausule, r207-217 walkthrough + `walkthrough_path`) spiegelt de serial walkthrough/advisories. Geen scripts gewijzigd: `--name-only` toont alleen vier `.md`-paden, en een gerichte `*.sh`/scripts-pad-diff is leeg. De interop-sectie blijft kloppen (r277-291, met r291 nieuw: v3-velden optioneel/additief, runner-switching veilig). Alle drie clausules kloppen.
