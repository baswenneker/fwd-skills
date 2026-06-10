# CLAUDE.md

Repo-level instructions for agents working in `fwd-skills`.

## Purpose

`fwd-skills` is HeadingFWD's Claude Code skills plugin. It registers a set of reusable skills via `.claude-plugin/plugin.json`. There is no application code — every directory under `skills/` is a self-contained skill consumed by Claude Code.

## Repo layout

```
.claude-plugin/plugin.json                # Plugin manifest (skill paths)
agents/<name>.md                          # Plugin subagents (auto-discovered; see "Agents")
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

## Agents

Skills may delegate to **plugin subagents** — markdown files at the plugin root in `agents/<name>.md` (subfolders allowed). They are **auto-discovered** (NOT listed in `plugin.json`) and referenced via the Agent tool's `subagent_type` as `fwd-skills:<name>` (a subfolder becomes part of the id: `agents/x/y.md` → `fwd-skills:x:y`).

Frontmatter: `name`, `description`, optional `tools` / `disallowedTools` (a `tools` allowlist is the strongest way to scope a read-only agent — what isn't granted can't be used), `model`, `isolation`, `color`. **Plugin agents ignore `hooks`, `mcpServers`, and `permissionMode`** (stripped on load for security); if an agent truly needs those, the consumer copies it into their own `.claude/agents/`.

The `fwd:mission-*` skills are the first users: `fwd-mission-coder` (write-capable), `fwd-mission-reviewer` and `fwd-mission-user-tester` (write-incapable validators — Bash for inspection, no `Write`/`Edit`). The family is three skills: `fwd:mission-plan` (interactive planning), `fwd:mission-run` (serial execution), and `fwd:mission-run-parallel` (opt-in wave-parallel sibling that shares the serial runner's scripts and state format). A mission's orchestration state + artifacts live on a `mission/<slug>` branch and are **committed there** (so the mission resumes from any worktree/clone) — deliberately not gitignored; only the per-worktree `.env` copy under `.trees/` stays ignored.

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
- **Cross-skill script references:** a skill may invoke a sibling skill's scripts via `${CLAUDE_SKILL_DIR}/../<sibling-skill>/scripts/<name>.sh`. `fwd:mission-run-parallel` → `fwd:mission-run` is the first instance in this repo. Consequence: renaming a referenced skill folder breaks its referrers — check for cross-skill dependents before renaming a skill folder.
- **README body language is English.** Skill descriptions in the README skills table mirror the SKILL.md frontmatter (so they may be Dutch when the frontmatter is Dutch — `fwd:plan` is the current example).
- See [CONTEXT.md](CONTEXT.md) for project vocabulary.

<!-- fwd:lessons:start -->
## Lessons

Persistent memory across sessions. Location: `.claude/lessons/LESSONS.md`.

**When to consult** (you decide):
- At the start of substantial work
- When uncertain about an approach or convention
- When the user references earlier work or a prior agreement

**When to append** (proactively, without asking):
- After a user correction ("no", "stop", "don't do X")
- When a surprise pattern is valuable across sessions
- When a rule, convention, or vocabulary you should have known is missing

**Format** (strict):

````
### YYYY-MM-DD | <type> | <scope>
**Context**: [what was happening]
**Observation**: [what went wrong / was observed]
**Lesson**: [what to do next time]
````

Types: `correction` | `insight` | `rule-gap` | `deviation`. Scope: skill, area, or `general`.

Use the Write tool to append to the bottom of `.claude/lessons/LESSONS.md`. If the file doesn't exist: create it with a header + format block.
<!-- fwd:lessons:end -->
