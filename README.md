# fwd-skills

HeadingFWD's Claude Code skills plugin.

A lightweight, plain-markdown skill registry, structured after [mattpocock/skills](https://github.com/mattpocock/skills/tree/main). Skills are organised by category under `skills/` and registered in `.claude-plugin/plugin.json`. The skills here are extracted standalone from [baswenneker/fwd-claude-code](https://github.com/baswenneker/fwd-claude-code) so they can be installed without the rest of the `fwd` workflow.

## Installation

> Only tested with [Claude Code](https://claude.ai/code).

```bash
npx skills@latest add baswenneker/fwd-skills
```

## Setup

After installing the plugin, run the setup wizard to enable optional HeadingFWD conventions:

```
/fwd:setup
```

Each feature has its own Yes/No prompt. The wizard is idempotent — re-running it is safe; existing entries are detected and refreshed in place.

### Scope: project-local vs user-global

Before any feature is installed, the wizard asks where it should land:

- **Project-local** — payload lives under `<project>/.claude/`, settings merge into `.claude/settings.local.json`, instructions append to the project's `CLAUDE.md`. The convention applies to this repo only. Defaulted when you're inside a git repo.
- **User-global** — payload lives under `~/.claude/`, settings merge into `~/.claude/settings.json`, instructions append to `~/.claude/CLAUDE.md`. The convention applies everywhere you run Claude Code.

### Feature: smartlint Stop-hook

- **Why** — consistent code quality without thinking about it: lint runs automatically after every Claude response.
- **How** — a Stop-hook fires after each response and runs `smart-lint.sh`. The wrapper diffs against git so unchanged code is skipped.
- **What** — copies `smart-lint.sh` + wrapper into `.claude/hooks/` and merges a hook entry into the matching `settings.json`. The script auto-detects project type (TS / Go / Python / Rust / Nix / shell) and runs the appropriate linters.
- **Skip if** — you don't want automatic lint checks after Claude actions.

### Feature: lessons memory file

- **Why** — Claude remembers corrections, conventions and patterns across sessions instead of starting blank each conversation.
- **How** — an instruction section in `CLAUDE.md` tells Claude when to read `LESSONS.md` and when to append (after corrections, surprises, missing rules).
- **What** — injects a marker-bracketed section (`<!-- fwd:lessons:start -->` … `<!-- fwd:lessons:end -->`) into `CLAUDE.md` and scaffolds an empty `LESSONS.md` next to it. Existing entries are never overwritten on re-run.
- **Skip if** — you'd rather Claude start each conversation with a clean slate.

## Skills

| Category | Skill | Description |
| --- | --- | --- |
| engineering | [fwd:git-commit](skills/engineering/fwd:git-commit/SKILL.md) | Stage and commit with conventional message — pre-flight scan blocks risky files (.env, logs, keys, secrets, >1MB). |
| engineering | [fwd:issue-create](skills/engineering/fwd:issue-create/SKILL.md) | Interactief een GitHub issue opstellen volgens een vast 5-secties template (probleem, voorbeelden, bevindingen, potentiële oplossing, tests). Leest input uit argument of huidige conversatie-context, detecteert bestaande repo-labels, vraagt om een assignee, en laat de gebruiker de complete draft per sectie reviewen voor `gh issue create`. |
| engineering | [fwd:issue-fix](skills/engineering/fwd:issue-fix/SKILL.md) | Privately work through your assigned GitHub issues overnight — pick the oldest open issue, fix it in an isolated worktree, run tests, commit (no push). Driven by `/loop`. Strictly read-only on GitHub (no labels, no comments, no PRs); all state local in `.claude/issue-loop/state.json`. |
| engineering | [fwd:plan](skills/engineering/fwd:plan/SKILL.md) | Plan een implementatie: verzamel context, stel 1-5 verdiepende vragen (DoD altijd inline, keuzes via AskUserQuestion popup), kies expliciet 1 of 3 plannen, en presenteer in visueel distincte boxen met spec-strip + TL;DR + Wijzigingen-tabel. Sluit altijd af met (Recommended)-tag op het beste plan en een verdict-block met onderbouwing. |
| engineering | [fwd:setup](skills/engineering/fwd:setup/SKILL.md) | Setup wizard for HeadingFWD's optional Claude Code conventions (smartlint Stop-hook, lessons memory file, gitignore entries, clear-context prompt on plan accept, disable commit/PR attribution). Asks for scope and per-feature Yes/No, copies bundled payloads, and merges JSON snippets or markdown sections into the matching settings/CLAUDE.md. Idempotent. Explicit `/fwd:setup` invocation only. |
| engineering | [fwd:skill-eval](skills/engineering/fwd:skill-eval/SKILL.md) | Black-box self-evaluation for any skill. Reads the target SKILL.md, generates ~10 experiments covering happy paths, flag interactions, error paths and domain invariants, runs each in `tmp/eval/eN/`, and reports pass/fail. Refuses on dirty tree. Reply `x` or `undo` after the report to clean up. |
| productivity | [fwd:grill-me](skills/productivity/fwd:grill-me/SKILL.md) | Interview the user relentlessly about a plan or design until reaching shared understanding, resolving each branch of the decision tree. |
| productivity | [fwd:caveman](skills/productivity/fwd:caveman/SKILL.md) | Ultra-compressed communication mode. Cuts token usage ~75% by dropping filler, articles, and pleasantries while keeping full technical accuracy. |
| productivity | [fwd:explain](skills/productivity/fwd:explain/SKILL.md) | Break down anything heavy — a plan, code file, diff, doc, stack trace, PR, URL, or concept — into a layered walkthrough. Mental model first (problem framed + best-fit form: diagram, analogy, before/after, or causal narrative), then one chunk at a time on demand. |
| productivity | [fwd:handoff](skills/productivity/fwd:handoff/SKILL.md) | Compact the current conversation into a handoff document for another agent to pick up. |
| productivity | [fwd:premortem](skills/productivity/fwd:premortem/SKILL.md) | Stress-test a plan by imagining it has already failed, list concrete failure modes across 8 categories, grade each Low/Medium/High via Likelihood × Impact, then ICE-rank 2–4 candidate mitigations per meaningful failure and flag an early-signal per finding. Closes with a "hardened plan" diff and an explicit "risks we accept" list. |

## Adding a skill

1. Create a new folder under `skills/<category>/fwd:<field-or-context>-<name>/` (e.g. `skills/engineering/fwd:git-commit/`).
2. Add a `SKILL.md` file with YAML frontmatter (`name`, `description`) and a markdown body. Bash helpers live in a sibling `scripts/` folder.
3. Register the skill folder path in `.claude-plugin/plugin.json` under `skills`.
4. Update the table above.

See [CLAUDE.md](CLAUDE.md) for repo conventions and [CONTEXT.md](CONTEXT.md) for shared vocabulary.

## Related

- [baswenneker/fwd-claude-code](https://github.com/baswenneker/fwd-claude-code) — full `fwd` workflow plugin (agents, hooks, CLI tooling); these skills are a slimmed-down subset.
- [mattpocock/skills](https://github.com/mattpocock/skills/tree/main) — layout and conventions inspiration.
