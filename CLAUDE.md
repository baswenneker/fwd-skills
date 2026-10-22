# CLAUDE.md

Repo-level instructions for agents working in `fwd-skills`.

## Purpose

`fwd-skills` is HeadingFWD's Claude Code skills plugin. It registers a set of reusable skills via `.claude-plugin/plugin.json`. There is no application code — every directory under `skills/` is a self-contained skill consumed by Claude Code.

## Repo layout

```
.claude-plugin/plugin.json                # Plugin manifest (skill paths)
skills/<category>/<field>-<name>/         # One folder per skill
  SKILL.md                                # Required: YAML frontmatter + markdown body
  scripts/                                # Optional: bash helpers (no Node tooling)
obsolete/skills/..., obsolete/agents/     # Retired skills + agents, not registered (see "Obsolete")
CONTEXT.md                                # Shared vocabulary
README.md                                 # Public-facing index
```

## Categories

Skills live under `skills/<category>/`. Pick the existing category that fits; only create a new one if no existing category covers it.

- **`engineering/`** — workflow tooling that touches code, git, builds, or repo state. Examples: `fwd:git-commit`, `fwd:rules-audit`. Side effects on the repo are expected.
- **`productivity/`** — interaction patterns and communication modes. Examples: `fwd:caveman`, `fwd:jip-janneke`. These shape how Claude responds; they don't touch the codebase.

When adding a new category, add a one-line description here too.

## Adding a skill

1. Pick or create a category under `skills/` (e.g. `engineering/`).
2. Create `skills/<category>/<field-or-context>-<name>/SKILL.md` with frontmatter:

   ```markdown
   ---
   name: <field-or-context>-<name>
   description: <one paragraph describing what it does and when to invoke>
   ---
   ```

   The `description` is what Claude Code uses to decide when the skill is relevant — be specific about trigger phrases and use-cases.

3. Add the skill's folder path to the `skills` array in `.claude-plugin/plugin.json`.
4. Update the skills table in `README.md`.
5. Raise `version` in `.claude-plugin/plugin.json` (see "Plugin version").

## Plugin version

`.claude-plugin/plugin.json` carries a `version` (since 1.0.0, 2026-10-22). Claude Code
updates an installed plugin only when that number changes, so a change that is not
followed by a raised version never reaches anyone. Raise it with every change that
users should get: patch for fixes, minor for a new skill or feature, major for a
removed or renamed skill.

## Agents

Skills may delegate to **plugin subagents** — markdown files at the plugin root in `agents/<name>.md` (subfolders allowed). They are **auto-discovered** (NOT listed in `plugin.json`) and referenced via the Agent tool's `subagent_type` as `fwd:<name>` (a subfolder becomes part of the id: `agents/x/y.md` → `fwd:x:y`).

Frontmatter: `name`, `description`, optional `tools` / `disallowedTools` (a `tools` allowlist is the strongest way to scope a read-only agent — what isn't granted can't be used), `model`, `isolation`, `color`. **Plugin agents ignore `hooks`, `mcpServers`, and `permissionMode`** (stripped on load for security); if an agent truly needs those, the consumer copies it into their own `.claude/agents/`.

**The plugin currently ships no agents.** The six that existed (`mission-coder`, `mission-reviewer`, `mission-scribe`, `mission-user-tester`, `steps-reviewer`, `steps-doubt`) moved to `obsolete/agents/` together with the skills that spawned them. Because `agents/` is auto-discovered, an agent file must physically leave that folder to be disabled — removing it from `plugin.json` is not possible.

**Shared inline norms.** Some blocks were hand-copied verbatim into several agent and skill files. `obsolete/scripts/check-agent-norms.sh` extracts a named block from every file that carries it and fails if the copies aren't byte-identical. All files it guards now live under `obsolete/`, so the script moved there too; `check-agent-norms.sh "<heading>" <file>...` still compares any block across any files if a new live skill ever needs it.

## Obsolete

Retired on 2026-09-10 and moved to `obsolete/` (layout mirrors the live tree): the `fwd:mission-*` family (unattended multi-agent missions), the `fwd:steps-*` family (attended step-by-step runs), `fwd:plan`, `fwd:codex-review-plan`, `fwd:codex-review-implementation`, `fwd:skill-eval`, `fwd:explain`, `fwd:premortem`, `fwd:unsure`, the six agents listed above, and `scripts/check-agent-norms.sh`. They are not registered in `plugin.json` and Claude Code does not load them. See `obsolete/README.md` for the table and the way back (`git mv` + a `plugin.json` line). `CONTEXT.md` keeps the mission/steps vocabulary as reference for that archived code.

## Moved out

`autocoder-issue` left this repo on 2026-09-18 for `baswenneker/workcenter`,
which ships the `workcenter` plugin. Every other autocoder skill already lived
there, and two repos creating the same six `fwd-` labels meant two sets of
colours, of which the last run won. It is `/autocoder-issue` now, not
`/fwd:autocoder-issue`. Nothing is kept here: `obsolete/` is for skills that
were retired, not for ones that live on elsewhere.

## Syncing from `fwd-claude-code`

Most skills here originate in [baswenneker/fwd-claude-code](https://github.com/baswenneker/fwd-claude-code) at `fwd/skills/<skill>/SKILL.md`. To mirror one into this repo:

1. Copy the source `SKILL.md` to `skills/<category>/fwd:<name>/SKILL.md`.
2. Verify frontmatter `name:` uses the `fwd:` prefix — rename if the upstream version is bare (e.g. `caveman` → `fwd:caveman`).
3. Update any bare-slash trigger references in the description (`/caveman` → `/fwd:caveman`).
4. Register the folder in `.claude-plugin/plugin.json` and add a row to `README.md`.
5. Check `ls ~/.claude/skills/<name>` — a personal-scope copy with the same `name` and `description` can shadow the plugin skill (Claude Code picks one), silently making every improvement made here invisible. Remove or rename the personal copy if found.

Do not back-port edits made here into `fwd-claude-code` automatically — that repo is the upstream source of truth for the canonical skill content; this repo is the slimmed-down distribution.

**Deliberately diverged from upstream:** the obsolete mission/steps/plan/skill-eval/explain files carry a stappenbudget feature, a `run_mode`, worktree-at-plan-time, and a vol-caveman text compaction that upstream does not have. They are archived now, so no sync applies to them; if one is ever revived, merge by hand — never copy over.

## Conventions

- **Skill names follow `<field-or-context>-<name>`** (e.g. `git-commit`, `rules-audit`). The `<field-or-context>` segment groups related skills (e.g. `git`, `rules`); the `<name>` segment is kebab-case. The folder name matches the `name` field in frontmatter exactly — no prefix, no colon.
- **The `fwd:` prefix comes from the plugin, not the skill name.** The plugin is named `fwd` in `.claude-plugin/plugin.json`, so Claude Code registers each skill as `/<plugin>:<skill-name>` — `/fwd:git-commit`. Do **not** put `fwd:` in a skill's `name` or folder: Claude Code rewrites the colon to a dash and you end up with `/fwd:fwd-git-commit`. Same rule for agents: `agents/foo-bar.md` → `fwd:foo-bar`.
- Keep `SKILL.md` focused; split supporting material into sibling files. Bash helpers go in a `scripts/` subfolder; reference them from `SKILL.md` via `${CLAUDE_SKILL_DIR}/scripts/<name>.sh` (resolves to the skill's own folder, works for personal, project, and plugin scopes). **No Node tooling** — bash only.
- All git commands route through `rtk git ...` (no conditional fallback to plain `git`). **Exception:** `skills/engineering/setup-review/` uses plain `git` in its scripts, its tests and the files it generates. Those run in other people's repos, on other machines and in CI, where rtk may be missing; a missing rtk would make a repo read as "not a git repository". None of that git output reaches Claude, so rtk would save nothing there.
- **Cross-skill script references:** a skill may invoke a sibling skill's scripts via `${CLAUDE_SKILL_DIR}/../<sibling-skill>/scripts/<name>.sh`. One live use: `setup-review/tests/lib.sh` runs `setup/scripts/apply-all.sh` to test its follow-up line, and `setup` names `setup-review` in that line. Two more exist under `obsolete/` (`codex-review-implementation` → `codex-review-plan`, `mission-plan` → `mission-run`). Renaming a referenced skill folder breaks its referrers — check for cross-skill dependents before renaming or moving a skill folder.
- **README body language is English.** Skill descriptions in the README skills table mirror the SKILL.md frontmatter (so they may be Dutch when the frontmatter is Dutch — `fwd:rules-audit` is the current example).
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
