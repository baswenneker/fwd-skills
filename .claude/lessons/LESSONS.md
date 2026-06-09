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

### 2026-06-09 | insight | fwd:grill-me
**Context**: fwd:grill-me almost always asked 11–12 questions regardless of how complex the grilled plan was. The skill instructed the model to "estimate the total number of questions" upfront and prefix each as `Question N/~total:`, and the QUESTION_FORMAT.md template hardcoded the example `Question 3/~12:`.
**Observation**: A hardcoded example number in a skill template acts as an anchor — the model reproduced ~12 every time it consulted the template — and the "estimate the total upfront" instruction turned that estimate into a self-fulfilling contract the model padded to reach. Together they converted an open-ended interview into a "fill the quota" exercise.
**Lesson**: Keep illustrative templates count-free, and don't make a skill commit to a quantity before it knows the work. For open-ended/iterative skills, state termination as a goal ("until every branch is resolved / nothing material is ambiguous"), not a number, and add explicit "few … many more" range cues to break any residual anchor. Applies to any skill in this repo that embeds example counts.
