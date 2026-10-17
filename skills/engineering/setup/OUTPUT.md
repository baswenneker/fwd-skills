# fwd:setup — output template

Fixed final-message format for `/fwd:setup`. `scripts/apply-all.sh` prints one
`### <feature>` block per installer, each with `exit=`, `stdout:`, and
`stderr:` (only `grilling` writes outside the project, to `~/.claude/CLAUDE.md`, which is why the `Scope:` line names it), then a `### tracked` and a `### followup` block. Turn that into the report below and print it **verbatim** as your
last message, in Dutch, exactly as structured here. Do not paraphrase, add
sections, reorder, or write a free-form summary instead — this is a fixed
report, not something to compose.

## Feature slug → Dutch label

| slug (from `### <feature>`) | label in the report |
|---|---|
| `smartlint` | Smartlint Stop-hook |
| `lessons` | Lessons memory file |
| `gitignore` | Gitignore entries voor fwd artefacten |
| `clear-context-on-plan` | Clear-context prompt |
| `no-attribution` | Attribution uitgeschakeld |
| `grilling` | Grilling-regel (globaal) |

List features in this exact order, always all six.

## How to fill each line

- `exit=0` → icon `✓`. Trailing text = the last `→ <path or omschrijving>`
  found on that feature's `stdout:`.
- `exit=2` → icon `⚠`. Trailing text = a short paraphrase of the first line
  of `stderr:` (the full stderr goes under "Aandachtspunten", not here).
- any other exit → icon `✗`. Same rule as `⚠`.

**Top line** — every feature `✓` → `✅ Setup voltooid`. One or more `⚠`/`✗`
→ `⚠️ Setup deels voltooid`.

**Bestanden aangepast** — collect the text following every `→` on a
`stdout:` line, across all `✓` features only, deduplicated, one per line.
`⚠`/`✗` features touched nothing — never list a path for them here.

**Aandachtspunten** — include this section (heading included) when at least
one feature is `⚠`/`✗`, **or** when a `✓` feature left a non-empty `stderr:`.
One bullet per such feature: its Dutch label, the full `stderr:` verbatim,
then "Los op en draai `/fwd:setup` opnieuw." For a `✓` feature with stderr,
open the bullet with *Let op (installatie geslaagd, met kanttekening)* — an
installer can succeed and still warn, and that warning must never disappear.
Omit the entire section only when every feature is `✓` **and** every
`stderr:` is empty.

**Onder versiebeheer** — `apply-all.sh` ends with a `### tracked` block
listing the touched files that git tracks. Is that block non-empty, then add
this section after "Bestanden aangepast", listing those paths, followed by
one line: "Deze staan onder versiebeheer en zijn nu gewijzigd in je
werkboom — beslis bewust of ze mee mogen in je volgende commit." Omit the
whole section when the block is empty (nothing tracked, or no git repo).

**Vervolgstap** — `apply-all.sh` ends with a `### followup` block. Does it
contain `mattpocock-setup`, then close the report with one extra line after
the "opnieuw draaien" line:

```
Vervolgstap: draai /mattpocock-skills:setup-matt-pocock-skills — die legt de issue tracker, de triage-labels en de plek van de domain docs vast. Let op: die wizard stelt wel vragen, deze niet.
```

Omit the line entirely when the block is empty. Never invent a follow-up
that the block does not name, and never run one — this wizard installs
nothing outside its own six features.

---

## Happy-path voorbeeld (echte output — dit is de exacte vorm)

```
✅ Setup voltooid

Scope: Project-lokaal, behalve de grilling-regel (globaal, ~/.claude/CLAUDE.md)

Geïnstalleerde conventies:
- ✓ Smartlint Stop-hook → /Users/bas/Development/Accounts/Artific/res-202-agent-loop/.claude/hooks/
- ✓ Lessons memory file → /Users/bas/Development/Accounts/Artific/res-202-agent-loop/.claude/lessons/LESSONS.md
- ✓ Gitignore entries voor fwd artefacten → .gitignore
- ✓ Clear-context prompt → ingesteld in settings.local.json
- ✓ Attribution uitgeschakeld → commits/PRs zonder byline en trailers
- ✓ Grilling-regel (globaal) → /Users/bas/.claude/CLAUDE.md

Bestanden aangepast:
- .claude/settings.local.json
- CLAUDE.md (Lessons-sectie toegevoegd)
- .gitignore
- /Users/bas/.claude/CLAUDE.md

Onder versiebeheer:
- CLAUDE.md
- .gitignore

Deze staan onder versiebeheer en zijn nu gewijzigd in je werkboom — beslis bewust of ze mee mogen in je volgende commit.

Je kan /fwd:setup opnieuw draaien — alle installers zijn idempotent.

Vervolgstap: draai /mattpocock-skills:setup-matt-pocock-skills — die legt de issue tracker, de triage-labels en de plek van de domain docs vast. Let op: die wizard stelt wel vragen, deze niet.
```

## Vorm bij een conflict — zelfde skelet, plus Aandachtspunten

```
⚠️ Setup deels voltooid

Scope: Project-lokaal, behalve de grilling-regel (globaal, ~/.claude/CLAUDE.md)

Geïnstalleerde conventies:
- ✓ Smartlint Stop-hook → /pad/.claude/hooks/
- ✓ Lessons memory file → /pad/.claude/lessons/LESSONS.md
- ⚠ Gitignore entries voor fwd artefacten → corrupte markers in .gitignore
- ✓ Clear-context prompt → ingesteld in settings.local.json
- ✓ Attribution uitgeschakeld → commits/PRs zonder byline en trailers
- ✓ Grilling-regel (globaal) → /pad-naar-home/.claude/CLAUDE.md

Bestanden aangepast:
- .claude/settings.local.json
- .claude/lessons/LESSONS.md
- /pad-naar-home/.claude/CLAUDE.md

Aandachtspunten:
- Gitignore entries voor fwd artefacten — ⚠ Found start marker but no end marker in .gitignore. The gitignore section is corrupt. Repair the markers (or delete the region between them) and re-run /fwd:setup. → Los op en draai /fwd:setup opnieuw.

Je kan /fwd:setup opnieuw draaien — alle installers zijn idempotent.
```
