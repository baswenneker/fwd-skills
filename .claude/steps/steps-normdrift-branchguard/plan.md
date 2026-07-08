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
2. Na uitlijnen slaagt datzelfde script op de échte `agents/` — alle kopieën van elk gedeeld blok identiek.
3. `record-step.sh` weigert te committen (exit ≠ 0 + heldere melding) als de worktree-HEAD niet op de plan-branch (`state.json`'s `.branch`) staat; op de juiste branch commit hij exact als nu.
4. Gate G1 groen: `bash -n` over alle gewijzigde `*.sh`; geen nieuwe tooling of dependencies.

## Eindbeeld
```
# Les B — record-step.sh op de verkeerde branch
$ ( cd <worktree-op-main> && echo '{}' | record-step.sh demo S1 "feat: x" )
refusing to commit: worktree HEAD is 'main', expected 'steps/demo' (.branch)
$ echo $?        → 1        # op steps/demo: commit als vanouds, recorded=S1 …

# Les A — norm-drift-check
$ bash scripts/check-agent-norms.sh
ok — 'Behavior prohibitions' identiek over 5 agents
ok — 'Comment hygiene norm' identiek over 2 agents
$ echo $?        → 0
# na één kopie muteren:
DRIFT — 'Behavior prohibitions': agents/fwd-steps-doubt.md ≠ agents/fwd-mission-coder.md
  <unified diff van het blok>
$ echo $?        → 1
```

## Seams (testplekken)
- `scripts/check-agent-norms.sh` — nieuw script, top-level `scripts/` (overspant de héle `agents/`-map, hoort niet onder één skill). Getest via CLI: exit-code + drift-melding.
- `skills/engineering/fwd:steps-run/scripts/record-step.sh` — bestaand. Getest via CLI: exit-code + melding op de verkeerde branch.

Geen unit-testframework in deze repo → elk klaar-criterium is een draaibaar fixture-commando (bewust; toegestaan voor bash-wiring).

## Stappen
- [ ] S1 — Branch-guard in `record-step.sh`: het script weigert te committen als de worktree-HEAD niet op `state.json`'s `.branch` staat. Klaar als: fixture-repo met `.branch="steps/demo"`, HEAD op een andere branch → `record-step.sh demo S1 "msg"` exit ≠ 0 + melding met verwachte branch; op `steps/demo` → exit 0, commit gemaakt, `recorded=S1`. Regels: geen
- [ ] S2 — `check-agent-norms.sh`: het drift-mechanisme. Nieuw script dat een genoemd blok (tussen `## <kop>` en de volgende `## `/EOF) uit meerdere bestanden knipt en faalt als ze niet byte-identiek zijn. Klaar als: twee tijdelijke `.md`-fixtures met een `## Behavior prohibitions`-blok → identiek geeft exit 0; één regel gemuteerd geeft exit 1 + unified diff. Regels: geen
- [ ] S3 — Richten op de echte agents + drift uitlijnen + documenteren: het script draait over de echte `agents/` voor beide gedeelde blokken (`Behavior prohibitions` over 5 agents, `Comment hygiene norm` over 2), bestaande drift wordt uitgelijnd, en CLAUDE.md benoemt het script + wanneer te draaien. Klaar als: `bash scripts/check-agent-norms.sh` → exit 0 op de echte agents; `grep -q check-agent-norms.sh CLAUDE.md` → aanwezig. Regels: geen
