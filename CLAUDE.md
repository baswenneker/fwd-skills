# CLAUDE.md

Repo-level instructions for agents working in `fwd-skills`.

## Purpose

`fwd-skills` is HeadingFWD's Claude Code skills plugin. It registers a set of reusable skills via `.claude-plugin/plugin.json`. There is no application code — every directory under `skills/` is a self-contained skill consumed by Claude Code.

## Repo layout

```
.claude-plugin/plugin.json                # Plugin manifest (skill paths)
agents/<name>.md                          # Plugin subagents (auto-discovered; see "Agents")
skills/<category>/<field>-<name>/         # One folder per skill
  SKILL.md                                # Required: YAML frontmatter + markdown body
  scripts/                                # Optional: bash helpers (no Node tooling)
CONTEXT.md                                # Shared vocabulary
README.md                                 # Public-facing index
```

## Categories

Skills live under `skills/<category>/`. Pick the existing category that fits; only create a new one if no existing category covers it.

- **`engineering/`** — workflow tooling that touches code, git, builds, or repo state. Examples: `fwd:git-commit`. Side effects on the repo are expected.
- **`productivity/`** — interaction patterns and communication modes. Examples: `fwd:caveman`, `fwd:explain`. These shape how Claude responds; they don't touch the codebase.

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

## Agents

Skills may delegate to **plugin subagents** — markdown files at the plugin root in `agents/<name>.md` (subfolders allowed). They are **auto-discovered** (NOT listed in `plugin.json`) and referenced via the Agent tool's `subagent_type` as `fwd:<name>` (a subfolder becomes part of the id: `agents/x/y.md` → `fwd:x:y`).

Frontmatter: `name`, `description`, optional `tools` / `disallowedTools` (a `tools` allowlist is the strongest way to scope a read-only agent — what isn't granted can't be used), `model`, `isolation`, `color`. **Plugin agents ignore `hooks`, `mcpServers`, and `permissionMode`** (stripped on load for security); if an agent truly needs those, the consumer copies it into their own `.claude/agents/`.

The `fwd:mission-*` skills are the first users: `mission-coder` (write-capable), `mission-reviewer` and `mission-user-tester` (validators with no `Write`/`Edit` — Bash for inspection only; the no-mutation rule is instruction, not tooling, so both carry it as an explicit prohibition), and `mission-scribe` (read-only, Haiku — compiles the milestone walkthrough, including its verification pass against the diff, but never judges anything). The family is two skills: `fwd:mission-plan` (interactive planning) and `fwd:mission-run` (serial execution). A mission's orchestration state + artifacts live on a `mission/<slug>` branch and are **committed there** (so the mission resumes from any worktree/clone) — deliberately not gitignored; only the per-worktree `.env` copy under `.trees/` stays ignored.

The `fwd:steps-*` family (attended counterpart of missions) uses two more: `steps-reviewer` (read-only fresh-eyes verdict per step: re-runs the gate, fake-test check, rules compliance, ponytail over-engineering pass) and `steps-doubt` (read-only, caveman-terse; spawned twice every 4 approved steps with one probing question each). Both pull the diff themselves via `rtk git diff` — the orchestrator never pastes diffs into prompts. Key contrast with missions: the **main session writes the code inline** (first-hand explanations) rather than delegating to a coder subagent, and in attended mode a commit happens only after the user approves a step at its gate (a run that is autonomous from the start commits per step on a clean reviewer verdict instead — see the run-mode divergence note below). Like missions it runs in a worktree at `.trees/steps/<slug>/`, and — as of the worktree-at-plan change — it creates that worktree the same way missions do: `fwd:steps-plan`'s `init-steps.sh` cuts the `steps/<slug>` branch **and** its worktree in one step (`git worktree add -b`), scaffolds `.claude/steps/<slug>/` **inside the worktree**, and commits the plan there — the main checkout is never switched, so parallel terminals sharing it are undisturbed (uncommitted work there stays put and does not travel into the worktree). `fwd:steps-run`'s first action, `setup-worktree.sh`, then just **reuses** that worktree (recreating it from the branch on a fresh clone; its switch-the-main-checkout-back-to-base branch survives only as a safety net for an old in-place plan or a manual switch). From there the main session writes, gates, and commits inside the worktree (`<WT>`), which it also passes as the repo-root to the reviewer/doubt subagents. State still travels on the branch, so the run resumes from any clone.

**Shared inline norms across agents.** A few tool prohibitions are hand-copied verbatim into several agent files (the `## Shared tool prohibitions` block: the no-rtk-pipe and no-`find /` bans). To stop those copies from silently drifting apart, `scripts/check-agent-norms.sh` extracts the named block from every agent that carries it and fails if the copies aren't byte-identical. Run it before committing any edit to an `agents/*.md` file that touches a shared block; with no arguments it guards the repo's real agents, and `check-agent-norms.sh "<heading>" <file>...` compares any block across any files. Role-specific prohibitions (e.g. the coder's handoff wording, the reviewer's `-C <worktree>` git usage) deliberately stay in each agent's own `## Behavior prohibitions` block and are **not** guarded — only the genuinely-universal block is mirrored. The no-argument default also guards a second block this way: `## Shared Codex handoff`, hand-copied into `codex-review-plan/SKILL.md` and `codex-review-implementation/SKILL.md`. A third guarded block is `## Gedeelde taalregel` (the user-facing language norm: report text is Dutch, self-explanatory, free of skill-internal codes like `gate ✓ 10/10` or bare VC-IDs) — hand-copied into the five report-producing agents (`steps-reviewer`, `steps-doubt`, `mission-scribe`, `mission-reviewer`, `mission-user-tester`) and three skills (`steps-run`, `codex-review-plan`, `codex-review-implementation`).

**Rules-driven missions.** The mission family uses `.claude/rules/` as the source of truth for repo conventions. Bootstrap it with `/fwd:rules-audit` — the skill scans the codebase, proposes rule files each backed by at least one golden example (a path to a real, exemplary file), and writes only after explicit user approval. Only markdown files under `.claude/rules/` are written; no other files are touched.

How the mission skills consume rules:
- **`fwd:mission-plan`** inventories available rule files at session start (via `list-rules.sh`), forces a conscious choice when none are found (run `/fwd:rules-audit` first, or proceed without), generates compliance validation criteria (VC-IDs) per feature from the matching rule files, and records a `rules_manifest` in `state.json`.
- **`fwd:mission-run`** pins the feature's matched rule files as a mandatory reading list in the coder spawn prompt, rejects a coder handoff when `rule_paths` is non-empty and `rules_applied` is missing (accountability without verantwoording is refused), compiles a milestone walkthrough after each milestone, and proposes rule candidates (rule-kandidaten) at finalize — the runner never mutates `.claude/rules/` itself; the human decides.

## Syncing from `fwd-claude-code`

Most skills here originate in [baswenneker/fwd-claude-code](https://github.com/baswenneker/fwd-claude-code) at `fwd/skills/<skill>/SKILL.md`. To mirror one into this repo:

1. Copy the source `SKILL.md` to `skills/<category>/fwd:<name>/SKILL.md`.
2. Verify frontmatter `name:` uses the `fwd:` prefix — rename if the upstream version is bare (e.g. `caveman` → `fwd:caveman`).
3. Update any bare-slash trigger references in the description (`/caveman` → `/fwd:caveman`).
4. Register the folder in `.claude-plugin/plugin.json` and add a row to `README.md`.

Do not back-port edits made here into `fwd-claude-code` automatically — that repo is the upstream source of truth for the canonical skill content; this repo is the slimmed-down distribution.

**Deliberately diverged from upstream (2026-07-09):** `fwd:steps-plan`, `fwd:steps-run`, `fwd:plan` (plus its new `REFERENCE.md`), `fwd:skill-eval`, `fwd:explain`, `fwd:jip-janneke`, and the `fwd:mission-*` files (both SKILL.md's and both REFERENCE.md's) carry the stappenbudget feature and/or a deliberate vol-caveman text compaction that upstream does not have. Mirroring these skills means **manual merging, never copy-over** — a routine sync would silently revert the stappenbudget and the compaction.

**Also diverged (2026-07-30):** the steps family gained an **uitvoermodus** (run mode). `fwd:steps-plan` asks for it at the same approval that accepts the step list (`ok` = attended, `ok auto` = autonomous — no extra turn, and deliberately *no* argument token, since `auto` is already the step budget there) and persists it as top-level `run_mode` in `state.json` + a word in `plan.md`'s header line. `fwd:steps-run` reads it in section 0, accepts a second argument (`<slug> auto|attended`) as a session-only override, and — when a run is autonomous **from the start** — commits every step via plain `record-step.sh` (clean tree per step, no snapshots, no `--no-commit`), ending in section 9's normal final report with the autonomous overview on top. The old `--no-commit` accumulation + `finalize-autonomous.sh` path survives unchanged for the *mid-run* `auto` (there uncommitted work already exists, so commit boundaries are gone). `approved_mode` on a step therefore names the **commit regime**, not who approved — deliberately not renamed, because `status.sh` derives `pending_autonomous_commit` from it and renaming would misread existing plans. A routine sync must not drop `run_mode` or collapse the two autonomous entry points back into one.

**Also diverged (2026-07-24):** `fwd:steps-plan` now creates the worktree at **plan** time (mirroring `fwd:mission-plan`'s `init-mission.sh`) instead of `git switch -c`-ing the shared checkout, and `fwd:steps-run` merely reuses it. This touches `init-steps.sh`, `setup-worktree.sh`, and both steps `SKILL.md`s. A routine sync must not restore the old plan-in-place `git switch -c` flow. Same date: the step report in `fwd:steps-run` (section 5) was redesigned to a decision-first template (open points on top, changes grouped per folder, titles above text — chosen by Bas after the first real run) and the tussenbalans template (section 7) lost its side-by-side label columns; a sync must not bring back the old ±15-line two-column report.

## Conventions

- **Skill names follow `<field-or-context>-<name>`** (e.g. `git-commit`, `rules-audit`). The `<field-or-context>` segment groups related skills (e.g. `git`, `rules`); the `<name>` segment is kebab-case. The folder name matches the `name` field in frontmatter exactly — no prefix, no colon.
- **The `fwd:` prefix comes from the plugin, not the skill name.** The plugin is named `fwd` in `.claude-plugin/plugin.json`, so Claude Code registers each skill as `/<plugin>:<skill-name>` — `/fwd:git-commit`. Do **not** put `fwd:` in a skill's `name` or folder: Claude Code rewrites the colon to a dash and you end up with `/fwd:fwd-git-commit`. Same rule for agents: `agents/mission-coder.md` → `fwd:mission-coder`.
- Keep `SKILL.md` focused; split supporting material into sibling files. Bash helpers go in a `scripts/` subfolder; reference them from `SKILL.md` via `${CLAUDE_SKILL_DIR}/scripts/<name>.sh` (resolves to the skill's own folder, works for personal, project, and plugin scopes). **No Node tooling** — bash only.
- All git commands route through `rtk git ...` (no conditional fallback to plain `git`).
- **Cross-skill script references:** a skill may invoke a sibling skill's scripts via `${CLAUDE_SKILL_DIR}/../<sibling-skill>/scripts/<name>.sh`. Two such references exist: `fwd:mission-plan` (stap 4.7, boot-preflight) calls `fwd:mission-run`'s `boot-app.sh --probe`, and `fwd:codex-review-implementation` calls `fwd:codex-review-plan`'s `resolve-plan-artifact.sh`. Renaming a referenced skill folder breaks its referrers — check for cross-skill dependents before renaming a skill folder.
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
