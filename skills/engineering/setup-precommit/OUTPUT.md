# fwd:setup-precommit — output template

Fixed final-message format for `/fwd:setup-precommit`. `scripts/apply-all.sh` prints
one `### <feature>` block per installer, each with `exit=`, `stdout:`, and `stderr:`,
then a `### tracked` block. Turn that into the report below and print it **verbatim**
as your last message, in Dutch, exactly as structured here. Do not paraphrase, add
sections, reorder, or write a free-form summary instead.

## Feature slug → Dutch label

| slug (from `### <feature>`) | label in the report |
|---|---|
| `precommit` | pre-commit hooks |
| `readme` | README-sectie "Git hooks" |
| `legacy` | Resten van setup-review opgeruimd |

List features in this exact order, always all three.

## How to fill each line

- `exit=0` and the **first** `stdout:` line starts with `↷` → icon `–` (skipped).
  Trailing text = that line's text after `↷`, shortened to what was left alone.
  For `precommit` this holds even though a later `✔` line says the git hooks were
  installed.
- other `exit=0` → icon `✓`. Trailing text = the path after the `→` on the
  feature's **first** `stdout:` line; for `precommit` add the hook list from that
  line in parentheses. `legacy` with "nothing left" → trailing text "niets gevonden".
  `legacy` with `removed` lines → "<n> bestanden".
- `exit=2` → icon `⚠`. Trailing text = a short paraphrase of the first line of
  `stderr:` (the full stderr goes under "Aandachtspunten").
- any other exit → icon `✗`. Same rule as `⚠`.

**Top line** — every feature `✓` or `–` → `✅ Pre-commit-setup voltooid`. One or more
`⚠`/`✗` → `⚠️ Pre-commit-setup deels voltooid`.

**Bestanden aangepast** — the path after every `→` on a `✔` line of `precommit` and
`readme`, deduplicated, one per line. Lines with `no change` touched nothing; leave
them out. No path at all → write `- geen (alles stond er al)`.

**Verwijderd** — include when `legacy` printed lines with `removed`: the path after
each `→`, one per line.

**Aandachtspunten** — include when at least one feature is `⚠`/`✗`, or a `✓`
feature left a non-empty `stderr:`. One bullet per such feature: its Dutch label, the
full `stderr:` verbatim, then "Los op en draai `/fwd:setup-precommit` opnieuw."

**Onder versiebeheer** — when the `### tracked` block is non-empty, list those paths,
followed by: "Deze staan onder versiebeheer en zijn nu gewijzigd in je werkboom —
beslis bewust of ze mee mogen in je volgende commit." Otherwise always add this line
instead: "Commit de nieuwe bestanden: een andere clone krijgt de hooks pas na een
pull en `pre-commit install`."

---

## Voorbeeld (exacte vorm)

```
✅ Pre-commit-setup voltooid

Scope: Project-lokaal

Geïnstalleerd:
- ✓ pre-commit hooks → /pad/.pre-commit-config.yaml (gitleaks, file checks, Conventional Commits, ruff, prettier, osv-scanner on push)
- ✓ README-sectie "Git hooks" → /pad/README.md
- ✓ Resten van setup-review opgeruimd → 3 bestanden

Bestanden aangepast:
- /pad/.pre-commit-config.yaml
- /pad/README.md

Verwijderd:
- /pad/.github/workflows/fwd-review.yml
- /pad/.claude/fwd/review-push.sh
- /pad/.claude/fwd/plugin.json

Onder versiebeheer:
- .pre-commit-config.yaml
- README.md

Deze staan onder versiebeheer en zijn nu gewijzigd in je werkboom — beslis bewust of ze mee mogen in je volgende commit.

Je kan /fwd:setup-precommit opnieuw draaien — het herschrijft alleen een config die het zelf schreef.
```

## Vorm bij een conflict

```
⚠️ Pre-commit-setup deels voltooid

Scope: Project-lokaal

Geïnstalleerd:
- ⚠ pre-commit hooks → core.hooksPath staat aan (husky)
- ✓ README-sectie "Git hooks" → /pad/README.md
- ✓ Resten van setup-review opgeruimd → niets gevonden

Bestanden aangepast:
- /pad/.pre-commit-config.yaml
- /pad/README.md

Aandachtspunten:
- pre-commit hooks — ⚠  core.hooksPath is set (.husky), probably by husky; pre-commit will not install its hooks next to it. Remove it (git config --unset core.hooksPath) or call pre-commit from those hooks, then re-run /fwd:setup-precommit. → Los op en draai /fwd:setup-precommit opnieuw.

Commit de nieuwe bestanden: een andere clone krijgt de hooks pas na een pull en `pre-commit install`.

Je kan /fwd:setup-precommit opnieuw draaien — het herschrijft alleen een config die het zelf schreef.
```
