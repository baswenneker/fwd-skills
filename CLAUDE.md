# CLAUDE.md

Repo-level instructions for agents working in `fwd-skills`.

## Purpose

`fwd-skills` is HeadingFWD's Claude Code skills plugin. It registers a set of reusable skills via `.claude-plugin/plugin.json`. There is no application code — every directory under `skills/` is a self-contained skill consumed by Claude Code.

## Repo layout

```
.claude-plugin/plugin.json   # Plugin manifest (skill paths)
skills/<category>/<skill>/   # One folder per skill
  SKILL.md                   # Required: YAML frontmatter + markdown body
CONTEXT.md                   # Shared vocabulary
README.md                    # Public-facing index
```

## Adding a skill

1. Pick or create a category under `skills/` (current: `examples/`).
2. Create `skills/<category>/<skill-name>/SKILL.md` with frontmatter:

   ```markdown
   ---
   name: <skill-name>
   description: <one paragraph describing what it does and when to invoke>
   ---
   ```

   The `description` is what Claude Code uses to decide when the skill is relevant — be specific about trigger phrases and use-cases.

3. Add the skill's folder path to the `skills` array in `.claude-plugin/plugin.json`.
4. Update the skills table in `README.md`.

## Conventions

- Skill names use `kebab-case` and match the folder name and the `name` field in frontmatter.
- Keep `SKILL.md` focused; split supporting material into sibling markdown files (e.g. `references.md`, `examples.md`) when the main file gets long.
- See [CONTEXT.md](CONTEXT.md) for project vocabulary.
