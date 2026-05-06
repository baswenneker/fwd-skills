# fwd-skills

HeadingFWD's Claude Code skills plugin.

A lightweight, plain-markdown skill registry, structured after [mattpocock/skills](https://github.com/mattpocock/skills). Skills are organised by category under `skills/` and registered in `.claude-plugin/plugin.json`.

## Installation

Add this repo as a local plugin marketplace in Claude Code:

```bash
/plugin marketplace add /path/to/fwd-skills
```

Then enable the `fwd-skills` plugin from the marketplace.

## Skills

| Category | Skill | Description |
| --- | --- | --- |
| examples | [hello-world](skills/examples/hello-world/SKILL.md) | Minimal example skill that prints a friendly greeting. |

## Adding a skill

1. Create a new folder under `skills/<category>/<skill-name>/`.
2. Add a `SKILL.md` file with YAML frontmatter (`name`, `description`) and a markdown body.
3. Register the skill folder path in `.claude-plugin/plugin.json` under `skills`.
4. Update the table above.

See [CLAUDE.md](CLAUDE.md) for repo conventions and [CONTEXT.md](CONTEXT.md) for shared vocabulary.
