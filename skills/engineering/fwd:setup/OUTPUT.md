# fwd:setup — output template

Fixed final-message format for `/fwd:setup`. `scripts/apply-all.sh` prints one
`### <feature>` block per installer, each with `exit=`, `stdout:`, and
`stderr:`. Turn that into the report below and print it **verbatim** as your
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

List features in this exact order, always all five.

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

**Aandachtspunten** — only include this section (heading included) when at
least one feature is `⚠` or `✗`. One bullet per such feature: its Dutch
label, the full `stderr:` verbatim, then "Los op en draai `/fwd:setup`
opnieuw." Omit the entire section when every feature is `✓`.

---

## Happy-path voorbeeld (echte output — dit is de exacte vorm)

```
✅ Setup voltooid

Scope: Project-lokaal

Geïnstalleerde conventies:
- ✓ Smartlint Stop-hook → /Users/bas/Development/Accounts/Artific/res-202-agent-loop/.claude/hooks/
- ✓ Lessons memory file → /Users/bas/Development/Accounts/Artific/res-202-agent-loop/.claude/lessons/LESSONS.md
- ✓ Gitignore entries voor fwd artefacten → .gitignore
- ✓ Clear-context prompt → ingesteld in settings.local.json
- ✓ Attribution uitgeschakeld → commits/PRs zonder byline en trailers

Bestanden aangepast:
- .claude/settings.local.json
- CLAUDE.md (Lessons-sectie toegevoegd)
- .gitignore

Je kan /fwd:setup opnieuw draaien — alle installers zijn idempotent.
```

## Vorm bij een conflict — zelfde skelet, plus Aandachtspunten

```
⚠️ Setup deels voltooid

Scope: Project-lokaal

Geïnstalleerde conventies:
- ✓ Smartlint Stop-hook → /pad/.claude/hooks/
- ✓ Lessons memory file → /pad/.claude/lessons/LESSONS.md
- ⚠ Gitignore entries voor fwd artefacten → corrupte markers in .gitignore
- ✓ Clear-context prompt → ingesteld in settings.local.json
- ✓ Attribution uitgeschakeld → commits/PRs zonder byline en trailers

Bestanden aangepast:
- .claude/settings.local.json
- .claude/lessons/LESSONS.md

Aandachtspunten:
- Gitignore entries voor fwd artefacten — ⚠ Found start marker but no end marker in .gitignore. The gitignore section is corrupt. Repair the markers (or delete the region between them) and re-run /fwd:setup. → Los op en draai /fwd:setup opnieuw.

Je kan /fwd:setup opnieuw draaien — alle installers zijn idempotent.
```
