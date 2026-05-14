---
name: fwd:premortem
description: Stress-test a plan by imagining it has already failed, then list concrete failure modes, grade each on Likelihood × Impact, and ICE-rank candidate mitigations for the meaningful ones. Use when user wants to pre-mortem a plan, asks "what could go wrong", wants to harden a design before commitment, or invokes /fwd:premortem.
argument-hint: <file | "pr 123" | URL | empty for most-recent-plan-in-conversation>
allowed-tools: Read, Bash, Glob, Grep, WebFetch
---

# Premortem

Imagine the plan has already shipped and failed 3–6 months from now. Work backwards: what specifically went wrong? Grade each failure, then harden the meaningful ones.

Opposite of `/fwd:plan` and of a postmortem — those *build* or *explain after the fact*; this one *stress-tests before commitment*.

## Step 1 — Resolve the plan

| `$ARGUMENTS` | Loader |
|---|---|
| empty | scan conversation for the most recent plan-like block (numbered phases, `ExitPlanMode` output, "Plan" / "Approach" section > 20 lines) |
| starts with `http(s)://` | `WebFetch` |
| `pr <N>`, `#<N>`, numeric | `gh pr view <N>` |
| path-like (contains `/` or extension) | `Read` |
| anything else | treat as inline plan text |

If nothing resolves: `No plan found. Pass a path, paste the plan, or run /fwd:plan first.` and stop. Otherwise dive in — no confirmation prompts.

## Step 2 — Generate failure modes

Sweep these categories — skip any that don't apply, but consider each:

- **Technical** — wrong abstraction, integration breaks, performance ceiling hit
- **Scope** — requirement missed, edge case ignored, scope creep
- **Assumptions** — something believed but never verified
- **Dependencies** — external service, library, or team blocks us or shifts under us
- **Coordination** — owner unclear, handoff misses, single point of knowledge
- **Operational** — deployment fails, no rollback, monitoring blind spot
- **Security** — data leak, auth gap, compliance miss
- **Schedule** — sequencing wrong, late-discovered blocker, optimistic estimate

Aim for **5–8 distinct, concrete scenarios**. Quality over quantity. Skip near-duplicates of the same root cause. Each failure mode is a *story* of how it plays out — not a category label.

## Step 3 — Grade

*Risk severity only — mitigation cost is scored separately in Step 4.*

For each failure, assign **Likelihood** (L/M/H) and **Impact** (L/M/H). Derive the risk grade from the matrix:

```
            Impact
           L   M   H
Likely  L  Lo  Lo  Md
        M  Lo  Md  Hi
        H  Md  Hi  Hi
```

Be honest. If every failure grades High, re-read with fresh eyes — most real plans land 1–3 Highs, the rest Medium or Low.

## Step 4 — Harden

For each **Medium or High** failure:

- **Early signal** — one line: what would we see if this failure is *starting* to happen? Turns the scenario into something operational.
- 2–4 candidate **mitigations**, each scored on **ICE** (1–10 per axis):
  - **Impact** — how much this mitigation reduces the failure
  - **Confidence** — how confident we are the mitigation actually works
  - **Ease** — how cheap to implement
- ICE = I × C × E (range 1–1000). Mark the highest-scoring mitigation with ★ — that's adopted.
- If even the ★ mitigation scores ICE < 100, drop the mitigation list and mark `accept — <reason>` instead. Don't propose security theatre.

Mitigations must be **concrete** (name the test, check, doc, or scope cut — not "be more careful") and **addressable now** (fit inside the plan's scope).

For Low risks, skip the early signal + mitigations unless the fix is trivial; list them in "Risks we accept".

## Step 5 — Render

```
# Premortem — <plan name or one-line summary>

## Failure modes

### 1. <punchy title> — Risk: High
**Scenario**: <2–3 sentences, past tense — "the deploy hit row-lock contention because…">
**Likelihood**: M  **Impact**: H
**Early signal**: <one line — what we'd see if this is starting to happen>
**Mitigations** (ICE-ranked):
  a) ★ <mitigation a> — ICE 720
  b) <mitigation b> — ICE 480
  c) <mitigation c> — ICE 120

### 2. ...

## Hardened plan — what changes

- <★ mitigation — concrete edit to the plan>
- ...

## Risks we accept

- <Low-risk item left unhardened, with reason>
- ...
```

Keep the whole response under 120 lines. If a failure mode has more depth, surface the headline only — let the user ask for more on a specific one.

## Style

- Plain English, no filler, no emoji.
- Punchy titles: `Auth token leaks into logs` beats `Logging issue`.
- Be specific about *how* it fails, not just *what* fails. Past tense ("we discovered X too late") forces concreteness.
- If the plan is too vague to premortem, say so and name what's missing — don't manufacture failures from thin air.
- Never grade everything High. If you do, you're either pattern-matching on fear or the plan genuinely shouldn't ship — say which.
- ICE scores are judgement, not measurement. If you can't articulate why a mitigation scored 8 vs. 6 on Confidence, use 1 / 5 / 10 buckets instead of granular 1–10.
- If the top mitigation has ICE < 100, you're probably proposing security theatre — say so and `accept` the risk instead.
