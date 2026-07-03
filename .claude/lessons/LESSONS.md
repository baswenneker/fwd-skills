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

### 2026-06-10 | insight | fwd:mission-run
**Context**: First live mission run (parallel-mission-runner), recording features per SKILL.md step 2.4
**Observation**: record-feature.sh's clean-tree check rejects exactly what the documented flow produces: the untracked handoffs/<fid>.md the orchestrator writes before recording, and the state.json left dirty on purpose by log-decision.sh — even though the script itself stages .claude/missions/<slug> right after the check
**Lesson**: Either exclude .claude/missions/<slug>/ from the clean check in record-feature.sh, or document that the orchestrator must commit handoff + decision writes as a chore(mission) commit before calling record-feature.sh (current workaround)

### 2026-06-10 | insight | fwd-skills/scripts
**Context**: Writing the parallel-runner scripts and harness (mission parallel-mission-runner, M2)
**Observation**: Two recurring traps: rtk git emits literal ok lines on quiet/clean operations so any porcelain/output parser must filter them (grep -vx ok), and bare rtk git resolves the repo from cwd so scripts invoked from outside a git tree silently hit the wrong repo
**Lesson**: In fwd-skills bash helpers, always filter rtk ok lines when parsing git output and pass -C <path> (or cd in a subshell) for every git op that must target a specific worktree

### 2026-06-11 | insight | rules-driven-missions
**Context**: F9 coder self-verified VC-20 with a grep for CONTEXT.md mentions across the six audit files and reported 6/6 present; the adversarial reviewer failed the milestone because the reviewer agent's only CONTEXT.md mention pointed at the advisories vocabulary entry, not the required Schrijfstijl block
**Observation**: A loose proxy grep (any CONTEXT.md mention) false-passed a compliance check that required a specific marker (a Schrijfstijl missions reference)
**Lesson**: When self-verifying per-file compliance criteria, grep for the specific required marker verbatim (e.g. Schrijfstijl), never a broad proxy like the filename being referenced — and treat each clause of a multi-file VC as its own check per file

### 2026-06-11 | rule-gap | fwd:mission-run
**Context**: Orchestrating mission jip-janneke-skill per SKILL.md: write handoff narrative, log decisions, then record-feature.sh
**Observation**: record-feature.sh's clean-worktree check rejects the pre-written handoff narrative AND the state.json edit made by log-decision.sh (its exclusions cover only .env*/boot artifacts, not .claude/missions/<slug>), yet the script itself git-adds that dir at commit time — the documented orchestrator order trips the recorder
**Lesson**: Record first with a clean tree (commit_sha stays the coder's commit), then write the narrative / re-log decisions and amend the checkpoint commit; or fix the scripts to exclude .claude/missions/<slug> from the dirty check

### 2026-06-26 | rule-gap | fwd:mission-* (coder/reviewer comments)
**Context**: A real mission worktree (sandbox-usecase-prototype) shipped code whose test docstrings and comments referenced mission-internal codes — `# VC-4a: …`, `"""Tests voor F3 … (VC-5)"""`, and even `# … in de pre-F4 implementatie zat`.
**Observation**: The coder receives the VC-IDs/feature-IDs verbatim as the feature's "definition of done" and naturally threads them into comments as requirement-traceability. CONTEXT.md's "Vertaal interne codes; dump ze niet rauw" rule covered only reports/walkthroughs/handoffs, never code comments — so nothing forbade it, and the reviewer had no VC to fail it on.
**Lesson**: Comments must describe what/why and read standalone — never mission-internal codes (F#/M#/VC-IDs) or history references ("pre-F4"). Fixed in three places: CONTEXT.md's new "Codecommentaar" block (the norm), the coder agent (told the IDs are internal-only input), and a standing comment-hygiene scrutiny-VC that mission-plan generates per milestone so the reviewer fails violations hard. General pattern: when an agent is handed internal identifiers as input, state explicitly whether they may appear in its output.

### 2026-07-03 | insight | fwd:steps-* (skill-ontwerp)
**Context**: Bouw van de steps-familie (attended tegenhanger van missions). Bas scherpte tijdens de bouw twee eisen aan: "ik wil nog een check of je echt goed naar ponytail hebt gekeken — ik vind eenvoudige code erg belangrijk", en een tussenbalans na elke 4 stappen met twee zelftwijfel-vragen via caveman-subagents.
**Observation**: Een eenvoud-discipline als samenvatting opnemen ("gebruik de Lazy Ladder") is voor Bas te dun; hij wil de volledige discipline aantoonbaar verwerkt. Periodieke twijfel-momenten ("What are you least confident about?" / "What am I missing?") wil hij als vast ritme in attended loops, niet ad hoc.
**Lesson**: Bij code-genererende skills: neem eenvoud-regels letterlijk en volledig op (ladder verbatim, oorzaak-boven-symptoom, geen ongevraagde abstracties, saai boven slim, safety floor) — niet parafraseren. En bouw periodieke zelftwijfel-reviews in: deterministische trigger in bash (done % 4), oordeel bij verse read-only subagents, consolidatie in helder Nederlands bij de orchestrator.
