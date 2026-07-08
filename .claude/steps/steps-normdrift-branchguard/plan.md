# Stappenplan: steps-laag verharden met lessen uit mission-laag-versnellen

*Doel: pas de twee overdraagbare lessen uit mission-laag-versnellen toe op de steps-laag — inline-norm-drift borgen en committen op de verkeerde branch voorkomen. Branch: `steps/steps-normdrift-branchguard`. Gate: `find agents skills scripts -name '*.sh' -print0 | xargs -0 -r -n1 bash -n`.*

## Herkomst

Analyse van mission-laag-versnellen (4 versnellings-fronten + proces-lessen), gelegd naast de steps-laag:

| Mission-front / les | Van toepassing op steps? |
|---|---|
| Normen inline + rtk-pipe/`find /`-verbod in agents | Al gedaan (M1 raakte `fwd-steps-reviewer` + `-doubt`) |
| Handoff-admin → Haiku-scribe | Nee — steps' stap-rapport is bewust uit eerste hand |
| Grotere features + `depends_on` | Nee — steps kent geen coder-spawn, stappen zijn bewust klein en strikt serieel |
| Reviewer vertrouwt gate-uitslag, geen her-run | Beslissing gebruiker (8 juli 2026): **laten zoals het is** — de onafhankelijke gate-run blijft het vertrouwens-anker per stap |
| Les A: inline-norm-drift | **Ja** — 5 agents dragen hand-kopieën van dezelfde norm-blokken; M1 zakte hier al één keer op |
| Les B: commit op de juiste branch | **Ja** — `record-step.sh` commit zonder branch-check |
| Les C: `for-each-ref` i.p.v. `git branch --format` | Al gefixt in `status.sh` |

Regels: bewust zonder `.claude/rules/` (leeg in deze repo; keuze gebruiker 8 juli 2026).

## Definition of Done
1. `scripts/check-agent-norms.sh` faalt (exit ≠ 0) zodra twee inline-kopieën van een gedeeld norm-blok uiteenlopen, en slaagt (exit 0) als ze byte-identiek zijn.
2. Na uitlijnen slaagt datzelfde script zónder argumenten op de échte `agents/`: het bewaakt één gedeeld blok — `## Shared tool prohibitions` (de rtk-pipe- en `find /`-verboden) — over de 5 agents die het dragen, en die kopieën zijn byte-identiek.
3. `record-step.sh` weigert te committen (exit ≠ 0 + heldere melding) als de worktree-HEAD niet op de plan-branch (`state.json`'s `.branch`) staat; op de juiste branch commit hij exact als nu.
4. Gate G1 groen: `bash -n` over alle gewijzigde `*.sh`; geen nieuwe tooling of dependencies.

> **Herijkt bij S3 (8 juli 2026):** de oorspronkelijke aanname — dat `## Behavior prohibitions` en `## Comment hygiene norm` complete hand-kopieën zijn die byte-identiek horen te zijn — bleek fout. Die blokken zijn bewust per rol anders (coder lévert een handoff, validators rapporteren evidence; mission-agents verwijzen naar mission/VC-codes, steps-agents naar plan/step-codes). Alleen twee regels zijn écht universeel: het rtk-pipe-verbod en het `find /`-verbod. Optie A: die twee worden afgesplitst naar een strak identiek `## Shared tool prohibitions`-blok in alle 5 agents; de rol-specifieke regels blijven in `## Behavior prohibitions`. De guard bewaakt alleen het gedeelde blok. `Comment hygiene norm` blijft ongemoeid.

## Eindbeeld
```
# Les B — record-step.sh op de verkeerde branch
$ ( cd <worktree-op-main> && echo '{}' | record-step.sh demo S1 "feat: x" )
refusing to commit: worktree HEAD is 'main', expected 'steps/demo' (.branch)
$ echo $?        → 1        # op steps/demo: commit als vanouds, recorded=S1 …

# Les A — norm-drift-check
$ bash scripts/check-agent-norms.sh
ok — 'Shared tool prohibitions' identiek over 5 bestanden
$ echo $?        → 0
# na één kopie muteren:
DRIFT — 'Shared tool prohibitions': agents/fwd-steps-doubt.md ≠ agents/fwd-mission-coder.md
  <unified diff van het blok>
$ echo $?        → 1
```

## Seams (testplekken)
- `scripts/check-agent-norms.sh` — nieuw script, top-level `scripts/` (overspant de héle `agents/`-map, hoort niet onder één skill). Getest via CLI: exit-code + drift-melding.
- `skills/engineering/fwd:steps-run/scripts/record-step.sh` — bestaand. Getest via CLI: exit-code + melding op de verkeerde branch.

Geen unit-testframework in deze repo → elk klaar-criterium is een draaibaar fixture-commando (bewust; toegestaan voor bash-wiring).

## Stappen
- [x] S1 — Branch-guard in `record-step.sh`: het script weigert te committen als de worktree-HEAD niet op `state.json`'s `.branch` staat. Klaar als: fixture-repo met `.branch="steps/demo"`, HEAD op een andere branch → `record-step.sh demo S1 "msg"` exit ≠ 0 + melding met verwachte branch; op `steps/demo` → exit 0, commit gemaakt, `recorded=S1`. Regels: geen
- [x] S2 — `check-agent-norms.sh`: het drift-mechanisme. Nieuw script dat een genoemd blok (tussen `## <kop>` en de volgende `## `/EOF) uit meerdere bestanden knipt en faalt als ze niet byte-identiek zijn. Klaar als: twee tijdelijke `.md`-fixtures met een `## Behavior prohibitions`-blok → identiek geeft exit 0; één regel gemuteerd geeft exit 1 + unified diff. Regels: geen
- [x] S3 — Gedeelde kern afsplitsen + guard richten + documenteren (Optie A): de twee universele verboden (rtk-pipe, `find /`) worden uit `## Behavior prohibitions` gelicht naar een strak identiek `## Shared tool prohibitions`-blok in alle 5 agents; de rol-specifieke regels blijven staan. `check-agent-norms.sh` krijgt een no-arg modus die dat blok over de 5 agents bewaakt. CLAUDE.md benoemt het script + wanneer te draaien. Klaar als: `bash scripts/check-agent-norms.sh` → exit 0 op de echte agents; `grep -q check-agent-norms.sh CLAUDE.md` → aanwezig. Regels: geen
