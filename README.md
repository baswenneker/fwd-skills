# fwd-skills

HeadingFWD's Claude Code skills plugin.

A lightweight, plain-markdown skill registry, structured after [mattpocock/skills](https://github.com/mattpocock/skills/tree/main). Skills are organised by category under `skills/` and registered in `.claude-plugin/plugin.json`. The skills here are extracted standalone from [baswenneker/fwd-claude-code](https://github.com/baswenneker/fwd-claude-code) so they can be installed without the rest of the `fwd` workflow.

## Installation

> Only tested with [Claude Code](https://claude.ai/code).

**Option A — as a Claude Code plugin** (recommended; the only option that includes the `fwd:mission-*` agents):

```bash
claude plugin marketplace add baswenneker/fwd-skills
claude plugin install fwd@headingfwd
```

Installs the skills **and** the bundled subagents (`mission-coder`, `mission-reviewer`, `mission-user-tester` for missions; `steps-reviewer`, `steps-doubt` for steps-runs) that the orchestrator skills spawn as `fwd:*`. Restart Claude Code after installing so the agents register.

**Option B — skills only, via the skills CLI:**

```bash
npx skills@latest add baswenneker/fwd-skills
```

The skills CLI syncs `skills/` only — it does **not** install the `agents/` directory. The interaction/communication skills work fine, but `/fwd:mission-run` and `/fwd:steps-run` will fail to spawn their subagents (`Agent type 'fwd:mission-coder' not found`). Use Option A if you want Missions or Steps.

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

## Steps: one reviewed step at a time, attended or autonomous

The `fwd:steps-*` family is the attended counterpart of missions, for work where you stay at the keyboard. `/fwd:steps-plan` pins a Definition of Done with a concrete "this is what done looks like" anchor, agrees the test seams, and cuts the work into a **step budget**: the first token of the argument (`/fwd:steps-plan 5 <goal>`) sets the number of gate moments — a number means exactly that many steps, `auto` means fine-grained (one demonstrable behavior per step, 1-3 tests, ~5 minutes of review), and the default is 3. A budgeted step bundles several behaviors as indented sub-bullets: red→green per behavior, but report, fresh-eyes review, commit and gate once per step. On a clear mismatch the planner offers a one-sentence counter-proposal — it never silently changes the count. `/fwd:steps-run` then executes exactly one step per turn — per behavior a failing test first and a minimal implementation along ponytail's Lazy Ladder, then a fresh-eyes verdict from a read-only reviewer subagent — and stops with a ±25-line decision-first step report ("Stap 7/20") — open points on top, changes grouped per folder in plain language, section titles above their text — until you approve. Approval is the commit: the git history becomes a log of decisions you actually reviewed. Every 4 approved steps, two caveman-style doubt agents probe what we're least confident about and what's being missed. At the same approval the planner also asks how the run should execute — `ok` for attended, `ok auto` for **autonomous**: every remaining step in one go, same rigor per step (red, green, full gate, fresh reviewer) and its own commit, with a single end report instead of a stop after each step. That choice is stored as `run_mode` and can be overridden per session with `/fwd:steps-run <slug> auto|attended`. An autonomous run breaks back to attended the moment a step gets stuck, a gate stays red, the reviewer FAILs, or a doubt agent has a concrete proposal — it never builds past a problem. Planning creates the worktree up front (`.trees/steps/<slug>/`, just like missions) without ever switching your main checkout, and `/fwd:steps-run` reuses it — so from the moment you plan, your main checkout stays free for parallel work in another terminal. Missions stay the tool for unattended/overnight runs.

## Skills

| Category | Skill | Description |
| --- | --- | --- |
| engineering | [fwd:codex-review-implementation](skills/engineering/codex-review-implementation/SKILL.md) | Adversarial review of the DIFF after implementation, checked against a resolved plan — a /fwd:plan contract, a /fwd:mission-plan mission, or a /fwd:steps-plan steps-plan — delegated to Codex through the codex plugin's rescue runtime. Determines the diff scope automatically (a resolved mission/steps branch's own commits, or the working tree as a fallback), then asks Codex the standard adversarial risk categories plus, when a plan was found, plan-fidelity questions (does the diff satisfy every Definition of Done (DoD)/VC line, did scope silently grow or shrink). Read-only — never edits code or the plan. Use when the user wants a second, adversarial opinion on an implementation before it ships, says "review this diff with Codex", "laat Codex deze implementatie checken", "codex review op deze diff", or invokes /fwd:codex-review-implementation. |
| engineering | [fwd:codex-review-plan](skills/engineering/codex-review-plan/SKILL.md) | Adversarial review of a plan BEFORE any code is written, delegated to Codex through the codex plugin's rescue runtime. Resolves the plan itself — a /fwd:plan contract, a /fwd:mission-plan mission, or a /fwd:steps-plan steps-plan (also accepts a path or pasted plan text) — then has Codex attack it for Definition of Done (DoD) coverage gaps, unobservable evidence lines, stale assumptions, and the classic risk categories (auth, data loss, rollback, races, empty-state, schema drift, observability). Read-only — never edits the plan and never writes code. Use when the user wants a second, adversarial opinion on a plan before building it, says "review this plan with Codex", "laat Codex dit plan checken", "codex review op dit plan", or invokes /fwd:codex-review-plan. |
| engineering | [fwd:git-commit](skills/engineering/git-commit/SKILL.md) | Stage and commit with conventional message — pre-flight scan blocks risky files (.env, logs, keys, secrets, >1MB) |
| engineering | [fwd:mission-plan](skills/engineering/mission-plan/SKILL.md) | Plan a multi-agent "mission" — scope a software goal through conversation, write a PRD plus a validation contract (what "done" means, before any code), decompose into features and milestones, then create the mission branch and persist the plan on it. The interactive half of the fwd:mission-* orchestration layer (modelled on Factory.ai Missions); execution is handled afterwards by /fwd:mission-run. Use when the user wants to plan a larger feature as an orchestrated mission, says "plan a mission", "start a mission", "scope this as a mission", or invokes /fwd:mission-plan. |
| engineering | [fwd:mission-run](skills/engineering/mission-run/SKILL.md) | Execute a planned mission — the resident orchestrator of the fwd:mission-* layer (a Claude Code take on Factory.ai Missions). Reads the mission's state.json, drives features one at a time by spawning a fresh coder subagent each, runs adversarial validators (Scrutiny + User-Testing) at milestone boundaries, and records a checkpoint after every unit so the mission resumes from any worktree or clone. Runs autonomously — never prompts. Use when the user runs /fwd:mission-run <slug>, says "run/execute/resume mission <slug>", or wraps it in /loop for a long multi-day run. Pass `status` as a second argument for a read-only progress report. |
| engineering | [fwd:plan](skills/engineering/plan/SKILL.md) | Plan een implementatie — verzamel codebase-context, presenteer eerst een DoD-voorstel met numbered bullets (akkoord of corrigeer in plain text, géén AskUserQuestion), stel daarna 0-3 verdiepende keuzes via AskUserQuestion, en presenteer 1 of 3 plannen in visueel distincte boxen met spec-strip + TL;DR + Wijzigingen-tabel. Sluit af met (Recommended)-tag op het beste plan en een verdict-block, en legt na de plan-keuze een licht contract vast in `.claude/plan-contracts/<slug>.md`. `/fwd:plan check [<slug>]` toetst achteraf de diff en de DoD-bewijsregels tegen dat contract. Use when user wants to plan a feature, refactor, or change met meerdere opties op tafel, of invokes /fwd:plan. |
| engineering | [fwd:rules-audit](skills/engineering/rules-audit/SKILL.md) | Interactief de `.claude/rules/` directory bootstrappen voor een repo. De skill scant de codebase, stelt regelbestanden voor — elk voorzien van minimaal één golden example (een pad naar een echt, exemplarisch bestand) — en schrijft pas weg na expliciete goedkeuring van de gebruiker. Gebruik bij "rules audit", "bootstrap rules", "stel regels op", "maak claude rules", of als je `/fwd:rules-audit` aanroept. |
| engineering | [fwd:setup](skills/engineering/setup/SKILL.md) | Setup wizard for HeadingFWD's optional Claude Code conventions. Runs unattended — zero prompts, always project-local scope: installs every convention in one batch (smartlint Stop-hook, a lessons memory file, gitignore entries for fwd runtime artefacts, Claude Code's clear-context prompt on plan accept, and disabling Claude Code's default commit/PR attribution) — copying bundled payload files into .claude/hooks/ or .claude/lessons/, merging JSON snippets into .claude/settings.local.json, injecting an instructions section into CLAUDE.md (lessons), or appending a marker-bracketed block to .gitignore. Idempotent and modular — each feature lives in scripts/<feature>/. Prints a fixed-format Dutch summary from the bundled OUTPUT.md template. Runs on Haiku. Use only when the user invokes /fwd:setup explicitly. |
| engineering | [fwd:skill-eval](skills/engineering/skill-eval/SKILL.md) | Black-box self-evaluation for any Claude Code skill. Reads the target SKILL.md, extracts its surface (triggers, CLI flags, input/output formats, documented exit codes, examples), generates ~10 experiments covering happy paths, flag interactions, error paths, and domain invariants, runs each in an isolated workdir under tmp/eval/, and reports pass/fail in a single markdown table. Refuses to run on a dirty working tree. Ends the report with an undo prompt — reply with `x` or `undo` to remove tmp/eval/. Use when the user says "self-evaluate skill X", "shake down skill X", "test skill X end-to-end", "regression-check skill X after my refactor", "does this skill still behave the way SKILL.md claims", or invokes /fwd:skill-eval. |
| engineering | [fwd:steps-plan](skills/engineering/steps-plan/SKILL.md) | Plan een klus als een reeks kleine, toetsbare stappen voor uitvoering met /fwd:steps-run — de lichte tegenhanger van fwd:mission-plan. Scope het doel kort, pin een Definition of Done mét concreet eindbeeld (input→output-voorbeeld of ASCII-mockup), spreek de testplekken (seams) af, en lever een genummerde stappenlijst binnen een stappenbudget — een getal als eerste argument-token = precies zoveel stappen (gate-momenten), `auto` = fijnmazig met één aantoonbaar gedrag per stap, default 3; een stap bundelt dan meerdere gedragingen, elk met een machinaal toetsbaar klaar-criterium. Vraagt bij het akkoord ook de uitvoermodus — attended (jij beslist per stap) of autonoom (alle stappen achter elkaar, commit per stap) — en legt die vast als `run_mode`. Use when the user zegt "plan dit in stappen", "maak een stappenplan", "steps-plan", of invokes /fwd:steps-plan. Niet voor onbeheerd/overnight werk — dat is fwd:mission-plan. |
| engineering | [fwd:steps-run](skills/engineering/steps-run/SKILL.md) | Voer een stappenplan van /fwd:steps-plan uit — attended (precies één stap per beurt) of autonoom (alle stappen achter elkaar, commit per stap), zoals in het plan afgesproken als `run_mode` en per sessie te overrulen met een tweede argument (`auto` / `attended`). Per stap; falende test eerst (rood), minimale implementatie langs de Lazy Ladder (groen), volledige gate, vers oordeel door een read-only reviewer-subagent, en attended een beslis-eerst stap-rapport van ±25 regels met "Stap N/M"-teller (open punten bovenaan, veranderd per map, titels boven de tekst) — daarna stopt de beurt en beslist de gebruiker (ok = commit & door, auto = autonoom afmaken, m = meer detail, stop = pauze, vrije tekst = correctie/vraag/planwijziging). Elke 4 goedgekeurde stappen een tussenbalans door twee doubt-subagents. Use when the user runs /fwd:steps-run <slug>, zegt "volgende stap", "ga door met het stappenplan", "draai <slug> autonoom", of "hervat <slug>". Zonder argument: lijst alle stappenplannen. Niet voor onbeheerd werk — dat is fwd:mission-run. |
| productivity | [fwd:caveman](skills/productivity/caveman/SKILL.md) | Ultra-compressed communication mode. Cuts token usage ~75% by dropping filler, articles, and pleasantries while keeping full technical accuracy. Use when user says "caveman mode", "talk like caveman", "use caveman", "less tokens", "be brief", or invokes /fwd:caveman. |
| productivity | [fwd:explain](skills/productivity/explain/SKILL.md) | Break down anything heavy — a plan, code file, diff, doc, stack trace, PR, URL, or concept — into a layered walkthrough. Builds a mental model first (problem framed + best-fit form: diagram, analogy, before/after, or causal narrative — plus structure map), then one chunk at a time on demand. Use when the input is too long to skim, when you've come back to something and lost the thread, or when ramping up on unfamiliar material. |
| productivity | [fwd:handoff](skills/productivity/handoff/SKILL.md) | Compact the current conversation into a handoff document for another agent to pick up. |
| productivity | [fwd:premortem](skills/productivity/premortem/SKILL.md) | Stress-test a plan by imagining it has already failed, then list concrete failure modes, grade each on Likelihood × Impact, and ICE-rank candidate mitigations for the meaningful ones. Use when user wants to pre-mortem a plan, asks "what could go wrong", wants to harden a design before commitment, or invokes /fwd:premortem. |
| productivity | [fwd:jip-janneke](skills/productivity/jip-janneke/SKILL.md) | Rewrites a referenced text into plain, readable language — "jip-en-janneketaal". One pass, chat output only; output is always Dutch unless another language is explicitly requested. Invoke when someone says "maak dit leesbaarder", "schrijf dit in jip-en-janneketaal", "leg uit in jip janneke", "leg dit uit voor een leek", "rewrite in plain language", "make this readable", or invokes /fwd:jip-janneke. |
| productivity | [fwd:explainer](skills/productivity/explainer/SKILL.md) | Builds a visual HTML explainer of anything heavy — what happened this session, an architecture, an auth or deployment flow, a plan, review findings, a diff — and publishes it as an artifact with a diagram that is verified by actually rendering it. Fixed shape: framing sentence, In 't kort, mermaid diagram of the mechanism, one running concrete example, term list, "wat ik weglaat". Written for a reader who is a layperson on devops and cloud; English terms allowed, each explained at first use. Invoke when someone says "maak een html explainer", "maak een explainer", "html explainer van ...", "visualiseer wat je gedaan hebt", "maak er een uitlegpagina van", or invokes /fwd:explainer. |
| productivity | [fwd:unsure](skills/productivity/unsure/SKILL.md) | Noem de 3 zaken waar je het minst zeker van bent — in een plan, ontwerp, diff, aanpak of in je eigen zojuist gegeven antwoord: wat wankelt, waarom, en wat het zou beslechten. Gebruik deze skill zodra iemand twijfel opvraagt of naar een zwakke plek zoekt: "waar ben je het minst zeker van", "wat is je zwakste aanname", "noem de zwakke punten hier", "hoe zeker ben je hiervan", "what are you least confident about", "poke holes in this", of /fwd:unsure. |

## Adding a skill

1. Create a new folder under `skills/<category>/<field-or-context>-<name>/` (e.g. `skills/engineering/git-commit/`). No `fwd:` prefix — the `/fwd:` in the slash command comes from the plugin name.
2. Add a `SKILL.md` file with YAML frontmatter (`name`, `description`) and a markdown body. Bash helpers live in a sibling `scripts/` folder.
3. Register the skill folder path in `.claude-plugin/plugin.json` under `skills`.
4. Update the table above.

See [CLAUDE.md](CLAUDE.md) for repo conventions and [CONTEXT.md](CONTEXT.md) for shared vocabulary.

## Related

- [baswenneker/fwd-claude-code](https://github.com/baswenneker/fwd-claude-code) — full `fwd` workflow plugin (agents, hooks, CLI tooling); these skills are a slimmed-down subset.
- [mattpocock/skills](https://github.com/mattpocock/skills/tree/main) — layout and conventions inspiration.
