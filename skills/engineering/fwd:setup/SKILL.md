---
name: fwd:setup
description: Setup wizard for HeadingFWD's optional Claude Code conventions. Asks the user once via a single three-question dialog (scope, features multiselect, attribution toggle) then runs the matching installers in batch — features are smartlint Stop-hook, lessons memory file, gitignore entries for fwd runtime artefacts, and clear-context prompt on plan accept; attribution (commit/PR byline) is a separate yes/no. Copies bundled payload files into .claude/hooks/ or .claude/lessons/, merges JSON snippets into ~/.claude/settings.json or .claude/settings.local.json, injects an instructions section into CLAUDE.md (lessons), or appends a marker-bracketed block to .gitignore. Idempotent and modular — each feature lives in scripts/<feature>/. Use only when the user invokes /fwd:setup explicitly.
disable-model-invocation: true
---

# fwd:setup

Walk the user through installing HeadingFWD's optional conventions in a single dialog. The wizard asks once — scope + which features — then runs every selected installer in batch and shows a single summary. Each feature is independent: its installer lives in `scripts/<feature>/`, accepts `--scope user|project`, and is idempotent. Re-running the skill is safe.

## Process

### 1. Pre-flight — pick the scope default

Run `rtk git rev-parse --is-inside-work-tree` (exit 0 = inside a git work tree). The result decides which scope option to list first in the dialog:

- **Inside a repo** → `Project-local` first (more likely the user wants per-repo config).
- **Outside a repo** → `User-global` first.

Do not install anything yet — this only changes option ordering in step 2.

### 2. Ask once — scope and features

Call `AskUserQuestion` with **three questions in one call**:

**Question 1 — scope** (single-select, no preview):
- **Project-local** — payload lands under `<cwd>/.claude/<feature-dir>/`; settings/instructions land in the project's settings file or CLAUDE.md.
- **User-global** — payload lands under `~/.claude/<feature-dir>/`; settings/instructions land under `~/.claude/`. Pick this when the user wants the convention to apply everywhere they run Claude Code.

**Question 2 — features** (`multiSelect: true`, no preview, 4 options). Each option's `description` is one short sentence — the WHY. Match the conversation language (Dutch if the session is in Dutch).

- **Smartlint Stop-hook** — automatic lint after every Claude response, so code quality stays consistent without you remembering to run linters.
- **Lessons memory file** — Claude remembers corrections, conventions and patterns across sessions instead of starting each conversation blank.
- **Gitignore entries for fwd runtime artefacts** — without this, `/loop /fwd:issue-fix` writes `.claude/issue-loop/state.json` and then skips every overnight tick on `main-checkout-dirty`.
- **Clear-context prompt on plan accept** — surfaces a "Clear context?" prompt right after `ExitPlanMode` so the implementation session doesn't carry the deliberation that produced the plan.

**Question 3 — attribution** (single-select, no preview):
- **Ja, uitschakelen** / **Yes, disable** — keeps the default `🤖 Generated with [Claude Code]` byline and `Co-Authored-By: Claude …` trailer out of commits and pull requests.
- **Nee, standaard laten** / **No, keep default** — no change to attribution settings; the no-attribution installer is skipped.

If the user selects **zero features** and chooses "No" on attribution, skip step 3 and go straight to the summary in step 4.

### 3. Apply selected installers in batch

For each selected feature, in this fixed order, run its installer with `--scope <chosen>` and capture the exit code and stderr. **Do not abort on a non-zero exit** — keep going so one feature's collision doesn't block the rest.

```
1. smartlint            → bash "${CLAUDE_SKILL_DIR}/scripts/smartlint/install.sh" --scope <scope>
2. lessons              → bash "${CLAUDE_SKILL_DIR}/scripts/lessons/install.sh" --scope <scope>
3. gitignore            → bash "${CLAUDE_SKILL_DIR}/scripts/gitignore/install.sh" --scope <scope>
4. clear-context-on-plan → bash "${CLAUDE_SKILL_DIR}/scripts/clear-context-on-plan/install.sh" --scope <scope>
5. no-attribution       → bash "${CLAUDE_SKILL_DIR}/scripts/no-attribution/install.sh" --scope <scope>
```

Per-feature exit code semantics (uniform across all installers):

- **0** — installed (fresh) or already present / refreshed in place. Idempotent.
- **2** — collision: the installer found a conflicting existing value and refused to overwrite. The installer printed the conflicting entry + remediation hint to stderr. Capture that stderr verbatim for the summary; do **not** retry.
- **other non-zero** — argument or I/O error. Capture stderr for the summary.

Feature-specific collision causes (for context when relaying stderr):

- **smartlint** — existing Stop-hook with a different command.
- **lessons** — corrupt sentinel markers in CLAUDE.md (start without end, or out of order).
- **gitignore** — corrupt sentinel markers in `.gitignore` / `~/.config/git/ignore`.
- **clear-context-on-plan** — `showClearContextOnPlanAccept` explicitly set to `false`.
- **no-attribution** — `attribution.commit` or `attribution.pr` holds a non-empty custom string.

### 4. Summary

Print one consolidated summary covering the whole run:

- **Scope** — `Project-local` or `User-global`, and the resolved paths (the settings file and CLAUDE.md that were touched, or would have been).
- **Per feature**:
  - ✓ installed / refreshed (exit 0)
  - ⚠ collision (exit 2) — relay the installer's stderr verbatim with the suggested fix and the re-run instruction (`re-run /fwd:setup`)
  - ✗ I/O error (other non-zero) — relay stderr
  - skipped (not selected)
- **Idempotency note** — re-running `/fwd:setup` is safe.

If the user selected zero features, the summary is just: scope shown (informational), no features installed, no files touched.

## Invariants

- Skill is invoked explicitly only — `disable-model-invocation: true` keeps the wizard out of automatic-trigger flows.
- The wizard asks at most **one** `AskUserQuestion` call per run — scope + features + attribution in a single dialog (three questions, one call). No per-feature follow-up prompts.
- Each feature installer lives at `scripts/<feature>/install.sh`, accepts `--scope user|project`, and is idempotent. Re-runs detect existing installs and either refresh in place or exit 2 on a corrupt/conflicting state.
- **JSON merging** (smartlint, clear-context-on-plan, no-attribution): the shared `scripts/lib/merge-json.sh` deep-merges objects, concatenates arrays, and lets new scalars win on conflict. Each installer dedupe-checks its own entries before calling the merger so re-runs do not double the array. `jq` is required; when missing the merger backs up the target to `<file>.bak` and replaces it with the new snippet.
- **Markdown injection** (lessons): the lessons installer brackets its section with sentinel HTML comments (`<!-- fwd:lessons:start -->` / `<!-- fwd:lessons:end -->`) and uses inline `head` / `tail` to replace the region between them on refresh. No shared lib yet — extract to `scripts/lib/merge-markdown.sh` if a second feature also needs it.
- **Gitignore injection**: marker-bracketed block (`# fwd:setup:gitignore:start` / `# fwd:setup:gitignore:end`) in `.gitignore` (project) or `~/.config/git/ignore` (user).
- Hook commands use literal `$HOME` (user) or `$CLAUDE_PROJECT_DIR` (project) — Claude Code's shell expands them at hook runtime. Lessons-file paths in the injected CLAUDE.md section follow the same convention (`$HOME/...` or repo-relative).
- One feature's collision (exit 2) never aborts the batch — the remaining installers still run.

## Adding a new feature later

1. Create `scripts/<feature>/install.sh` (accept `--scope user|project`, idempotent, exit 2 on collision).
2. Drop static files in `scripts/<feature>/payload/`. Use placeholders (`__HOOK_DIR__`, `__LESSONS_PATH__`, etc.) for path substitution at install time.
3. Pick a merge style appropriate to what you're injecting:
   - JSON settings → call `../lib/merge-json.sh`
   - Markdown / CLAUDE.md section → use sentinel markers + inline `head`/`tail` (see `scripts/lessons/install.sh`)
   - Plain file copy → just `cp` into `<scope>/.claude/<feature-dir>/`
4. Wire the feature into the dialog in section 2: if it is an installable tool/file, add it as an option to the Q2 multiselect (max 4 options — if already at 4, move the least-common option to a separate Q3-style binary question or combine where logical). If it is a settings preference (like attribution), add it as a new single-select question in the same `AskUserQuestion` call. No preview, no per-feature follow-up call.
5. Wire the feature into the apply-loop in section 3 — add it to the fixed order with the path to its `install.sh`.
6. Add the feature-specific collision cause to the bullet list in section 3.
