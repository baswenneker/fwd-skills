---
name: fwd:skill-eval
description: Black-box self-evaluation for any Claude Code skill. Reads the target SKILL.md, extracts its surface (triggers, CLI flags, input/output formats, documented exit codes, examples), generates ~10 experiments covering happy paths, flag interactions, error paths, and domain invariants, runs each in an isolated workdir under tmp/eval/, and reports pass/fail in a single markdown table. Refuses to run on a dirty working tree. Ends the report with an undo prompt — reply with `x` or `undo` to remove tmp/eval/. Use when the user says "self-evaluate skill X", "shake down skill X", "test skill X end-to-end", "regression-check skill X after my refactor", "does this skill still behave the way SKILL.md claims", or invokes /fwd:skill-eval.
context: fork
allowed-tools: Read, Write, Bash, AskUserQuestion, TaskCreate, TaskUpdate, TaskGet, TaskList
argument-hint: <path-to-skill-folder>
---

# fwd:skill-eval

Black-box self-evaluation for Claude Code skills. Treats the target skill as a contract written in `SKILL.md`: every trigger phrase, flag, input format, output format, exit code, and example is a claim that should hold. Builds a small experiment matrix that probes those claims, runs each experiment in an isolated workdir, and reports pass/fail.

This is **behavioral** evaluation, not unit testing — it complements `pytest`, it does not replace it.

## When to use

Triggers:
- "self-evaluate skill X" / "shake down skill X" / "test skill X end-to-end"
- "does this skill still work?" / "does it behave the way SKILL.md claims?"
- "regression-check skill X after my refactor"
- "give me demo-ready evidence that skill X works"
- Reviewing a skill before publishing it to `fwd-skills` or another registry
- User invokes `/fwd:skill-eval`

Skip when:
- The user only wants `pytest` run — call the skill's own test suite directly.
- The target skill has no behavioral surface (pure prompt-only agent skills) — those need rubric scoring, not pass/fail.
- The user wants a single specific scenario verified — just run it; don't build a matrix for n=1.

## Prerequisites

- A target skill folder containing a populated `SKILL.md`.
- The skill's runtime deps are installable (e.g. `uv sync` succeeds, MCP server is reachable).
- A clean git working tree — the skill refuses to run otherwise (exit 5).
- A writable `tmp/eval/` directory under the skill repo root.
- `CLAUDE_SKILL_DIR` exported (or the skill is invoked from inside the harness).

## Workflow

### Phase 0 — Pre-flight

Run the pre-flight gate before anything else:

```
bash "${CLAUDE_SKILL_DIR}/scripts/preflight.sh" <target-skill-path>
```

Behavior:
- **Exit 5** — working tree is dirty. Report the message verbatim and stop. Do not proceed.
- **Exit 6** — target skill path missing or has no `SKILL.md`. Report and stop.
- **Exit 0** — `tmp/eval/` is reset, target validated. Continue to Phase 1.

The dirty-tree refusal is intentional: undo (Phase 6) only catches changes inside `tmp/eval/`. A dirty start would make the post-eval diff ambiguous.

### Phase 1 — Discover (read-only)

1. Read the target's `SKILL.md` frontmatter + body. Extract:
   - **Triggers** — phrases listed in `description`.
   - **Entry point** — bash script, Python CLI, MCP tool, or agent prompt.
   - **CLI surface** — flags, options, modes, defaults. Parse `argparse` from the source if it's a Python CLI; otherwise call `--help`.
   - **Input formats** — file extensions, directory layouts.
   - **Output formats** — target extensions, append/new/auto modes.
   - **Documented exit codes** — from the SKILL.md "Exit codes" section or source.
   - **Documented examples** — `Quick start` blocks are the closest thing to a contract.

2. Read `examples/` and `scripts/tests/` if present:
   - Sample inputs you can reuse.
   - Domain invariants the existing tests already assert (free oracle-check ideas).

3. Output a one-paragraph "skill model" to the user before designing experiments. It should answer: *what does this skill claim to do, on what inputs, with what outputs, with what failure modes?*

Use the `Explore` subagent if the target is large. Don't read every file — surface area only.

### Phase 2 — Design (interactive)

Default matrix size: **10 experiments**, distributed roughly:

| Bucket | Count | Probes |
|--------|-------|--------|
| Happy paths | 3–4 | One per (input format × output format) combination |
| Flag/mode interactions | 1–2 | Caps, modes, mutually exclusive flags |
| Error paths | 3–4 | One per documented exit code or error condition |
| Domain invariants | 1–2 | Properties that *must* hold (FK integrity, idempotency, consistency, ordering) |

For each experiment, write down:
- **ID** — `E1..E10`.
- **Label** — short imperative title.
- **Command** — verbatim invocation.
- **Expected exit code**.
- **Oracle check** — the verification step (SQL query, file inspection, stdout regex).
- **Pass criterion** — what makes the result green.

Register all experiments with `TaskCreate` *before* running, so the user can see the matrix and redirect if needed.

### Phase 3 — Execute (one experiment at a time)

1. Create `tmp/eval/eN/` per experiment. Don't share workdirs across experiments unless append-mode is explicitly being tested.
2. Stage any custom fixtures (CSV files with mismatched schemas, oversized inputs, etc.) into the workdir.
3. Run the command with `2>&1; echo "---EXIT: $?---"` so stdout, stderr, and the exit code are all captured.
4. Set `CLAUDE_SKILL_DIR` explicitly when running outside the harness.
5. Mark the task `in_progress` before starting and `completed` after verification — never batch.
6. Don't proceed to the next experiment until verification (Phase 4) is done. Easier to root-cause failures while context is fresh.

### Phase 4 — Verify (per experiment)

Run the oracle check. Common shapes:

- **SQLite output**: `sqlite3 out.db` with a heredoc — assert row counts, FK integrity (`COUNT(*) WHERE child_fk NOT IN (SELECT id FROM parent)` should be 0), column-level invariants.
- **XLSX output**: load with `openpyxl` inside the skill's `uv` venv. Inspect sheet names, freeze panes, header rows, sample rows.
- **Error paths**: assert exit code matches the documented value; assert stderr contains the documented error message.
- **Domain invariants**: build a fixture where the property is *non-trivial* — e.g., when testing "same input → same fake", craft input where the same value appears in two tables/columns, then SQL-join the result and verify the mapping is consistent.

Failed verification is a finding — record it, do not paper over it. If the skill behaves differently than documented, the documentation or the skill is wrong; either way the user needs to know.

### Phase 5 — Report

Single markdown response, four parts:

1. **Results table** — one row per experiment:

   | # | Experiment | Input | Output | Expected | Result |
   |---|---|---|---|---|---|

2. **Highlights** — bullet list of non-obvious findings (e.g., "PII consistency holds cross-table", "skip strategy preserves verbatim", "append-mode IDs continue from MAX(id)+1 as documented").

3. **Not tested** — short list of edge cases deliberately skipped (cyclic FKs, missing deps, network outages).

4. **Undo block** — always end with this exact block:

   ```
   ---
   **Undo:** Reply with `x` or `undo` to remove `tmp/eval/`. Diffs outside the sandbox will be surfaced separately.
   ```

Keep the report scannable. Reader should see green/red in 30 seconds.

### Phase 6 — Undo (next-turn)

If the user's next message is `x`, `undo`, `revert`, `clean up`, or any obvious equivalent, run:

```
bash "${CLAUDE_SKILL_DIR}/scripts/cleanup.sh"
```

Then echo the script's output verbatim — it lists what was removed and surfaces any other diffs (`git status --porcelain`) that the eval skill couldn't clean up.

If the user's next message is something else, treat the eval as done and respond normally — do **not** prompt again.

## Conventions

- **Workdir**: always `tmp/eval/eN/` under the skill repo root. Reset by `preflight.sh` at start.
- **Naming**: experiment IDs `E1..E10` in run order; TaskCreate subjects start with `E<N>:`.
- **Isolation**: one fresh workdir per experiment unless an experiment explicitly tests stateful behavior (append-mode, idempotency).
- **Capture**: every command call ends with `2>&1; echo "---EXIT: $?---"`.
- **TaskCreate first**: register the full matrix before running. Lets the user redirect before you burn time.
- **No mocks**: oracle checks read the actual artifacts (SQLite, XLSX, JSON, etc.). Don't trust stdout summaries — verify the file.
- **Git via rtk**: every git invocation routes through `rtk git ...` per repo policy.

## Limits and caveats

- **Black-box only.** Does not run `pytest`. If the target ships unit tests, run them separately.
- **External services.** Skills that need HTTP APIs, MCP servers, or paid LLM calls need credentials provisioned up-front. Mark unreachable cases as "skipped" rather than "failed".
- **Judgment-heavy invariants.** The default matrix covers structural invariants (exit codes, row counts, FK integrity). Deeper invariants ("anonymized values look plausible", "the explanation is correct") need a rubric or a human eye — flag them in "Not tested", don't fake-pass them.
- **10 is a default, not a ceiling.** Complex skills may want 20+; trivial converters may want 5. Adapt to surface area.
- **Side effects outside sandbox.** Cleanup only removes `tmp/eval/`. If the target skill writes elsewhere (e.g. real git commits), `cleanup.sh` surfaces those via `git status --porcelain` so you can revert manually.
- **Don't grade on a curve.** Five experiments green is fine. Skipping error paths because they're inconvenient is not — call out the gap.

## Exit codes

| Code | Meaning |
|---|---|
| 0 | All experiments executed (pass/fail visible in the table) |
| 5 | Working tree dirty — refused to start |
| 6 | Target skill path or `SKILL.md` missing |
| 7 | Cleanup script failed |

## Output format example

```markdown
## Results

| # | Experiment | Input | Output | Expected | Result |
|---|---|---|---|---|---|
| 1 | Excel → SQLite (baseline) | `example_data.xlsx` | `.sqlite` | success, 0 orphans | ✅ 50/201/583 rows, 0 orphans |
| 2 | Excel → XLSX | `example_data.xlsx` | `.xlsx` | 3 sheets, frozen header | ✅ topo order, freeze A2 |
| ... | ... | ... | ... | ... | ... |
| 10 | xlsx output already exists | `.xlsx` on existing `.xlsx` | `.xlsx` | exit 2 | ✅ exit 2 |

## Highlights

- PII mapping is run-scoped and cross-table: identical inputs in different tables map to identical fakes.
- Skip-strategy preserved: `note` and `datum` columns untouched as configured.
- Pre-flight validation catches all 4 invalid-input cases with exit code 2 — no half-written output files.

## Not tested

- Cyclic / composite FK detection (exit 3)
- Schema-mismatch on append (exit 2 path B)
- Missing `uv` or spaCy model (exit 4)
- Tabel name > 31 chars for xlsx output

---
**Undo:** Reply with `x` or `undo` to remove `tmp/eval/`. Diffs outside the sandbox will be surfaced separately.
```

## Reference

- Worked example: a 10-experiment run on the `syntherklaas` skill that exercised three datasets (xlsx, csv-dir, custom 2-table CSV) and uncovered PII-consistency behavior across tables.
- Pattern source: this skill grew out of an ad-hoc self-eval session — the workflow above is the cleaned-up version of what worked there.
