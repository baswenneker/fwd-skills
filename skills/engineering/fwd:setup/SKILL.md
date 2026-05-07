---
name: fwd:setup
description: Setup wizard for HeadingFWD's optional Claude Code conventions. Asks the user which features to install (currently smartlint Stop-hook and a lessons memory file), copies bundled payload files into .claude/hooks/ or .claude/lessons/, and merges the matching JSON snippet into ~/.claude/settings.json or .claude/settings.local.json — or for the lessons feature, injects an instructions section into the matching CLAUDE.md. Idempotent and modular — each feature lives in scripts/<feature>/. Use only when the user invokes /fwd:setup explicitly.
disable-model-invocation: true
---

# fwd:setup

Walk the user through installing HeadingFWD's optional conventions. Each feature is independent: the wizard asks per feature and runs its installer with the chosen scope. What gets merged where depends on the feature — JSON snippets land in settings files, markdown sections land in CLAUDE.md, payload files copy to feature-specific subfolders. Re-running the skill is safe — installers are idempotent and detect existing entries.

## Process

### 1. Pick the install scope

Ask the user via `AskUserQuestion`:

- **Project-local** — feature payload lands under `<cwd>/.claude/<feature-dir>/`, settings/instructions land in the project's settings/CLAUDE.md. Default this option when the cwd is inside a git repository (check with `git rev-parse --is-inside-work-tree` first).
- **User-global** — feature payload lands under `~/.claude/<feature-dir>/`, settings/instructions land in `~/.claude/`. Pick this when the user wants the convention to apply everywhere they run Claude Code.

Pass the chosen scope as `--scope user` or `--scope project` to each feature installer.

### 2. Smartlint Stop-hook

Ask via `AskUserQuestion` whether to install the smartlint Stop-hook. Simple Yes/No — no preview pane. The installer copies the wrapper scripts to `<scope>/.claude/hooks/` and merges a Stop-hook entry into the matching settings file (`~/.claude/settings.json` or `.claude/settings.local.json`).

If the user picks **Yes**, run:

```
bash "${CLAUDE_SKILL_DIR}/scripts/smartlint/install.sh" --scope <scope>
```

The installer's exit code tells you what happened:

- **0** — installed (fresh) or refreshed (exact match already in settings; payload re-copied to pick up bundled updates).
- **2** — collision: an existing smart-lint Stop-hook with a different command was found. The installer printed the conflicting entry to stderr and refused to merge. Do **not** retry automatically — relay the warning verbatim to the user with the suggested fix (remove the existing entry, re-run `/fwd:setup`).
- **other non-zero** — argument or I/O error; surface the stderr.

If **No**, skip silently.

### 3. Lessons memory file

Ask via `AskUserQuestion` whether to install the lessons memory feature. Simple Yes/No — no preview pane. The installer injects a `## Lessons` instruction section into CLAUDE.md (bracketed by `<!-- fwd:lessons:start -->` / `<!-- fwd:lessons:end -->` markers) and scaffolds an empty `LESSONS.md` at `$HOME/.claude/lessons/LESSONS.md` (user) or `.claude/lessons/LESSONS.md` (project).

If the user picks **Yes**, run:

```
bash "${CLAUDE_SKILL_DIR}/scripts/lessons/install.sh" --scope <scope>
```

The installer's exit code tells you what happened:

- **0** — installed (fresh) or refreshed (markers found, content between them replaced with current template). The scaffold `LESSONS.md` is only copied when missing — existing entries are never overwritten.
- **2** — corrupt markers: the start marker is present without an end marker, or markers are out of order. The installer printed a repair instruction to stderr and refused to modify CLAUDE.md. Do **not** retry automatically — relay the warning verbatim and ask the user to repair the marker region, then re-run `/fwd:setup`.
- **other non-zero** — argument or I/O error; surface the stderr.

If **No**, skip silently.

### 4. Summary

After all selected installers have run, print a short summary:

- Which features were installed
- Which settings file or CLAUDE.md was updated
- Where the payload files live
- Note that re-running `/fwd:setup` is safe (idempotent)

## Invariants

- Skill is invoked explicitly only — `disable-model-invocation: true` keeps the wizard out of automatic-trigger flows.
- Each feature installer lives at `scripts/<feature>/install.sh`, accepts `--scope user|project`, and is idempotent. Re-runs detect existing installs and either refresh in place or exit 2 on a corrupt/conflicting state.
- **JSON merging** (smartlint): the shared `scripts/lib/merge-json.sh` deep-merges objects, concatenates arrays, and lets new scalars win on conflict. Each installer dedupe-checks its own hook before calling the merger so re-runs do not double the array. `jq` is required; when missing the merger backs up the target to `<file>.bak` and replaces it with the new snippet.
- **Markdown injection** (lessons): the lessons installer brackets its section with sentinel HTML comments (`<!-- fwd:lessons:start -->` / `<!-- fwd:lessons:end -->`) and uses inline `head` / `tail` to replace the region between them on refresh. No shared lib yet — extract to `scripts/lib/merge-markdown.sh` if a second feature also needs it.
- Hook commands use literal `$HOME` (user) or `$CLAUDE_PROJECT_DIR` (project) — Claude Code's shell expands them at hook runtime. Lessons-file paths in the injected CLAUDE.md section follow the same convention (`$HOME/...` or repo-relative).

## Adding a new feature later

1. Create `scripts/<feature>/install.sh` (accept `--scope user|project`, idempotent, exit 2 on collision).
2. Drop static files in `scripts/<feature>/payload/`. Use placeholders (`__HOOK_DIR__`, `__LESSONS_PATH__`, etc.) for path substitution at install time.
3. Pick a merge style appropriate to what you're injecting:
   - JSON settings → call `../lib/merge-json.sh`
   - Markdown / CLAUDE.md section → use sentinel markers + inline `head`/`tail` (see `scripts/lessons/install.sh`)
   - Plain file copy → just `cp` into `<scope>/.claude/<feature-dir>/`
4. Add an `AskUserQuestion` block in this SKILL.md that gates the installer with a simple Yes/No (no preview pane — the question is *whether* to install, not *how* it's wired), and add the feature to the summary.
