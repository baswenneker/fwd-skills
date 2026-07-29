---
name: setup
description: Setup wizard for HeadingFWD's optional Claude Code conventions. Runs unattended — zero prompts, always project-local scope: installs every convention in one batch — smartlint Stop-hook, lessons memory file, gitignore entries for fwd runtime artefacts, clear-context prompt on plan accept, and no-attribution (disables the Claude commit/PR byline). Copies bundled payload files into .claude/hooks/ or .claude/lessons/, merges JSON snippets into .claude/settings.local.json, injects an instructions section into CLAUDE.md (lessons), or appends a marker-bracketed block to .gitignore. Idempotent and modular — each feature lives in scripts/<feature>/. Prints a fixed-format Dutch summary from the bundled OUTPUT.md template, never free-form prose. Runs on Haiku. Use only when the user invokes /fwd:setup explicitly.
context: fork
model: haiku
allowed-tools: Bash
disable-model-invocation: true
---

# fwd:setup

Install HeadingFWD's optional conventions with zero prompts, always
project-local. One batch, one fixed-format summary. Each feature is
independent: its installer lives in `scripts/<feature>/install.sh`, accepts
`--scope user|project`, and is idempotent. Re-running the skill is safe.

## Apply + report

!`bash "${CLAUDE_SKILL_DIR}/scripts/apply-all.sh" && echo "---OUTPUT-TEMPLATE---" && cat "${CLAUDE_SKILL_DIR}/OUTPUT.md"`

## Instructions

The block above already ran all five installers at `--scope project` — that
already happened, do not run them again. It contains two parts:

1. **Above `---OUTPUT-TEMPLATE---`**: one `### <feature>` report per
   installer (`exit=`, `stdout:`, `stderr:`), always in this order:
   `smartlint`, `lessons`, `gitignore`, `clear-context-on-plan`,
   `no-attribution`.
2. **Below `---OUTPUT-TEMPLATE---`**: the fixed report template
   (`OUTPUT.md`) — read its own instructions and fill in every placeholder
   from part 1.

Print the filled-in template **verbatim** as your only response. Do not add
commentary before or after it, do not call any tool, do not ask a question.

Per-feature exit code semantics (uniform across all installers):

- **0** — installed (fresh) or already present / refreshed in place. Idempotent.
- **2** — collision: the installer found a conflicting existing value and
  refused to overwrite. It printed the conflicting entry + remediation hint
  to `stderr`. Relay that verbatim per `OUTPUT.md`'s "Aandachtspunten" rule;
  do **not** retry.
- **other non-zero** — argument or I/O error. Same handling as a collision.

Feature-specific collision causes (for context when relaying stderr):

- **smartlint** — existing Stop-hook with a different command.
- **lessons** — corrupt sentinel markers in CLAUDE.md (start without end, or out of order).
- **gitignore** — corrupt sentinel markers in `.gitignore`.
- **clear-context-on-plan** — `showClearContextOnPlanAccept` explicitly set to `false`.
- **no-attribution** — `attribution.commit` or `attribution.pr` holds a non-empty custom string.

## Invariants

- Skill is invoked explicitly only — `disable-model-invocation: true` keeps the wizard out of automatic-trigger flows.
- **Zero prompts.** The wizard never calls `AskUserQuestion` — every feature is always installed, always at project scope. `allowed-tools: Bash` enforces this structurally: the skill has no tool to ask with.
- **Always project scope.** `scripts/apply-all.sh` hardcodes `--scope project` — this skill never touches `~/.claude/`. (The installers themselves still accept `--scope user` if invoked manually outside this skill.)
- Runs on Haiku (`context: fork` + `model: haiku`) — the apply step is a single deterministic bash pre-flight block and the report is a fill-in-the-blanks template, so no larger model is needed.
- The final message is always the filled-in `OUTPUT.md` template — never a free-form summary. See `OUTPUT.md` for the exact fill rules and worked examples.
- Each feature installer lives at `scripts/<feature>/install.sh`, accepts `--scope user|project`, and is idempotent. Re-runs detect existing installs and either refresh in place or exit 2 on a corrupt/conflicting state.
- `scripts/apply-all.sh` always exits 0 itself (it reports per-installer failures, it doesn't propagate them) so the `&&` chain in "Apply + report" always reaches `cat OUTPUT.md`.
- **JSON merging** (smartlint, clear-context-on-plan, no-attribution): the shared `scripts/lib/merge-json.sh` deep-merges objects, concatenates arrays, and lets new scalars win on conflict. Each installer dedupe-checks its own entries before calling the merger so re-runs do not double the array. `jq` is required; when missing the merger backs up the target to `<file>.bak` and replaces it with the new snippet.
- **Markdown injection** (lessons): the lessons installer brackets its section with sentinel HTML comments (`<!-- fwd:lessons:start -->` / `<!-- fwd:lessons:end -->`) and uses inline `head` / `tail` to replace the region between them on refresh. No shared lib yet — extract to `scripts/lib/merge-markdown.sh` if a second feature also needs it.
- **Gitignore injection**: marker-bracketed block (`# fwd:setup:gitignore:start` / `# fwd:setup:gitignore:end`) in `.gitignore`.
- Hook commands use literal `$CLAUDE_PROJECT_DIR` — Claude Code's shell expands it at hook runtime.
- One feature's collision (exit 2) never aborts the batch — `apply-all.sh` always runs all five.

## Adding a new feature later

1. Create `scripts/<feature>/install.sh` (accept `--scope user|project`, idempotent, exit 2 on collision).
2. Drop static files in `scripts/<feature>/payload/`. Use placeholders (`__HOOK_DIR__`, `__LESSONS_PATH__`, etc.) for path substitution at install time.
3. Pick a merge style appropriate to what you're injecting:
   - JSON settings → call `../lib/merge-json.sh`
   - Markdown / CLAUDE.md section → use sentinel markers + inline `head`/`tail` (see `scripts/lessons/install.sh`)
   - Plain file copy → just `cp` into `<scope>/.claude/<feature-dir>/`
4. Add it to the `FEATURES` array in `scripts/apply-all.sh` (order = display order).
5. Add the feature-specific collision cause to the bullet list above.
6. Add a row for it to the slug→label table in `OUTPUT.md`.
