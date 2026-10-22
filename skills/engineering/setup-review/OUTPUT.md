# fwd:setup-review — output template

Fixed final-message format for `/fwd:setup-review`. `scripts/apply-all.sh` prints one
`### <feature>` block per installer, each with `exit=`, `stdout:`, and `stderr:`, then
a `### tracked` block. Turn that into the report below and print it **verbatim** as
your last message, in Dutch, exactly as structured here. Do not paraphrase, add
sections, reorder, or write a free-form summary instead.

## Feature slug → Dutch label

| slug (from `### <feature>`) | label in the report |
|---|---|
| `precommit` | pre-commit met gitleaks en push-hook |
| `workflow` | GitHub Actions-checks |
| `review-flag` | Reviewer aangezet (review: true) |

List features in this exact order, always all three.

## How to fill each line

- `exit=0` with a `stdout:` line starting with `↷` → icon `–` (skipped: the repo
  already had that file). Trailing text = that line's text after `↷`, shortened to
  what was left alone and what was not added.
- other `exit=0` → icon `✓`. Trailing text = the path after the last `→` on that
  feature's `stdout:`.
- `exit=2` → icon `⚠`. Trailing text = a short paraphrase of the first line of
  `stderr:` (the full stderr goes under "Aandachtspunten").
- any other exit → icon `✗`. Same rule as `⚠`.

A feature can have both `✔` and `↷` lines (`workflow`: one file written, the other
already there). Then the icon is `✓` and the trailing text names the written path,
followed by "; <file> bestond al".

**Top line** — every feature `✓` or `–` → `✅ Review-setup voltooid`. One or more
`⚠`/`✗` → `⚠️ Review-setup deels voltooid`.

**Bestanden aangepast** — the path after every `→` on a `✔` line, of any feature
(a `⚠` feature may have written a file before it stopped), deduplicated, one per
line. Lines with `no change` touched nothing; leave them out. The `✔ Git hooks` and
`✔ pre-commit` lines name a command, not a file; leave them out too.
No path at all → write `- geen (alles stond er al)`.

**Aandachtspunten** — include when at least one feature is `⚠`/`✗`, or a `✓`
feature left a non-empty `stderr:`. One bullet per such feature: its Dutch label, the
full `stderr:` verbatim, then "Los op en draai `/fwd:setup-review` opnieuw."

**Onder versiebeheer** — when the `### tracked` block is non-empty, list those paths,
followed by: "Deze staan onder versiebeheer en zijn nu gewijzigd in je werkboom —
beslis bewust of ze mee mogen in je volgende commit." Otherwise always add this line
instead: "Commit de nieuwe bestanden: CI, de Workcenter en je andere machines zien ze
pas na een push."

---

## Voorbeeld (exacte vorm)

```
✅ Review-setup voltooid

Scope: Project-lokaal

Geïnstalleerd:
- ✓ pre-commit met gitleaks en push-hook → /pad/.pre-commit-config.yaml
- ✓ GitHub Actions-checks → /pad/.github/workflows/fwd-osv-weekly.yml
- ✓ Reviewer aangezet (review: true) → /pad/.claude/fwd/plugin.json

Bestanden aangepast:
- /pad/.pre-commit-config.yaml
- /pad/.claude/fwd/review-push.sh
- /pad/.github/workflows/fwd-review.yml
- /pad/.github/workflows/fwd-osv-weekly.yml
- /pad/.claude/fwd/plugin.json

Commit de nieuwe bestanden: CI, de Workcenter en je andere machines zien ze pas na een push.

Je kan /fwd:setup-review opnieuw draaien — het overschrijft niets wat er al staat.
```

## Vorm bij een conflict

```
⚠️ Review-setup deels voltooid

Scope: Project-lokaal

Geïnstalleerd:
- ⚠ pre-commit met gitleaks en push-hook → core.hooksPath staat aan (husky)
- – GitHub Actions-checks → fwd-review.yml bestond al, niet aangepast
- ✓ Reviewer aangezet (review: true) → /pad/.claude/fwd/plugin.json

Bestanden aangepast:
- /pad/.pre-commit-config.yaml
- /pad/.claude/fwd/review-push.sh
- /pad/.claude/fwd/plugin.json

Aandachtspunten:
- pre-commit met gitleaks en push-hook — ⚠  core.hooksPath is set (.husky), probably by husky; pre-commit will not install its hooks next to it. Remove it (git config --unset core.hooksPath) or call pre-commit from those hooks, then re-run /fwd:setup-review. → Los op en draai /fwd:setup-review opnieuw.

Commit de nieuwe bestanden: CI, de Workcenter en je andere machines zien ze pas na een push.

Je kan /fwd:setup-review opnieuw draaien — het overschrijft niets wat er al staat.
```
