# fwd-skills

HeadingFWD's Claude Code skills plugin.

A lightweight, plain-markdown skill registry, structured after [mattpocock/skills](https://github.com/mattpocock/skills/tree/main). Skills are organised by category under `skills/` and registered in `.claude-plugin/plugin.json`. The skills here are extracted standalone from [baswenneker/fwd-claude-code](https://github.com/baswenneker/fwd-claude-code) so they can be installed without the rest of the `fwd` workflow.

## Installation

> Only tested with [Claude Code](https://claude.ai/code).

```bash
npx skills@latest add baswenneker/fwd-skills
```

## Skills

| Category | Skill | Description |
| --- | --- | --- |
| engineering | [fwd:git-commit](skills/engineering/fwd:git-commit/SKILL.md) | Stage and commit with conventional message — pre-flight scan blocks risky files (.env, logs, keys, secrets, >1MB). |
| productivity | [fwd:grill-me](skills/productivity/fwd:grill-me/SKILL.md) | Interview the user relentlessly about a plan or design until reaching shared understanding, resolving each branch of the decision tree. |
| productivity | [fwd:caveman](skills/productivity/fwd:caveman/SKILL.md) | Ultra-compressed communication mode. Cuts token usage ~75% by dropping filler, articles, and pleasantries while keeping full technical accuracy. |
| productivity | [fwd:explain](skills/productivity/fwd:explain/SKILL.md) | Break down anything heavy — a plan, code file, diff, doc, stack trace, PR, URL, or concept — into a layered walkthrough. Mental model first (problem framed + best-fit form: diagram, analogy, before/after, or causal narrative), then one chunk at a time on demand. |
| productivity | [fwd:plan](skills/productivity/fwd:plan/SKILL.md) | Plan an implementation: gather context, ask numbered-choice clarifying questions inline, present three options (minimal / uitgebreid / pragmatisch) with TL;DR + details + changes table, close with a comparative verdict. |

## Adding a skill

1. Create a new folder under `skills/<category>/fwd:<field-or-context>-<name>/` (e.g. `skills/engineering/fwd:git-commit/`).
2. Add a `SKILL.md` file with YAML frontmatter (`name`, `description`) and a markdown body. Bash helpers live in a sibling `scripts/` folder.
3. Register the skill folder path in `.claude-plugin/plugin.json` under `skills`.
4. Update the table above.

See [CLAUDE.md](CLAUDE.md) for repo conventions and [CONTEXT.md](CONTEXT.md) for shared vocabulary.

## Related

- [baswenneker/fwd-claude-code](https://github.com/baswenneker/fwd-claude-code) — full `fwd` workflow plugin (agents, hooks, CLI tooling); these skills are a slimmed-down subset.
- [mattpocock/skills](https://github.com/mattpocock/skills/tree/main) — layout and conventions inspiration.
