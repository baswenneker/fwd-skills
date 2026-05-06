---
name: fwd:plan
description: Plan an implementation — gather codebase context, ask numbered-choice clarifying questions inline, then present three options (minimal / uitgebreid / pragmatisch) with TL;DR + details + a per-plan changes table, closing with a comparative verdict and recommendation. Use when user wants to plan a feature, refactor, or change with multiple options on the table, or invokes /fwd:plan.
argument-hint: <what to plan, or empty to ask>
allowed-tools: Read, Glob, Grep, Bash, WebFetch, WebSearch, Agent
---

# Plan

Walk through a four-step flow: investigate → clarify → present three plans → verdict.

**Hard constraints:**

- **Subagents only when the user explicitly asks.** Default: stay in the main turn — subagents can't ask follow-up questions and they hide context. If the user says "use subagents" / "spawn agents to research X" / similar, `Agent` is allowed for that part. Otherwise, do the work yourself.
- **No `AskUserQuestion`.** Phrase questions inline as plain-text numbered choices and wait for the user's reply.
- **No code changes.** This skill ends with a verdict; implementation is a separate next step.

## Step 1 — Gather context

Read just enough to plan. Tools: `Read`, `Glob`, `Grep`, `Bash` (read-only), `WebFetch`, `WebSearch`.

1. Restate the request in your own words — what is actually being changed?
2. 2–4 targeted Glob/Grep searches around terms in the request.
3. Read 2–4 key files to learn existing patterns (naming, structure, conventions).
4. Skim `CLAUDE.md`, `CONTEXT.md`, any `docs/adr/` ADRs, **and any rule files under `.claude/rules/`** (architecture, structure, conventions, stack, testing, `guidelines-<lang>`). These dictate the conventions every plan must respect — comments, docstrings, typing, naming, testing patterns.
5. If a library/framework is involved, look up current docs (Context7 MCP if available, else WebSearch).

Stay light — enough to plan, not enough to implement.

## Step 2 — Clarifying questions

**Always ask Q1: the Definition of Done (DoD).** Open-ended. Then identify ambiguities, edge cases, scope boundaries, and design choices the request doesn't pin down, and add them as numbered-choice follow-ups.

```
[One short sentence: why you're asking before drafting plans.]

**1. Definition of Done — when is this change "complete"?**
   *(Open answer. Concrete acceptance criteria: which tests pass, which behaviour is observable, which edge cases are handled.)*

**2. [Question — name the ambiguity in one sentence]**
   1. [Option A] — [one-line consequence]
   2. [Option B] — [one-line consequence]
   3. [Option C, if applicable] — [one-line consequence]

**3. [Next question]**
   1. ...
   2. ...
```

Rules:

- **Q1 is always the DoD**, open-ended. Never guess it — the DoD must come from the user. If they skip it, re-ask.
- Then up to 4 numbered-choice questions (2–5 total). Skip any whose answer wouldn't change the plans.
- Each numbered-choice question is numbered; each option inside is numbered. User replies in any clear format ("DoD: …, 2.1, 3.2").
- **Stop after the questions and wait.** Do not proceed to Step 3 until the user answers.
- For the numbered-choice questions: if the user says "you decide" / "geen voorkeur", pick the lowest-risk default and state the assumption.

## Step 3 — Three plans

Design three plans with distinct trade-offs:

- **Minimal** — smallest change. Reuse existing code; no new abstractions. Low risk, tiny diff.
- **Uitgebreid (extensive)** — architecturally ideal. New abstractions where they earn it; clean separation; testable. The "do it properly" version.
- **Pragmatisch (pragmatic)** — middle ground. Invest where it pays off; take shortcuts where the cost is low.

**Per-plan requirements** (apply to all three):

- **Tests.** Every plan must include a test approach — what level (unit / integration / E2E), what's covered, where the files live, and how it satisfies the DoD from Step 2. Test files appear in the Wijzigingen table.
- **Rules from `.claude/rules/`.** Every plan respects the rule files read in Step 1 (comments, docstrings, typing, naming, structure, testing patterns). Don't restate the rules in each plan — note once in the plan's Details that applicable rules from `.claude/rules/` will be applied to every touched file.

Present each plan in this exact shape:

```
## Plan A — Minimal

**TL;DR:** [One sentence: what the plan does and what makes it "minimal".]

**Details:**
- [3–6 concrete bullets: what changes, what's reused, key decisions.]
- **Tests:** [level — unit/integration/E2E — what's covered, where the test files live, how it maps to the DoD]
- **Regels:** Applicable rules from `.claude/rules/` apply to every touched file (per Step 1).

**Wijzigingen:**

| File | Change | Reason |
|------|--------|--------|
| `path/to/feature.ts` | nieuw | [why added] |
| `path/to/other.ts` | gewijzigd | [what changes] |
| `path/to/feature.test.ts` | nieuw | [tests for what behaviour] |
| `path/to/old.ts` | verwijderd | [why removed] |
```

Then `## Plan B — Uitgebreid` and `## Plan C — Pragmatisch` with the same structure.

Rules:

- Use real, existing paths from Step 1. Do not invent files.
- The `Change` column is one of `nieuw` / `gewijzigd` / `verwijderd`.
- Each plan must stand alone — the user can read one plan in isolation and understand it.

## Step 4 — Verdict

Close with a comparative verdict:

```
## Verdict

[2–4 sentences comparing the plans against the user's actual situation: constraints, codebase state, size of change, risk profile.]

**Aanbeveling: Plan [A | B | C]**

[2–4 sentences: *why* this plan fits this request. Tie reasoning to Step 1 findings and Step 2 answers. Name the one trade-off the recommended plan accepts versus the alternatives.]
```

Rules:

- **Pick a winner.** "Depends on your preference" is not a verdict.
- Anchor the recommendation in the user's actual answers and the actual codebase, not in abstract principles.
- If the right answer genuinely depends on something only the user can decide ("are you going to extend this in 6 months?"), name that fork and give a conditional recommendation.

## Style

- Plain language. No filler.
- Match the user's prose language (Dutch / English); keep file paths and code identifiers exact.
- After the verdict, **stop**. Do not implement; wait for the user to say what's next.
