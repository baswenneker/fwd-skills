---
name: setup
description: Setup wizard for HeadingFWD's optional Claude Code conventions. Runs unattended — zero prompts: installs every convention in one batch. Project-local: smartlint Stop-hook, lessons memory file, gitignore entries for fwd runtime artefacts, clear-context prompt on plan accept, no-attribution (disables the Claude commit/PR byline and session link). Global (~/.claude): a grilling rule that makes Matt Pocock's grilling skill ask only the real questions, a rule that puts every background wait loop under timeout, a rule that always runs /codex:adversarial-review in the background, a rule that ends every finished turn with the fwd:next-steps status block, and the RTK PreToolUse hook. The codex-review rule and the RTK hook install only when the codex plugin or rtk is present; otherwise the report marks them as skipped. Copies bundled payload files into .claude/hooks/ or .claude/lessons/, merges JSON snippets into .claude/settings.local.json, injects marker-bracketed sections into CLAUDE.md (lessons in the project; grilling, wait-loops, codex-review and next-steps in ~/.claude), or appends a marker-bracketed block to .gitignore. Idempotent and modular — each feature lives in scripts/<feature>/. Prints a fixed-format Dutch summary from the bundled OUTPUT.md template, never free-form prose. Runs on Haiku. Use only when the user invokes /fwd:setup explicitly.
context: fork
model: haiku
allowed-tools: Bash
disable-model-invocation: true
---

# fwd:setup

Install HeadingFWD's optional conventions with zero prompts. Five go into the
project, five into `~/.claude`. One batch, one fixed-format summary. Each feature is
independent: its installer lives in `scripts/<feature>/install.sh`, accepts
`--scope user|project`, and is idempotent. Re-running the skill is safe.

## Apply + report

!`bash "${CLAUDE_SKILL_DIR}/scripts/apply-all.sh" && echo "---OUTPUT-TEMPLATE---" && cat "${CLAUDE_SKILL_DIR}/OUTPUT.md"`

## Instructions

The block above already ran all ten installers — five at `--scope project`,
`grilling`, `wait-loops`, `codex-review`, `next-steps` and `rtk` at `--scope user`. That
already happened, do not run them again. It contains two parts:

1. **Above `---OUTPUT-TEMPLATE---`**: one `### <feature>` report per
   installer (`exit=`, `stdout:`, `stderr:`), always in this order:
   `smartlint`, `lessons`, `gitignore`, `clear-context-on-plan`,
   `no-attribution`, `grilling`, `wait-loops`, `codex-review`, `next-steps`, `rtk` — followed by a `### tracked` block (touched files that
   git tracks) and a `### followup` block (skills the user may want to run
   by hand next, detected but never run).
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
- **no-attribution** — `attribution.commit` or `attribution.pr` holds a non-empty custom string, or `attribution.sessionUrl` is explicitly `true`.
- **grilling**, **wait-loops**, **codex-review**, **next-steps** — corrupt sentinel markers in `~/.claude/CLAUDE.md` (one without the other, or out of order), or an unmanaged copy of the same rule (its heading outside the markers), which installing would duplicate.
- **rtk** — another PreToolUse command already calls `rtk hook` or an rtk rewrite script. A missing `rtk` is not a collision: the installer skips with exit 0.

Skipped is its own outcome, not a collision: `codex-review` without the codex plugin and `rtk` without the rtk binary exit 0 and print a stdout line starting with `↷`. `OUTPUT.md` shows those with icon `–`.

## Invariants

- Skill is invoked explicitly only — `disable-model-invocation: true` keeps the wizard out of automatic-trigger flows.
- **Zero prompts.** The wizard never calls `AskUserQuestion` — every feature is always installed, at the scope fixed below. `allowed-tools: Bash` enforces this structurally: the skill has no tool to ask with.
- **Project scope, except five global features.** `scripts/apply-all.sh` runs the installers listed in its `USER_SCOPE` at `--scope user` — `grilling`, `wait-loops`, `codex-review`, `next-steps`, `rtk` — and every other one at `--scope project`. Outside the project this skill writes only to `~/.claude/CLAUDE.md` (between `<!-- fwd:<feature>:start -->` / `<!-- fwd:<feature>:end -->` markers) and `~/.claude/settings.json` (the RTK hook), or the same files under `$CLAUDE_CONFIG_DIR`. These five shape how Claude works in every repo, so a per-project copy would be missing wherever setup was not run, and the RTK hook would run twice next to a global one. The grilling rule overrides Matt Pocock's `grilling` skill from CLAUDE.md, which leaves that skill untouched so its plugin updates keep arriving. Nothing else goes global without the same deliberate decision. (The installers themselves accept either scope when invoked manually.)
- Runs on Haiku (`context: fork` + `model: haiku`) — the apply step is a single deterministic bash pre-flight block and the report is a fill-in-the-blanks template, so no larger model is needed.
- The final message is always the filled-in `OUTPUT.md` template — never a free-form summary. See `OUTPUT.md` for the exact fill rules and worked examples.
- Each feature installer lives at `scripts/<feature>/install.sh`, accepts `--scope user|project`, and is idempotent. Re-runs detect existing installs and either refresh in place or exit 2 on a corrupt/conflicting state.
- `scripts/apply-all.sh` always exits 0 itself (it reports per-installer failures, it doesn't propagate them) so the `&&` chain in "Apply + report" always reaches `cat OUTPUT.md`.
- **JSON merging** (smartlint, clear-context-on-plan, no-attribution): the shared `scripts/lib/merge-json.sh` deep-merges objects, concatenates arrays, and lets new scalars win on conflict. Each installer dedupe-checks its own entries before calling the merger so re-runs do not double the array. `jq` is required; when missing the merger backs up the target to `<file>.bak` and replaces it with the new snippet.
- **Markdown injection** (lessons): the lessons installer brackets its section with sentinel HTML comments (`<!-- fwd:lessons:start -->` / `<!-- fwd:lessons:end -->`) and uses inline `head` / `tail` to replace the region between them on refresh. The global rules (grilling, wait-loops, codex-review, next-steps) use the shared `scripts/lib/md-block.sh`, which adds two things: a guard that refuses (exit 2) when the rule's heading already sits outside the markers, and `--remove`, which deletes the block. The wizard never calls `--remove`; it exists for undoing by hand, e.g. `bash scripts/grilling/install.sh --scope user --remove`. The lessons installer still has its own copy of the logic because it substitutes a path into its payload.
- **Gitignore injection**: marker-bracketed block (`# fwd:setup:gitignore:start` / `# fwd:setup:gitignore:end`) in `.gitignore`.
- Hook commands use literal `$CLAUDE_PROJECT_DIR` — Claude Code's shell expands it at hook runtime.
- One feature's collision (exit 2) never aborts the batch — `apply-all.sh` always runs all ten.
- **Follow-up detection, never execution.** `apply-all.sh` checks whether Matt Pocock's `setup-matt-pocock-skills` is installed and, if so, emits `mattpocock-setup` in its `### followup` block; `OUTPUT.md` turns that into one closing line. That skill configures a repo's issue tracker, triage labels and domain docs, and it is interactive — it asks questions and shows drafts to edit. That is why it is only pointed at, never chained: this wizard has no tool to ask with, runs on Haiku in a fork, and its zero-prompt guarantee would be broken by any skill that prompts. The check is a glob over the plugin cache under `${CLAUDE_CONFIG_DIR:-$HOME/.claude}`; no match means no line, which is also what happens if that cache layout ever changes. It also emits `setup-precommit` while the project has no `.pre-commit-config.yaml`, or has one but no installed `pre-commit` hook (a fresh clone): `/fwd:setup-precommit` (gitleaks, formatters, Conventional Commits, osv-scanner on push) is a separate skill so it can run on its own, and this wizard only points at it.

## Adding a new feature later

1. Create `scripts/<feature>/install.sh` (accept `--scope user|project`, idempotent, exit 2 on collision).
2. Drop static files in `scripts/<feature>/payload/`. Use placeholders (`__HOOK_DIR__`, `__LESSONS_PATH__`, etc.) for path substitution at install time.
3. Pick a merge style appropriate to what you're injecting:
   - JSON settings → call `../lib/merge-json.sh`
   - Markdown / CLAUDE.md section → call `../lib/md-block.sh` (see `scripts/grilling/install.sh`)
   - Plain file copy → just `cp` into `<scope>/.claude/<feature-dir>/`
4. Add it to the `FEATURES` array in `scripts/apply-all.sh` (order = display order); add it to `USER_SCOPE` too only after a deliberate decision to make it global.
5. Add the feature-specific collision cause to the bullet list above.
6. Add a row for it to the slug→label table in `OUTPUT.md`.
