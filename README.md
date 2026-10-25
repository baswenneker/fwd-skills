# fwd-skills

HeadingFWD's Claude Code skills plugin.

A lightweight, plain-markdown skill registry, structured after [mattpocock/skills](https://github.com/mattpocock/skills/tree/main). Skills are organised by category under `skills/` and registered in `.claude-plugin/plugin.json`. The skills here are extracted standalone from [baswenneker/fwd-claude-code](https://github.com/baswenneker/fwd-claude-code) so they can be installed without the rest of the `fwd` workflow.

## Installation

> Only tested with [Claude Code](https://claude.ai/code).

**Option A — as a Claude Code plugin** (recommended):

```bash
claude plugin marketplace add baswenneker/fwd-skills
claude plugin install fwd@headingfwd
```

Installs every skill listed in `.claude-plugin/plugin.json`. Restart Claude Code after installing or updating so the skills register.

**Option B — skills only, via the skills CLI:**

```bash
npx skills@latest add baswenneker/fwd-skills
```

The skills CLI syncs `skills/` only. The plugin currently ships no subagents, so both options give the same set of skills.

## Setup

After installing the plugin, run the setup wizard to enable optional HeadingFWD conventions:

```
/fwd:setup
```

It runs unattended: zero prompts, project-local (`<project>/.claude/`, `.claude/settings.local.json`, the project's `CLAUDE.md` and `.gitignore`), except five features that go into `~/.claude` because they apply to every repo: the grilling, wait-loops, codex-review and next-steps rules and the RTK hook. It installs all ten features in one batch and prints a fixed Dutch report. The wizard is idempotent — re-running it is safe; existing entries are detected and refreshed in place. The report lists which touched files are under version control, so you can decide whether they go into your next commit. If Matt Pocock's `setup-matt-pocock-skills` is installed, the report ends with a pointer to it; that wizard is interactive and is never run for you. While the repo has no `.pre-commit-config.yaml`, or this clone never installed its hook, the report also points at `/fwd:setup-precommit` (see "Pre-commit setup" below).

### Feature: smartlint Stop-hook

- **Why** — consistent code quality without thinking about it: lint runs automatically after every Claude response.
- **How** — a Stop-hook fires after each response and runs `smart-lint.sh`. The wrapper diffs against git so unchanged code is skipped.
- **What** — copies `smart-lint.sh` + wrapper into `.claude/hooks/` and merges a hook entry into `.claude/settings.local.json`. The script auto-detects project type (TS / Go / Python / Rust / Nix / shell) and runs the appropriate linters.

### Feature: lessons memory file

- **Why** — Claude remembers corrections, conventions and patterns across sessions instead of starting blank each conversation.
- **How** — an instruction section in `CLAUDE.md` tells Claude when to read `LESSONS.md` and when to append (after corrections, surprises, missing rules).
- **What** — injects a marker-bracketed section (`<!-- fwd:lessons:start -->` … `<!-- fwd:lessons:end -->`) into `CLAUDE.md` and scaffolds an empty `LESSONS.md` next to it. Existing entries are never overwritten on re-run.

### Feature: gitignore entries

- **What** — appends a marker-bracketed block to `.gitignore` for Claude Code's `/loop` scheduling lock (`.claude/scheduled_tasks.lock`) and scratch output (`tmp/`). Both otherwise keep the working tree permanently dirty.

### Feature: clear-context prompt on plan accept

- **What** — sets `showClearContextOnPlanAccept: true` in `.claude/settings.local.json`, so Claude Code offers to clear context when you accept a plan in plan mode.

### Feature: no-attribution

- **What** — disables the Claude byline and trailers on commits and PRs, and the link to the Claude session, via the `attribution` settings (`commit`, `pr`, `sessionUrl`). Refuses to overwrite a custom attribution string you set yourself.

### Feature: grilling rule (global)

- **Why** — Matt Pocock's `grilling` skill (behind grill-me / grill-with-docs) asks every decision as a question. This rule keeps only the real questions and lists the rest as assumptions at the end of each round, which you correct in one reply.
- **How** — a rule in your user-level `CLAUDE.md` narrows the skill. The skill itself stays untouched, so its plugin updates keep arriving.
- **What** — injects a marker-bracketed block (`<!-- fwd:grilling:start -->` … `<!-- fwd:grilling:end -->`) into `~/.claude/CLAUDE.md`, the only file the wizard writes outside the project. Re-runs refresh the block in place. To remove it: `bash <plugin>/skills/engineering/setup/scripts/grilling/install.sh --scope user --remove`.

### Feature: wait-loops rule (global)

- **Why** — a background loop that waits for a file or a log line runs forever when that never comes. Claude Code then hangs on exit, which blocks restarts and updates.
- **What** — a marker-bracketed block (`<!-- fwd:wait-loops:start -->` …) in `~/.claude/CLAUDE.md`: every wait loop runs under `timeout 1800`, only loops that watch get wrapped (never a build or deploy), and exit code 124 means "not done yet", not "failed". Remove with `scripts/wait-loops/install.sh --scope user --remove`.

### Feature: codex-review rule (global)

- **Why** — `/codex:adversarial-review` first asks whether to wait or run in the background, and a review takes minutes.
- **What** — a marker-bracketed block (`<!-- fwd:codex-review:start -->` …) in `~/.claude/CLAUDE.md` that always runs it in the background, without asking. Installs only when the codex plugin (openai-codex) is installed; otherwise the report marks it as skipped. Remove with `scripts/codex-review/install.sh --scope user --remove`.

### Feature: next-steps rule (global)

- **Why** — after a piece of work the user kept asking "en nu?" to learn where things stand.
- **What** — a marker-bracketed block (`<!-- fwd:next-steps:start -->` …) in `~/.claude/CLAUDE.md` that has Claude end every turn that finishes a piece of work with the `/fwd:next-steps` block, unasked. Plain questions, quick back-and-forth and autonomous `/loop` ticks are skipped. Remove with `scripts/next-steps/install.sh --scope user --remove`.

### Feature: RTK hook (global)

- **Why** — [RTK](https://github.com/rtk-ai/rtk) filters the output of commands such as `git status` before it reaches Claude, which saves many tokens.
- **What** — merges a `PreToolUse` hook (`rtk hook claude`, matcher `Bash`) into `~/.claude/settings.json`. Skipped, and marked so in the report, when `rtk` is not on `PATH` or when the `rtk` there is the unrelated Rust Type Kit. Refuses (exit 2) when another rtk hook is already registered, so commands are never rewritten twice.

## Pre-commit setup

`/fwd:setup` points at a second wizard while the repo has no `.pre-commit-config.yaml`, or has one whose hook this clone never installed:

```
/fwd:setup-precommit
```

It sets the repo up with [pre-commit](https://pre-commit.com) hooks, unattended and project-local. It is separate from `/fwd:setup` so it can run on its own. The hooks run on the developer's machine only; there is no CI and no merge check.

- **Every commit** — file checks and fixers from `pre-commit-hooks` (trailing whitespace, end of file, merge-conflict markers, large files, private keys, YAML/JSON/TOML syntax) and `gitleaks` on the staged changes.
- **Per language, every commit** — autofixing formatters for what the repo contains: ruff for Python, shfmt and shellcheck for shell scripts, Prettier for TypeScript, JavaScript, HTML, CSS and JSON (the project's own Prettier and ESLint when `package.json` lists them), actionlint for GitHub workflows, hadolint for Dockerfiles.
- **Commit message** — `conventional-pre-commit`: `feat: ...`, `fix: ...` and so on.
- **Every push** — `osv-scanner` over every lockfile; a dependency with a known vulnerability blocks the push. Only when the repo has a lockfile.
- **README** — a "Git hooks" section that tells the next clone to run `pre-commit install`. git runs no hook on a clone, by design, so that one step stays.
- **Clean-up** — removes what the retired `/fwd:setup-review` left: its GitHub Actions workflows, the push hook that called the Workcenter reviewer, and `"review": true`.

A re-run rewrites a config the wizard wrote itself, so new languages and raised pinned versions arrive; a config the repo wrote is left alone. Commit the files it writes: another clone gets the hooks only after a pull and `pre-commit install`.

## Skills

| Category | Skill | Description |
| --- | --- | --- |
| engineering | [fwd:changelog](skills/engineering/changelog/SKILL.md) | Automatically generate and update CHANGELOG.md based on recent changes. Writes directly without asking for confirmation. |
| engineering | [fwd:git-commit](skills/engineering/git-commit/SKILL.md) | Stage and commit with conventional message — pre-flight scan blocks risky files (.env, logs, keys, secrets, >1MB) |
| engineering | [fwd:rules-audit](skills/engineering/rules-audit/SKILL.md) | Interactief de `.claude/rules/` directory bootstrappen voor een repo. De skill scant de codebase, stelt regelbestanden voor — elk voorzien van minimaal één golden example (een pad naar een echt, exemplarisch bestand) — en schrijft pas weg na expliciete goedkeuring van de gebruiker. Gebruik bij "rules audit", "bootstrap rules", "stel regels op", "maak claude rules", of als je `/fwd:rules-audit` aanroept. |
| engineering | [fwd:setup](skills/engineering/setup/SKILL.md) | Setup wizard for HeadingFWD's optional Claude Code conventions. Runs unattended — zero prompts, always project-local scope: installs every convention in one batch — smartlint Stop-hook, lessons memory file, gitignore entries for fwd runtime artefacts, clear-context prompt on plan accept, and no-attribution (disables the Claude commit/PR byline). Copies bundled payload files into .claude/hooks/ or .claude/lessons/, merges JSON snippets into .claude/settings.local.json, injects an instructions section into CLAUDE.md (lessons), or appends a marker-bracketed block to .gitignore. Idempotent and modular — each feature lives in scripts/<feature>/. Prints a fixed-format Dutch summary from the bundled OUTPUT.md template, never free-form prose. Runs on Haiku. Use only when the user invokes /fwd:setup explicitly. |
| engineering | [fwd:setup-precommit](skills/engineering/setup-precommit/SKILL.md) | Sets a repo up with pre-commit hooks. Runs unattended — zero prompts, project-local. Writes a .pre-commit-config.yaml with file checks and whitespace fixers (pre-commit-hooks), gitleaks, a Conventional Commits check on the message, autofixing formatters for the languages it finds (ruff for Python, shfmt and shellcheck for shell, Prettier for TypeScript/JS/HTML/CSS/JSON, the project's own ESLint and Prettier when package.json lists them), actionlint for GitHub workflows, hadolint for Dockerfiles, and osv-scanner on every push (blocks on a known CVE) when the repo has a lockfile. Runs `pre-commit install`, adds a "Git hooks" section to README.md that tells the next clone to run `pre-commit install`, and removes what the retired /fwd:setup-review left (its workflows, the Workcenter push hook, "review": true). Idempotent; rewrites a config it wrote itself, never one the repo wrote. Prints a fixed-format Dutch summary from the bundled OUTPUT.md template. Runs on Haiku. Use only when the user invokes /fwd:setup-precommit explicitly; /fwd:setup points at it while the repo has no config, or has one whose hook this clone never installed. |
| productivity | [fwd:caveman](skills/productivity/caveman/SKILL.md) | Ultra-compressed communication mode. Cuts token usage ~75% by dropping filler, articles, and pleasantries while keeping full technical accuracy. Use when user says "caveman mode", "talk like caveman", "use caveman", "less tokens", "be brief", or invokes /fwd:caveman. |
| productivity | [fwd:jip-janneke](skills/productivity/jip-janneke/SKILL.md) | Rewrites a referenced text into plain, readable language — "jip-en-janneketaal". One pass, chat output only; output is always Dutch unless another language is explicitly requested. Invoke when someone says "maak dit leesbaarder", "schrijf dit in jip-en-janneketaal", "leg uit in jip janneke", "leg dit uit voor een leek", "rewrite in plain language", "make this readable", or invokes /fwd:jip-janneke. Not fwd:caveman (compresses WITH abbreviations, cuts to fragments — opposite direction). fwd:jip-janneke rewrites the full text once, into complete readable sentences. |
| productivity | [fwd:explainer](skills/productivity/explainer/SKILL.md) | Builds a visual HTML explainer of anything heavy — what happened this session, an architecture, an auth or deployment flow, a plan, review findings, a diff — and publishes it as an artifact whose diagrams are verified by actually rendering them. Fixed shape: framing sentence, a numbered table of contents, In 't kort, a hand-drawn SVG diagram of the mechanism plus a further diagram in every section that has its own sequence, comparison or set of relationships, one running concrete example, term list, "wat ik weglaat". Written for a reader who is a layperson on devops and cloud; English terms allowed, each explained at first use. Invoke when someone says "maak een html explainer", "maak een explainer", "html explainer van ...", "visualiseer wat je gedaan hebt", "maak er een uitlegpagina van", or invokes /fwd:explainer. |
| productivity | [fwd:next-steps](skills/productivity/next-steps/SKILL.md) | Answers "en nu?" with a short, fixed status block in Dutch — what we are working on, where we stand, the next steps and who does each one — and ends with an offer to start, here or through the autocoder. Looks at the current session only and changes nothing. Invoke when the user asks "en nu?", "ok en nu?", "wat nu?", "wat is de status?", "waar staan we?", "what's next", or invokes /fwd:next-steps; the global next-steps rule from /fwd:setup also has Claude end every turn that finishes a piece of work with this block. |

## Obsolete skills

The mission and steps families (`mission-plan`, `mission-run`, `steps-plan`, `steps-run` plus their six subagents), `plan`, `codex-review-plan`, `codex-review-implementation`, `skill-eval`, `explain`, `premortem` and `unsure` were retired on 2026-09-10. Their sources are kept under [`obsolete/`](obsolete/README.md) but are not registered in the plugin.

## Adding a skill

1. Create a new folder under `skills/<category>/<field-or-context>-<name>/` (e.g. `skills/engineering/git-commit/`). No `fwd:` prefix — the `/fwd:` in the slash command comes from the plugin name.
2. Add a `SKILL.md` file with YAML frontmatter (`name`, `description`) and a markdown body. Bash helpers live in a sibling `scripts/` folder.
3. Register the skill folder path in `.claude-plugin/plugin.json` under `skills`.
4. Update the table above.

See [CLAUDE.md](CLAUDE.md) for repo conventions and [CONTEXT.md](CONTEXT.md) for shared vocabulary.

## Related

- [baswenneker/fwd-claude-code](https://github.com/baswenneker/fwd-claude-code) — full `fwd` workflow plugin (agents, hooks, CLI tooling); these skills are a slimmed-down subset.
- [mattpocock/skills](https://github.com/mattpocock/skills/tree/main) — layout and conventions inspiration.
