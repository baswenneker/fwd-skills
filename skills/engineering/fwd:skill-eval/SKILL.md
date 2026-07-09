---
name: fwd:skill-eval
description: Black-box self-evaluation for any Claude Code skill. Reads the target SKILL.md, extracts its surface (triggers, CLI flags, input/output formats, documented exit codes, examples), generates ~10 experiments covering happy paths, flag interactions, error paths, and domain invariants, runs each in an isolated workdir under tmp/eval/, and reports pass/fail in a single markdown table. Refuses to run on a dirty working tree. Ends the report with an undo prompt — reply with `x` or `undo` to remove tmp/eval/. Use when the user says "self-evaluate skill X", "shake down skill X", "test skill X end-to-end", "regression-check skill X after my refactor", "does this skill still behave the way SKILL.md claims", or invokes /fwd:skill-eval.
context: fork
allowed-tools: Read, Write, Bash, AskUserQuestion, TaskCreate, TaskUpdate, TaskGet, TaskList
argument-hint: <path-to-skill-folder>
---

# fwd:skill-eval

Black-box self-evaluation for Claude Code skills. The target skill is a contract written in `SKILL.md`: every trigger phrase, flag, input format, output format, exit code, and example is a claim that should hold. Build a small experiment matrix that probes those claims, run each experiment in an isolated workdir, report pass/fail.

**Behavioral** evaluation, not unit testing — complements `pytest`, does not replace it.

Skip when:
- The user only wants `pytest` run — call the skill's own test suite directly.
- The target has no behavioral surface (pure prompt-only agent skills) — those need rubric scoring, not pass/fail.
- The user wants one specific scenario verified — just run it; no matrix for n=1.

## Prerequisites

- Target skill folder with a populated `SKILL.md`.
- Runtime deps installable (`uv sync` succeeds, MCP server reachable).
- Clean git working tree — refuses otherwise (exit 5).
- Writable `tmp/eval/` under the skill repo root.
- `CLAUDE_SKILL_DIR` exported (or invoked from inside the harness).

## Workflow

### Phase 0 — Pre-flight

Run the gate before anything else:

```
bash "${CLAUDE_SKILL_DIR}/scripts/preflight.sh" <target-skill-path>
```

- **Exit 5** — dirty tree. Report the message verbatim, stop. Do not proceed.
- **Exit 6** — target path missing or no `SKILL.md`. Report, stop.
- **Exit 0** — `tmp/eval/` reset, target validated → Phase 1.

The dirty-tree refusal is intentional: undo (Phase 6) only catches changes inside `tmp/eval/`; a dirty start makes the post-eval diff ambiguous.

### Phase 1 — Discover (read-only)

1. Read the target's `SKILL.md` frontmatter + body. Extract:
   - **Triggers** — phrases in `description`.
   - **Entry point** — bash script, Python CLI, MCP tool, or agent prompt.
   - **CLI surface** — flags, options, modes, defaults. Python CLI → parse `argparse` from source; otherwise call `--help`.
   - **Input formats** — extensions, directory layouts.
   - **Output formats** — target extensions, append/new/auto modes.
   - **Documented exit codes** — SKILL.md "Exit codes" section or source.
   - **Documented examples** — `Quick start` blocks are the closest thing to a contract.
2. Read `examples/` and `scripts/tests/` if present: reusable sample inputs; domain invariants existing tests already assert (free oracle-check ideas).
3. Output a one-paragraph "skill model" to the user before designing experiments: *what does this skill claim to do, on what inputs, with what outputs, with what failure modes?*

Use the `Explore` subagent when the target is large — surface area only, don't read every file.

### Phase 2 — Design (interactive)

Default matrix: **10 experiments**, roughly:

| Bucket | Count | Probes |
|--------|-------|--------|
| Happy paths | 3–4 | One per (input format × output format) combination |
| Flag/mode interactions | 1–2 | Caps, modes, mutually exclusive flags |
| Error paths | 3–4 | One per documented exit code or error condition |
| Domain invariants | 1–2 | Properties that *must* hold (FK integrity, idempotency, consistency, ordering) |

Per experiment write down: **ID** (`E1..E10`), **Label** (short imperative), **Command** (verbatim), **Expected exit code**, **Oracle check** (SQL query, file inspection, stdout regex), **Pass criterion**.

Register all experiments with `TaskCreate` *before* running — the user sees the matrix and can redirect.

### Phase 3 — Execute (one experiment at a time)

1. `tmp/eval/eN/` per experiment. No shared workdirs unless append-mode is explicitly under test.
2. Stage custom fixtures (mismatched-schema CSVs, oversized inputs, …) into the workdir.
3. Run with `2>&1; echo "---EXIT: $?---"` — stdout, stderr, and exit code all captured.
4. Set `CLAUDE_SKILL_DIR` explicitly when running outside the harness.
5. Task `in_progress` before starting, `completed` after verification — never batch.
6. No next experiment until verification (Phase 4) is done — root-cause failures while context is fresh.

### Phase 4 — Verify (per experiment)

Run the oracle check. Common shapes:

- **SQLite output**: `sqlite3 out.db` heredoc — row counts, FK integrity (`COUNT(*) WHERE child_fk NOT IN (SELECT id FROM parent)` = 0), column invariants.
- **XLSX output**: `openpyxl` inside the skill's `uv` venv — sheet names, freeze panes, header rows, sample rows.
- **Error paths**: exit code matches the documented value; stderr contains the documented message.
- **Domain invariants**: build a fixture where the property is *non-trivial* — e.g. for "same input → same fake", put the same value in two tables/columns, SQL-join the result, verify the mapping is consistent.

Failed verification is a finding — record it, never paper over it. Skill behaves differently than documented → the documentation or the skill is wrong; either way the user needs to know.

### Phase 5 — Report

Single markdown response, four parts:

1. **Results table** — one row per experiment:

   | # | Experiment | Input | Output | Expected | Result |
   |---|---|---|---|---|---|

2. **Highlights** — bullets with non-obvious findings (e.g. "PII consistency holds cross-table", "append-mode IDs continue from MAX(id)+1 as documented").

3. **Not tested** — edge cases deliberately skipped (cyclic FKs, missing deps, network outages).

4. **Undo block** — always end with exactly:

   ```
   ---
   **Undo:** Reply with `x` or `undo` to remove `tmp/eval/`. Diffs outside the sandbox will be surfaced separately.
   ```

Keep it scannable — green/red visible in 30 seconds.

### Phase 6 — Undo (next-turn)

Next user message is `x`, `undo`, `revert`, `clean up`, or an obvious equivalent → run:

```
bash "${CLAUDE_SKILL_DIR}/scripts/cleanup.sh"
```

Echo the script's output verbatim — it lists what was removed and surfaces any other diffs (`git status --porcelain`) the eval couldn't clean up.

Anything else → the eval is done; respond normally, do **not** prompt again.

## Conventions

- **Workdir**: always `tmp/eval/eN/` under the skill repo root; reset by `preflight.sh`.
- **Naming**: IDs `E1..E10` in run order; TaskCreate subjects start with `E<N>:`.
- **Isolation**: fresh workdir per experiment unless it explicitly tests stateful behavior (append-mode, idempotency).
- **Capture**: every command ends with `2>&1; echo "---EXIT: $?---"`.
- **TaskCreate first**: register the full matrix before running — the user can redirect before you burn time.
- **No mocks**: oracle checks read the actual artifacts (SQLite, XLSX, JSON, …). Don't trust stdout summaries — verify the file.
- **Git via rtk**: every git invocation routes through `rtk git ...` per repo policy.

## Limits and caveats

- **Black-box only.** Does not run `pytest`; ship unit tests → run them separately.
- **External services.** HTTP APIs, MCP servers, paid LLM calls need credentials up-front. Unreachable → "skipped", never "failed".
- **Judgment-heavy invariants.** The default matrix covers structural invariants (exit codes, row counts, FK integrity). Deeper ones ("values look plausible", "the explanation is correct") need a rubric or a human eye — flag in "Not tested", don't fake-pass.
- **10 is a default, not a ceiling.** Complex skills may want 20+; trivial converters 5. Adapt to surface area.
- **Side effects outside sandbox.** Cleanup only removes `tmp/eval/`. Target writes elsewhere (real git commits) → `cleanup.sh` surfaces them via `git status --porcelain` for manual revert.
- **Don't grade on a curve.** Five experiments green is fine; skipping error paths because they're inconvenient is not — call out the gap.

## Exit codes

| Code | Meaning |
|---|---|
| 0 | All experiments executed (pass/fail visible in the table) |
| 5 | Working tree dirty — refused to start |
| 6 | Target skill path or `SKILL.md` missing |
| 7 | Cleanup script failed |
