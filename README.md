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

It runs unattended: zero prompts, always project-local (`<project>/.claude/`, `.claude/settings.local.json`, the project's `CLAUDE.md` and `.gitignore`). It installs all five features in one batch and prints a fixed Dutch report. The wizard is idempotent — re-running it is safe; existing entries are detected and refreshed in place. The report lists which touched files are under version control, so you can decide whether they go into your next commit. If Matt Pocock's `setup-matt-pocock-skills` is installed, the report ends with a pointer to it; that wizard is interactive and is never run for you.

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

- **What** — disables the Claude byline and trailers on commits and PRs via the `attribution` settings. Refuses to overwrite a custom attribution string you set yourself.

## Skills

| Category | Skill | Description |
| --- | --- | --- |
| engineering | [fwd:autocoder-issue](skills/engineering/autocoder-issue/SKILL.md) | Open an issue for the Workcenter autocoder from any repo. Creates the six fwd- labels when the repo lacks them, writes the issue in the shape the autocoder reads (what, done when, what happens at the end), assigns it to the operator and labels it for the evening run or for straight away. Works on GitHub through `gh` and on Lely's GitLab through `glab`. Use when the operator says "maak een autocoder issue", "zet dit op de autocoder", "laat de autocoder dit doen", "autocoder issue voor ...", asks for the autocoder labels in a repo, or invokes /fwd:autocoder-issue. |
| engineering | [fwd:changelog](skills/engineering/changelog/SKILL.md) | Automatically generate and update CHANGELOG.md based on recent changes. Writes directly without asking for confirmation. |
| engineering | [fwd:git-commit](skills/engineering/git-commit/SKILL.md) | Stage and commit with conventional message — pre-flight scan blocks risky files (.env, logs, keys, secrets, >1MB) |
| engineering | [fwd:rules-audit](skills/engineering/rules-audit/SKILL.md) | Interactief de `.claude/rules/` directory bootstrappen voor een repo. De skill scant de codebase, stelt regelbestanden voor — elk voorzien van minimaal één golden example (een pad naar een echt, exemplarisch bestand) — en schrijft pas weg na expliciete goedkeuring van de gebruiker. Gebruik bij "rules audit", "bootstrap rules", "stel regels op", "maak claude rules", of als je `/fwd:rules-audit` aanroept. |
| engineering | [fwd:setup](skills/engineering/setup/SKILL.md) | Setup wizard for HeadingFWD's optional Claude Code conventions. Runs unattended — zero prompts, always project-local scope: installs every convention in one batch — smartlint Stop-hook, lessons memory file, gitignore entries for fwd runtime artefacts, clear-context prompt on plan accept, and no-attribution (disables the Claude commit/PR byline). Copies bundled payload files into .claude/hooks/ or .claude/lessons/, merges JSON snippets into .claude/settings.local.json, injects an instructions section into CLAUDE.md (lessons), or appends a marker-bracketed block to .gitignore. Idempotent and modular — each feature lives in scripts/<feature>/. Prints a fixed-format Dutch summary from the bundled OUTPUT.md template, never free-form prose. Runs on Haiku. Use only when the user invokes /fwd:setup explicitly. |
| productivity | [fwd:caveman](skills/productivity/caveman/SKILL.md) | Ultra-compressed communication mode. Cuts token usage ~75% by dropping filler, articles, and pleasantries while keeping full technical accuracy. Use when user says "caveman mode", "talk like caveman", "use caveman", "less tokens", "be brief", or invokes /fwd:caveman. |
| productivity | [fwd:jip-janneke](skills/productivity/jip-janneke/SKILL.md) | Rewrites a referenced text into plain, readable language — "jip-en-janneketaal". One pass, chat output only; output is always Dutch unless another language is explicitly requested. Invoke when someone says "maak dit leesbaarder", "schrijf dit in jip-en-janneketaal", "leg uit in jip janneke", "leg dit uit voor een leek", "rewrite in plain language", "make this readable", or invokes /fwd:jip-janneke. Not fwd:caveman (compresses WITH abbreviations, cuts to fragments — opposite direction). fwd:jip-janneke rewrites the full text once, into complete readable sentences. |
| productivity | [fwd:explainer](skills/productivity/explainer/SKILL.md) | Builds a visual HTML explainer of anything heavy — what happened this session, an architecture, an auth or deployment flow, a plan, review findings, a diff — and publishes it as an artifact whose diagrams are verified by actually rendering them. Fixed shape: framing sentence, a numbered table of contents, In 't kort, a hand-drawn SVG diagram of the mechanism plus a further diagram in every section that has its own sequence, comparison or set of relationships, one running concrete example, term list, "wat ik weglaat". Written for a reader who is a layperson on devops and cloud; English terms allowed, each explained at first use. Invoke when someone says "maak een html explainer", "maak een explainer", "html explainer van ...", "visualiseer wat je gedaan hebt", "maak er een uitlegpagina van", or invokes /fwd:explainer. |

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
