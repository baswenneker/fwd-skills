# Lessons

Persistent learnings from prior sessions. Append-only, newest at the bottom.

## Format

````
### YYYY-MM-DD | <type> | <scope>
**Context**: ...
**Observation**: ...
**Lesson**: ...
````

- **type**: correction | insight | rule-gap | deviation
- **scope**: free-form — skill (e.g. `fwd:git-commit`), area (`engineering`), or `general`

## Entries

<!-- new entries appended below -->

### 2026-06-02 | rule-gap | fwd-skills
**Context**: Building the fwd:mission-* skills, which are the repo's first to ship subagents (coder, reviewer, user-tester).
**Observation**: CLAUDE.md documented only `skills/` — nothing about how a plugin ships agents, so the convention had to be re-derived from the Claude Code docs.
**Lesson**: Plugin subagents live at the plugin root in `agents/<name>.md`, are auto-discovered (NOT listed in `plugin.json`), and are referenced via `subagent_type` as `fwd-skills:<name>`. Plugin agents ignore `hooks`/`mcpServers`/`permissionMode` (stripped on load). Scope read-only agents with a `tools` allowlist (omit `Write`/`Edit`). Now documented in CLAUDE.md "## Agents".

### 2026-06-03 | insight | fwd:mission-run
**Context**: The mission scripts passed every milestone test in a scratch repo, but a branch review found they broke in real use.
**Observation**: Tests ran scripts from the MAIN checkout, while the skill runs them after cd-ing into the worktree — where `git rev-parse --show-toplevel` returns the worktree and doubles derived paths. Separately, a "did the coder commit?" check used `git rev-list --count`, which counts metadata checkpoint commits and false-passes a no-op coder.
**Lesson**: Test a script from the cwd it actually runs in (the worktree, not just main). Resolve the main repo via `--git-common-dir` so scripts are cwd-independent. To prove real work happened, diff for code changes (excluding metadata paths), never count commits.
