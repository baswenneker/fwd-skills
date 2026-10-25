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
| `baseline` | Bestaande fouten opgeruimd |

List features in this exact order, always all four.

## How to fill each line

- `exit=0` and the **first** `stdout:` line starts with `↷` → icon `–` (skipped:
  the repo already had that file). Trailing text = that line's text after `↷`,
  shortened to what was left alone and what was not added. For `precommit` this
  holds even though later `✔` lines say the git hooks were installed.
- other `exit=0` → icon `✓`. Trailing text = the path after the `→` on the
  feature's **first** `stdout:` line. When a later line starts with `↷` (`workflow`:
  the pull-request file written, the weekly one already there), add
  "; <file name> bestond al".
- `exit=2` → icon `⚠`. Trailing text = a short paraphrase of the first line of
  `stderr:` (the full stderr goes under "Aandachtspunten").
- any other exit → icon `✗`. Same rule as `⚠`.

`baseline` on a `✔` line → icon `✓`, trailing text = "commit <sha>, <n> bestanden" (the
sha and count from that line). It wrote no file of its own, so it adds nothing to
"Bestanden aangepast".

Lines starting with two spaces and `(` are notes (`(no osv-scanner: ...)`); put
each one, translated, as a sub-bullet under its feature.

**Top line** — every feature `✓` or `–` → `✅ Review-setup voltooid`. One or more
`⚠`/`✗` → `⚠️ Review-setup deels voltooid`.

**Bestanden aangepast** — the path after every `→` on a `✔` line, of any feature
(a `⚠` feature may have written a file before it stopped), except `baseline`,
deduplicated, one per line. Lines with `no change` touched nothing; leave them out.
No path at all → write `- geen (alles stond er al)`.

**Aandachtspunten** — include when at least one feature is `⚠`/`✗`, or a `✓`
feature left a non-empty `stderr:`. One bullet per such feature: its Dutch label, the
full `stderr:` verbatim, then "Los op en draai `/fwd:setup-review` opnieuw."

**Nog met de hand op te lossen** — include when `baseline` printed lines starting
with `!`. Put every line after the first `!` line in a code block, with the leading
`!   ` removed, then: "De autofixes konden dit niet oplossen. Los het op en commit het,
anders faalt de check `pre-commit` op de eerste PR."

**Onder versiebeheer** — when the `### tracked` block is non-empty, list those paths,
followed by: "Deze staan onder versiebeheer en zijn nu gewijzigd in je werkboom —
beslis bewust of ze mee mogen in je volgende commit." Otherwise always add this line
instead: "Commit de nieuwe bestanden: CI, de Workcenter en je andere machines zien ze
pas na een push."

**Andere clones** — always add this line, unless `precommit` is `⚠`/`✗`: "Op elke
andere clone van deze repo (de Workcenter, een andere machine): na de pull één keer
`pre-commit install`, anders draaien de hooks daar niet. Worktrees van een clone
delen zijn hooks en hebben dat niet nodig." Do not tell the user to run
`/fwd:setup-review` there: the files arrive through git.

---

## Voorbeeld (exacte vorm)

```
✅ Review-setup voltooid

Scope: Project-lokaal

Geïnstalleerd:
- ✓ pre-commit met gitleaks en push-hook → /pad/.pre-commit-config.yaml
- ✓ GitHub Actions-checks → /pad/.github/workflows/fwd-review.yml
- ✓ Reviewer aangezet (review: true) → /pad/.claude/fwd/plugin.json
- ✓ Bestaande fouten opgeruimd → commit 28bd330, 3 bestanden

Bestanden aangepast:
- /pad/.pre-commit-config.yaml
- /pad/.claude/fwd/review-push.sh
- /pad/.claude/fwd/worktree-deps.sh
- /pad/.github/workflows/fwd-review.yml
- /pad/.github/workflows/fwd-osv-weekly.yml
- /pad/.claude/fwd/plugin.json

Nog met de hand op te lossen:
    eslint: tests/helpers/database.ts
    eslint:   19:13  error  Without `.where(...)` you will delete all the rows in a table.  drizzle/enforce-delete-with-where
    eslint: ✖ 1 problem (1 error, 0 warnings)

De autofixes konden dit niet oplossen. Los het op en commit het, anders faalt de check `pre-commit` op de eerste PR.

Commit de nieuwe bestanden: CI, de Workcenter en je andere machines zien ze pas na een push.

Op elke andere clone van deze repo (de Workcenter, een andere machine): na de pull één keer `pre-commit install`, anders draaien de hooks daar niet. Worktrees van een clone delen zijn hooks en hebben dat niet nodig.

Je kan /fwd:setup-review opnieuw draaien — het overschrijft geen config of workflow die er al staat.
```

## Vorm bij een conflict

```
⚠️ Review-setup deels voltooid

Scope: Project-lokaal

Geïnstalleerd:
- ⚠ pre-commit met gitleaks en push-hook → core.hooksPath staat aan (husky)
- – GitHub Actions-checks → fwd-review.yml bestond al, niet aangepast
- ✓ Reviewer aangezet (review: true) → /pad/.claude/fwd/plugin.json
- – Bestaande fouten opgeruimd → niet-gecommitte wijzigingen, niets aangepast; commit of stash ze en draai opnieuw

Bestanden aangepast:
- /pad/.pre-commit-config.yaml
- /pad/.claude/fwd/review-push.sh
- /pad/.claude/fwd/plugin.json

Aandachtspunten:
- pre-commit met gitleaks en push-hook — ⚠  core.hooksPath is set (.husky), probably by husky; pre-commit will not install its hooks next to it. Remove it (git config --unset core.hooksPath) or call pre-commit from those hooks, then re-run /fwd:setup-review. → Los op en draai /fwd:setup-review opnieuw.

Commit de nieuwe bestanden: CI, de Workcenter en je andere machines zien ze pas na een push.

Je kan /fwd:setup-review opnieuw draaien — het overschrijft geen config of workflow die er al staat.
```
