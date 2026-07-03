# fwd-skills

HeadingFWD's Claude Code skills plugin.

A lightweight, plain-markdown skill registry, structured after [mattpocock/skills](https://github.com/mattpocock/skills/tree/main). Skills are organised by category under `skills/` and registered in `.claude-plugin/plugin.json`. The skills here are extracted standalone from [baswenneker/fwd-claude-code](https://github.com/baswenneker/fwd-claude-code) so they can be installed without the rest of the `fwd` workflow.

## Installation

> Only tested with [Claude Code](https://claude.ai/code).

**Option A — as a Claude Code plugin** (recommended; the only option that includes the `fwd:mission-*` agents):

```bash
claude plugin marketplace add baswenneker/fwd-skills
claude plugin install fwd-skills@headingfwd
```

Installs the skills **and** the bundled subagents (`fwd-mission-coder`, `fwd-mission-reviewer`, `fwd-mission-user-tester` for missions; `fwd-steps-reviewer`, `fwd-steps-doubt` for steps-runs) that the orchestrator skills spawn as `fwd-skills:*`. Restart Claude Code after installing so the agents register.

**Option B — skills only, via the skills CLI:**

```bash
npx skills@latest add baswenneker/fwd-skills
```

The skills CLI syncs `skills/` only — it does **not** install the `agents/` directory. The interaction/communication skills work fine, but `/fwd:mission-run` and `/fwd:steps-run` will fail to spawn their subagents (`Agent type 'fwd-skills:fwd-mission-coder' not found`). Use Option A if you want Missions or Steps.

## Setup

After installing the plugin, run the setup wizard to enable optional HeadingFWD conventions:

```
/fwd:setup
```

Each feature has its own Yes/No prompt. The wizard is idempotent — re-running it is safe; existing entries are detected and refreshed in place.

### Scope: project-local vs user-global

Before any feature is installed, the wizard asks where it should land:

- **Project-local** — payload lives under `<project>/.claude/`, settings merge into `.claude/settings.local.json`, instructions append to the project's `CLAUDE.md`. The convention applies to this repo only. Defaulted when you're inside a git repo.
- **User-global** — payload lives under `~/.claude/`, settings merge into `~/.claude/settings.json`, instructions append to `~/.claude/CLAUDE.md`. The convention applies everywhere you run Claude Code.

### Feature: smartlint Stop-hook

- **Why** — consistent code quality without thinking about it: lint runs automatically after every Claude response.
- **How** — a Stop-hook fires after each response and runs `smart-lint.sh`. The wrapper diffs against git so unchanged code is skipped.
- **What** — copies `smart-lint.sh` + wrapper into `.claude/hooks/` and merges a hook entry into the matching `settings.json`. The script auto-detects project type (TS / Go / Python / Rust / Nix / shell) and runs the appropriate linters.
- **Skip if** — you don't want automatic lint checks after Claude actions.

### Feature: lessons memory file

- **Why** — Claude remembers corrections, conventions and patterns across sessions instead of starting blank each conversation.
- **How** — an instruction section in `CLAUDE.md` tells Claude when to read `LESSONS.md` and when to append (after corrections, surprises, missing rules).
- **What** — injects a marker-bracketed section (`<!-- fwd:lessons:start -->` … `<!-- fwd:lessons:end -->`) into `CLAUDE.md` and scaffolds an empty `LESSONS.md` next to it. Existing entries are never overwritten on re-run.
- **Skip if** — you'd rather Claude start each conversation with a clean slate.

## Rules-driven missions

The `fwd:mission-*` family supports a rules-driven workflow. Project conventions live under `.claude/rules/` as markdown files bootstrapped interactively by `/fwd:rules-audit` (golden examples, explicit approval, writes only after the user agrees). The planner (`fwd:mission-plan`) reads those rules at session start and generates compliance validation criteria (VC-IDs) tied to the touched files. The runner (`fwd:mission-run`) pins the matching rules per feature as a binding reading list for the coder, enforces a `rules_applied` accountability field in the handoff, compiles a milestone walkthrough after each milestone, and proposes rule candidates at finalize — the human decides whether to add them.

## Steps: attended, one reviewed step at a time

The `fwd:steps-*` family is the attended counterpart of missions, for work where you stay at the keyboard. `/fwd:steps-plan` pins a Definition of Done with a concrete "this is what done looks like" anchor, agrees the test seams, and cuts the work into small steps (one demonstrable behavior each, 1-3 tests, ~5 minutes of review). `/fwd:steps-run` then executes exactly one step per turn — failing test first, minimal implementation along ponytail's Lazy Ladder, a fresh-eyes verdict from a read-only reviewer subagent — and stops with a ±15-line step report ("Stap 7/20") until you approve. Approval is the commit: the git history becomes a log of decisions you actually reviewed. Every 4 approved steps, two caveman-style doubt agents probe what we're least confident about and what's being missed. Missions stay the tool for unattended/overnight runs.

## Skills

| Category | Skill | Description |
| --- | --- | --- |
| engineering | [fwd:git-commit](skills/engineering/fwd:git-commit/SKILL.md) | Stage and commit with conventional message — pre-flight scan blocks risky files (.env, logs, keys, secrets, >1MB) |
| engineering | [fwd:issue-create](skills/engineering/fwd:issue-create/SKILL.md) | Interactief een GitHub issue opstellen volgens een vast 5-secties template (probleem, voorbeelden, bevindingen, potentiële oplossing, tests). Skill leest input uit een argument óf de huidige conversatie-context, detecteert bestaande repo-labels, vraagt om een assignee, en laat de gebruiker de complete draft per sectie reviewen voordat `gh issue create` wordt aangeroepen. Use when user wants to create a GitHub issue from a problem they are describing, runs `/fwd:issue-create`, says "maak een issue", or "create issue from context". |
| engineering | [fwd:issue-fix](skills/engineering/fwd:issue-fix/SKILL.md) | Privately work through your assigned GitHub issues overnight — pick the oldest open issue, fix it in an isolated worktree, run tests, commit (no push). Driven by /loop. Strictly read-only on GitHub (no labels, no comments, no PRs) so collaborators can't tell the work was automated; all state local in `.claude/issue-loop/state.json`. Use when user says "work through my GitHub issues overnight", runs `/loop /fwd:issue-fix`, or invokes `/fwd:issue-fix` to fix one issue. |
| engineering | [fwd:mission-plan](skills/engineering/fwd:mission-plan/SKILL.md) | Plan a multi-agent "mission" — scope a software goal through conversation, write a PRD plus a validation contract (what "done" means, before any code), decompose into features and milestones, then create the mission branch and persist the plan on it. The interactive half of the fwd:mission-* orchestration layer (modelled on Factory.ai Missions); execution is handled afterwards by /fwd:mission-run. Use when the user wants to plan a larger feature as an orchestrated mission, says "plan a mission", "start a mission", "scope this as a mission", or invokes /fwd:mission-plan. |
| engineering | [fwd:mission-run](skills/engineering/fwd:mission-run/SKILL.md) | Execute a planned mission — the resident orchestrator of the fwd:mission-* layer (a Claude Code take on Factory.ai Missions). Reads the mission's state.json, drives features one at a time by spawning a fresh coder subagent each, runs adversarial validators (Scrutiny + User-Testing) at milestone boundaries, and records a checkpoint after every unit so the mission resumes from any worktree or clone. Runs autonomously — never prompts. Use when the user runs /fwd:mission-run <slug>, says "run/execute/resume mission <slug>", or wraps it in /loop for a long multi-day run. Pass `status` as a second argument for a read-only progress report. |
| engineering | [fwd:plan](skills/engineering/fwd:plan/SKILL.md) | Plan een implementatie — verzamel codebase-context, presenteer eerst een DoD-voorstel met numbered bullets (akkoord of corrigeer in plain text, géén AskUserQuestion), stel daarna 0-3 verdiepende keuzes via AskUserQuestion, en presenteer 1 of 3 plannen in visueel distincte boxen met spec-strip + TL;DR + Wijzigingen-tabel. Sluit af met (Recommended)-tag op het beste plan en een verdict-block, en legt na de plan-keuze een licht contract vast in `.claude/plan-contracts/<slug>.md`. `/fwd:plan check [<slug>]` toetst achteraf de diff en de DoD-bewijsregels tegen dat contract. Use when user wants to plan a feature, refactor, or change met meerdere opties op tafel, of invokes /fwd:plan. |
| engineering | [fwd:rules-audit](skills/engineering/fwd:rules-audit/SKILL.md) | Interactief de `.claude/rules/` directory bootstrappen voor een repo. De skill scant de codebase, stelt regelbestanden voor — elk voorzien van minimaal één golden example (een pad naar een echt, exemplarisch bestand) — en schrijft pas weg na expliciete goedkeuring van de gebruiker. Gebruik bij "rules audit", "bootstrap rules", "stel regels op", "maak claude rules", of als je `/fwd:rules-audit` aanroept. |
| engineering | [fwd:setup](skills/engineering/fwd:setup/SKILL.md) | Setup wizard for HeadingFWD's optional Claude Code conventions. Asks the user in a single multiselect dialog which features to install (currently smartlint Stop-hook, a lessons memory file, gitignore entries for fwd runtime artefacts, Claude Code's clear-context prompt on plan accept, and disabling Claude Code's default commit/PR attribution), then runs the matching installers in batch — copying bundled payload files into .claude/hooks/ or .claude/lessons/, merging JSON snippets into ~/.claude/settings.json or .claude/settings.local.json, injecting an instructions section into CLAUDE.md (lessons), or appending a marker-bracketed block to .gitignore. Idempotent and modular — each feature lives in scripts/<feature>/. Use only when the user invokes /fwd:setup explicitly. |
| engineering | [fwd:skill-eval](skills/engineering/fwd:skill-eval/SKILL.md) | Black-box self-evaluation for any Claude Code skill. Reads the target SKILL.md, extracts its surface (triggers, CLI flags, input/output formats, documented exit codes, examples), generates ~10 experiments covering happy paths, flag interactions, error paths, and domain invariants, runs each in an isolated workdir under tmp/eval/, and reports pass/fail in a single markdown table. Refuses to run on a dirty working tree. Ends the report with an undo prompt — reply with `x` or `undo` to remove tmp/eval/. Use when the user says "self-evaluate skill X", "shake down skill X", "test skill X end-to-end", "regression-check skill X after my refactor", "does this skill still behave the way SKILL.md claims", or invokes /fwd:skill-eval. |
| engineering | [fwd:steps-plan](skills/engineering/fwd:steps-plan/SKILL.md) | Plan een klus als een reeks kleine, toetsbare stappen voor attended uitvoering met /fwd:steps-run — de lichte tegenhanger van fwd:mission-plan. Scope het doel kort, pin een Definition of Done mét concreet eindbeeld (input→output-voorbeeld of ASCII-mockup), spreek de testplekken (seams) af, en lever een genummerde stappenlijst waarin elke stap één aantoonbaar gedrag is met een machinaal toetsbaar klaar-criterium. Use when the user zegt "plan dit in stappen", "maak een stappenplan", "steps-plan", of invokes /fwd:steps-plan. Niet voor onbeheerd/overnight werk — dat is fwd:mission-plan. |
| engineering | [fwd:steps-run](skills/engineering/fwd:steps-run/SKILL.md) | Voer een stappenplan van /fwd:steps-plan uit — attended, precies één stap per beurt. Per stap; falende test eerst (rood), minimale implementatie langs de Lazy Ladder (groen), volledige gate, vers oordeel door een read-only reviewer-subagent, en een stap-rapport van ±15 regels met "Stap N/M"-teller — daarna stopt de beurt en beslist de gebruiker (ok = commit & door, m = meer detail, stop = pauze, vrije tekst = correctie/vraag/planwijziging). Elke 4 goedgekeurde stappen een tussenbalans door twee doubt-subagents. Use when the user runs /fwd:steps-run <slug>, zegt "volgende stap", "ga door met het stappenplan", of "hervat <slug>". Zonder argument: lijst alle stappenplannen. Niet voor onbeheerd werk — dat is fwd:mission-run. |
| productivity | [fwd:grill-me](skills/productivity/fwd:grill-me/SKILL.md) | Interview the user relentlessly about a plan or design until reaching shared understanding, resolving each branch of the decision tree. Use when user wants to stress-test a plan, get grilled on their design, or mentions "grill me". |
| productivity | [fwd:caveman](skills/productivity/fwd:caveman/SKILL.md) | Ultra-compressed communication mode. Cuts token usage ~75% by dropping filler, articles, and pleasantries while keeping full technical accuracy. Use when user says "caveman mode", "talk like caveman", "use caveman", "less tokens", "be brief", or invokes /fwd:caveman. |
| productivity | [fwd:explain](skills/productivity/fwd:explain/SKILL.md) | Break down anything heavy — a plan, code file, diff, doc, stack trace, PR, URL, or concept — into a layered walkthrough. Builds a mental model first (problem framed + best-fit form: diagram, analogy, before/after, or causal narrative — plus structure map), then one chunk at a time on demand. Use when the input is too long to skim, when you've come back to something and lost the thread, or when ramping up on unfamiliar material. |
| productivity | [fwd:handoff](skills/productivity/fwd:handoff/SKILL.md) | Compact the current conversation into a handoff document for another agent to pick up. |
| productivity | [fwd:premortem](skills/productivity/fwd:premortem/SKILL.md) | Stress-test a plan by imagining it has already failed, then list concrete failure modes, grade each on Likelihood × Impact, and ICE-rank candidate mitigations for the meaningful ones. Use when user wants to pre-mortem a plan, asks "what could go wrong", wants to harden a design before commitment, or invokes /fwd:premortem. |
| productivity | [fwd:jip-janneke](skills/productivity/fwd:jip-janneke/SKILL.md) | Rewrites a referenced text into plain, readable language — "jip-en-janneketaal". One pass, chat output only; output is always Dutch unless another language is explicitly requested. Invoke when someone says "maak dit leesbaarder", "schrijf dit in jip-en-janneketaal", "rewrite in plain language", "make this readable", or invokes /fwd:jip-janneke. |

## Adding a skill

1. Create a new folder under `skills/<category>/fwd:<field-or-context>-<name>/` (e.g. `skills/engineering/fwd:git-commit/`).
2. Add a `SKILL.md` file with YAML frontmatter (`name`, `description`) and a markdown body. Bash helpers live in a sibling `scripts/` folder.
3. Register the skill folder path in `.claude-plugin/plugin.json` under `skills`.
4. Update the table above.

See [CLAUDE.md](CLAUDE.md) for repo conventions and [CONTEXT.md](CONTEXT.md) for shared vocabulary.

## Related

- [baswenneker/fwd-claude-code](https://github.com/baswenneker/fwd-claude-code) — full `fwd` workflow plugin (agents, hooks, CLI tooling); these skills are a slimmed-down subset.
- [mattpocock/skills](https://github.com/mattpocock/skills/tree/main) — layout and conventions inspiration.
