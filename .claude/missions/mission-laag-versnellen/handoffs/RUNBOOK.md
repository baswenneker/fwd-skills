# RUNBOOK — mission-laag-versnellen

Deze missie levert geen bootbare app op: `fwd-skills` is een Claude Code skills-plugin (markdown + bash). "Draaien" betekent hier: de gewijzigde skills gebruiken en de scripts verifiëren.

## Wat is er gewijzigd
- **5 agent-definities** (`agents/fwd-mission-*.md`, `fwd-steps-*.md`): normen inline, rtk/zoek-gedragsverbod.
- **1 nieuwe agent**: `agents/fwd-mission-scribe.md` (Haiku, read-only) — compileert milestone-walkthroughs.
- **run-machinerie**: `record-feature.sh` (untracked narrative + handoff-validatie), `pick-next-unit.sh` (passeert geblokkeerde features).
- **plan-machinerie**: `validate-artifacts.sh` (`depends_on`-lint), `SKILL.md`/`REFERENCE.md` (sizing-regel, reading_list, size).

## Benodigde omgeving
- Geen env vars, geen secrets. Alleen `bash` en `jq` (voor de mission-scripts), en `rtk` voor git.
- Geen login/credentials.

## Demo-stappen (read-only, lokaal)
1. **Shell-syntax-gate** (alle scripts): `find skills agents -name '*.sh' -print0 | xargs -0 -n1 bash -n` → geen output, exit 0.
2. **Nieuwe scribe-agent bestaat en is read-only**: `grep -n 'model: haiku' agents/fwd-mission-scribe.md` en `grep '^tools:' agents/fwd-mission-scribe.md` (geen Write/Edit).
3. **depends_on-lint verwerpt een kapot plan / accepteert een geldig**: bouw een tmp-fixture (zie proef hieronder) en draai `validate-artifacts.sh` → exit 1 op cykel, exit 0 op geldig.
4. **pick-next-unit passeert een geblokkeerde feature**: met een fixture waarin A `blocked` is en B onafhankelijk → levert B.
5. **Agents verwijzen niet meer naar CONTEXT.md**: `grep -rn 'CONTEXT.md' agents/` → geen treffers.

## Laatst geverifieerd
(zie hieronder — ingevuld door de cold-start-proef)

## Laatst geverifieerd (cold-start-proef, verse her-uitvoering)
- Gate G1 `bash -n` over alle scripts → exit 0.
- `agents/fwd-mission-scribe.md` → `model: haiku`, tools-allowlist zonder Write/Edit.
- `grep -rn 'CONTEXT.md' agents/` → geen treffers (agents zelfvoorzienend).
- `pick-next-unit.sh` op de afgeronde missie → lege output, exit 0 (correct "alles done"-signaal).
- `validate-artifacts.sh` en de gehardde `record-feature.sh` zijn deze sessie onafhankelijk door de reviewer-subagents tegen wegwerp-fixtures gedraaid (kapot plan → non-zero; geldig → exit 0; ongeldige handoff → non-zero).
