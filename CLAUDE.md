# CLAUDE.md

Repo-level instructions for agents working in `fwd-skills`.

## Purpose

`fwd-skills` is HeadingFWD's Claude Code skills plugin. It registers a set of reusable skills via `.claude-plugin/plugin.json`. There is no application code — every directory under `skills/` is a self-contained skill consumed by Claude Code.

## Repo layout

```
.claude-plugin/plugin.json                # Plugin manifest (skill paths)
skills/<category>/fwd:<field>-<name>/     # One folder per skill
  SKILL.md                                # Required: YAML frontmatter + markdown body
  scripts/                                # Optional: bash helpers (no Node tooling)
CONTEXT.md                                # Shared vocabulary
README.md                                 # Public-facing index
```

## Categories

Skills live under `skills/<category>/`. Pick the existing category that fits; only create a new one if no existing category covers it.

- **`engineering/`** — workflow tooling that touches code, git, builds, or repo state. Examples: `fwd:git-commit`. Side effects on the repo are expected.
- **`productivity/`** — interaction patterns and communication modes. Examples: `fwd:grill-me`, `fwd:caveman`, `fwd:explain`. These shape how Claude responds; they don't touch the codebase.

When adding a new category, add a one-line description here too.

## Adding a skill

1. Pick or create a category under `skills/` (e.g. `engineering/`).
2. Create `skills/<category>/fwd:<field-or-context>-<name>/SKILL.md` with frontmatter:

   ```markdown
   ---
   name: fwd:<field-or-context>-<name>
   description: <one paragraph describing what it does and when to invoke>
   ---
   ```

   The `description` is what Claude Code uses to decide when the skill is relevant — be specific about trigger phrases and use-cases.

3. Add the skill's folder path to the `skills` array in `.claude-plugin/plugin.json`.
4. Update the skills table in `README.md`.

## Syncing from `fwd-claude-code`

Most skills here originate in [baswenneker/fwd-claude-code](https://github.com/baswenneker/fwd-claude-code) at `fwd/skills/<skill>/SKILL.md`. To mirror one into this repo:

1. Copy the source `SKILL.md` to `skills/<category>/fwd:<name>/SKILL.md`.
2. Verify frontmatter `name:` uses the `fwd:` prefix — rename if the upstream version is bare (e.g. `caveman` → `fwd:caveman`).
3. Update any bare-slash trigger references in the description (`/caveman` → `/fwd:caveman`).
4. Register the folder in `.claude-plugin/plugin.json` and add a row to `README.md`.

Do not back-port edits made here into `fwd-claude-code` automatically — that repo is the upstream source of truth for the canonical skill content; this repo is the slimmed-down distribution.

## Conventions

- **Skill names follow `fwd:<field-or-context>-<name>`** (e.g. `fwd:git-commit`, `fwd:rules-audit`). The `<field-or-context>` segment groups related skills (e.g. `git`, `rules`); the `<name>` segment is kebab-case. The folder name matches the `name` field in frontmatter exactly — colon and all.
- The slash command is the same string with a leading `/` (e.g. `/fwd:git-commit`).
- Keep `SKILL.md` focused; split supporting material into sibling files. Bash helpers go in a `scripts/` subfolder; reference them from `SKILL.md` via `${CLAUDE_SKILL_DIR}/scripts/<name>.sh` (resolves to the skill's own folder, works for personal, project, and plugin scopes). **No Node tooling** — bash only.
- All git commands route through `rtk git ...` (no conditional fallback to plain `git`).
- See [CONTEXT.md](CONTEXT.md) for project vocabulary.
