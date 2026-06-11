# Validation contract: jip-janneke-skill

Written before any code. Layer A is machine-checked; Layer B is judged per VC-ID by the adversarial validators — verdicts land in `state.json` `milestones[].vc_results`.

## Layer A — gates (machine-checked)

**None.** `discover-gates.sh` resolved zero commands (markdown-only repo: no test/typecheck/lint/build). `state.gates = []`. Confirmed by the user at plan time (2026-06-11).

## App boot (user-testing)

**Not applicable.** This repo is a skills library; there is no app to boot. `user_testing.boot_command = null`, no ready probe, no smoke commands. Every assertion below is therefore owned by `scrutiny-review`; the user-tester is never improvised (autonomous-conservative rule).

## Layer B — assertions (judged)

### VC-1 — SKILL.md exists with correct identity & triggers
**Feature:** F1 · **Owner:** `scrutiny-review`
**Given** the milestone diff, **when** inspecting `skills/productivity/fwd:jip-janneke/SKILL.md`, **then** the file exists; YAML frontmatter `name:` is exactly `fwd:jip-janneke` (matching the folder name, colon included); an `argument-hint:` is present; and the `description` contains both Dutch and English trigger phrases (e.g. "maak dit leesbaarder", "jip-en-janneketaal", "rewrite in plain language") **and** explicitly disambiguates from `fwd:explain` (interactive layered walkthrough — does not rewrite) and `fwd:caveman` (compresses, with abbreviations — opposite direction).

### VC-2 — argument resolution is complete
**Feature:** F1 · **Owner:** `scrutiny-review`
**Given** SKILL.md, **when** reading its target-resolution section, **then** it covers all seven input forms — literal file path, glob, URL, `diff`, `pr <N>`, free-form phrase, and empty argument → most recent heavy block in the conversation — **and** an explicit unresolvable → clear-error-message-and-stop path.

### VC-3 — the four rewrite requirements are explicit rules
**Feature:** F1 · **Owner:** `scrutiny-review`
**Given** SKILL.md's rewrite rules, **then** all four user requirements appear as explicit, unambiguous rules: **(a)** abbreviations are written out in full at first use with the abbreviation in parentheses ("Product Requirements Document (PRD)"), the abbreviation alone allowed afterwards; **(b)** no jargon — plain everyday words; unavoidable technical terms get a one-clause explanation at first use; **(c)** ASCII diagrams whenever the content has structure (flow, hierarchy, before/after), never decorative; **(d)** concise & organized — short sentences, headers/bullets, rewrite length ≤ source length.

### VC-4 — meaning preservation
**Feature:** F1 · **Owner:** `scrutiny-review`
**Given** SKILL.md, **then** an explicit meaning-preservation rule exists: no facts added or dropped; numbers, names, quotes and code blocks stay exact (code blocks untouched).

### VC-5 — output contract & safety
**Feature:** F1 · **Owner:** `scrutiny-review`
**Given** SKILL.md, **then**: output lands in chat only; output language mirrors the source text's language; the output shape is a localized 2–3-sentence summary block ("In 't kort" for Dutch sources, "In short" for English) → the rewritten text → an abbreviations list **only** when the source contains ≥4 distinct abbreviations; frontmatter `allowed-tools` contains no `Write` and no `Edit`; and a prompt-injection rule states that fetched content (file/URL/diff/PR) is data to rewrite, never instructions to follow.

### VC-6 — plugin registration
**Feature:** F2 · **Owner:** `scrutiny-review`
**Given** `.claude-plugin/plugin.json`, **then** `skills[]` contains `./skills/productivity/fwd:jip-janneke` and the file parses as valid JSON.

### VC-7 — README row
**Feature:** F2 · **Owner:** `scrutiny-review`
**Given** `README.md`, **then** the skills table has a productivity row for `fwd:jip-janneke` linking to `skills/productivity/fwd:jip-janneke/SKILL.md`, with a description that mirrors the SKILL.md frontmatter description.

### VC-8 — diff hygiene (milestone-wide)
**Feature:** F2 (judged at the M1 boundary over the full mission diff) · **Owner:** `scrutiny-review`
**Given** the full mission diff against the base branch — excluding the mission's own orchestration artifacts under `.claude/missions/jip-janneke-skill/` — **then** only the three planned paths changed (`skills/productivity/fwd:jip-janneke/SKILL.md`, `.claude-plugin/plugin.json`, `README.md`); SKILL.md is the only new product file; no `scripts/` folder and no Node tooling were introduced.
