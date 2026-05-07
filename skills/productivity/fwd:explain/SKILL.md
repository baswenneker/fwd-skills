---
name: fwd:explain
description: Break down anything heavy — a plan, code file, diff, doc, stack trace, PR, URL, or concept — into a layered walkthrough. Builds a mental model first (problem framed + best-fit form: diagram, analogy, before/after, or causal narrative — plus structure map), then one chunk at a time on demand. Use when the input is too long to skim, when you've come back to something and lost the thread, or when ramping up on unfamiliar material.
argument-hint: <file | glob | "diff" | "pr 123" | URL | phrase | empty for most-recent-in-conversation>
allowed-tools: Read, Bash, Glob, Grep, WebFetch
---

# Explain

Take anything heavy and build a mental model on demand: a one-screen frame (problem + mental model + map) first, then one chunk at a time when the user asks. The mental-model form adapts to the content; mechanical chunking does not replace pedagogical scaffolding. The chunk shape changes per input type (phases for a plan, sections for a code file, files for a diff) — the layered structure stays the same.

Opposite of `/fwd:plan` and `/fwd:write-doc` — those *create*, this one *explains*.

## Step 1 — Resolve the target

**Never prompt for confirmation — just dive in.** If you grabbed the wrong target the user will tell you.

Detect the input type from `$ARGUMENTS`. Order matters — first match wins:

| `$ARGUMENTS` form | Detected as | Loader |
|---|---|---|
| empty | most recent explainable block in conversation | scan context (see below) |
| starts with `http://` or `https://` | URL | `WebFetch` (or `gh pr view <N>` if it's a GitHub PR/issue URL) |
| `pr <N>`, `#<N>`, or numeric only | GitHub PR or issue | `gh pr view <N>` then `gh issue view <N>` |
| `diff`, `HEAD~N`, `<branch>...<branch>`, or starts with `git ` | git diff | run the implied `git diff …` |
| contains `*`, `?`, `[`, `{` | glob | `Glob` |
| contains `/` or starts with `.`, `~`, `/` | literal path | `Read` |
| bare filename with extension | repo-wide search | `find . -type f -name "<NAME>" -not -path '*/node_modules/*' -not -path '*/.git/*' -not -path '*/.claude/*' -print0 \| xargs -0 ls -t 2>/dev/null \| head -1` (newest mtime wins) |
| multi-line text containing `at .* (.*:\d+)` style frames | stack trace | take inline |
| anything else (free-form phrase) | concept search in this codebase | `Grep` for keywords, read top 3 hits |

If nothing resolves: `Couldn't resolve <arg>. Pass a path, glob, "diff", URL, "pr <N>", or paste the content.` and stop.

### Empty `$ARGUMENTS` — find the freshest thing in conversation

Scan the conversation for the most recent **explainable block**. Definition: any of —

- An `ExitPlanMode` tool call's `plan` parameter
- A pasted markdown / code / log block in a user message, length > 30 lines
- A long assistant message containing structural markers (`## `, `Phase \d+`, code fences, etc.), length > 30 lines

Pick most-recent by message order. Tie-break inside one message: longest qualifying block wins. No type preference, no confirmation.

If nothing meets the bar: `Nothing to explain in this conversation. Pass a target.` and stop.

## Step 2 — Classify and parse (silent)

Once content is loaded, classify it. The class picks the chunk model:

| Class | Chunk noun | What to extract per chunk |
|---|---|---|
| Plan | Phase | name, one-sentence goal, file count, files (path + note), verification |
| Code | Section | top-level defs (function, class, export), one-line purpose, key deps |
| Diff | File | per file: what changed, why (best guess), risk surface |
| Doc | Section | h2/h3 outline; one-sentence summary per section |
| Stack | Frame | user-code frames (skip framework noise); root-cause guess |
| Concept | Reference | top files/symbols matching the phrase; one-line role per item |
| Other | Section | structural split (headers, blank lines); 5–8 chunks |

**Always extract, regardless of class:**

- **The Question** — what problem does this solve, or what question does it answer? 1 sentence, plain language. Frame the *problem*, not the artifact. ("How do I run code outside React's render cycle without breaking it?" beats "What does useEffect do?")
- **Mental Model** — the bridge that lets a reader hold this in their head. Pick the form that lands hardest:
  - Concrete + structural (architecture, flow, request lifecycle) → ASCII diagram
  - Abstract concept (hook, principle, design pattern) → analogy ("Think of it as X")
  - Migration / diff / refactor → contrast (before → after)
  - Bug / stack trace → causal narrative (X → Y → crash)
  - Nothing fits → first principles (1–2 sentences capturing the essence)
- **Not** *(optional)* — what this is NOT, to sharpen boundaries. Only include when the line is naturally sharp (often: concepts, APIs). Skip if forced.

Do **not** write any of this to the user yet. Hold it for Step 3.

## Step 3 — Render Layer 1 (Big Picture). Stop after.

Output five blocks, in order. Whole response under 40 lines.

**A. The Question** — 1 line. Frame the *problem*, not the artifact. Plain language, no jargon dump.

**B. Mental Model** — pick the form that lands hardest for this content. Free judgment, no rigid table — let the heuristics from Step 2 guide you:

- *Diagram* — for concrete, structural content (flow, layers, call graph). 8–15 lines max, `┌─┐│└─┘ → ↓ ─→`, no decoration. Patterns that fit well: layer cascade, before/after, sequence, tree, box-and-arrow, timeline.
- *Analogy* — for abstract concepts. 2–4 lines, "Think of it as X" — bridge to a familiar domain.
- *Before/after* — for migrations / diffs / refactors. 2–4 lines, old shape → new shape.
- *Causal narrative* — for bugs / stack traces. 2–4 lines, X → Y → crash.
- *First principles* — for content that none of the above fit. 1–2 sentences capturing the essence.

If no form lands, write `no model added — <reason>` and move on. If the source already contains a useful diagram, re-use it instead of inventing one.

**C. Not** *(optional)* — 1–2 lines, only if the boundary is naturally sharp. Skip silently if forced — never invent contrast to fill the slot.

**D. Map** — one numbered line per chunk, prefixed with the noun:

```
1. Phase: <name>          (<N> files)
2. Phase: <name>          (<N> files)
...
```

(For diff: `1. File: <path>          (+12 −3)`. For code: `1. Section: <name>          (<N> defs)`. Same shape, different noun.)

**E. Menu** — verbatim:

```
Reply with:
  next        → walk through chunk 1
  <#>         → jump to that chunk
  more        → expanded structured detail for current chunk
  full        → verbatim text for current chunk
  done        → wrap up
```

Stop. Do not preview chunk 1.

## Step 4 — Layer 2 (one chunk per follow-up)

When the user replies `next`, `<#>`, `back`, or a chunk name, render that chunk only:

```
## <Noun> <N> — <name>      [<N>/<total>]

Goal: <one sentence>

<mini-diagram if the chunk has structure; skip otherwise>

Top items (top 5; reply "more" for all):
  <action>: <thing> — <note>
  ...

<Verification | Notes | Key insight>: <one line per item, or "none">

next | back | <#> | more | full | done
```

Under 25 lines. If item count > 5, show 5 and note that `more` reveals the rest. The `[<N>/<total>]` footer lets you re-orient if context gets tight.

## Step 5 — Layer 3 (on-demand)

- `more` → expanded structured detail for the current chunk, no truncation. (Plan: full file table. Code: full bodies. Diff: full hunks. Doc: full section text. Stack: full frame context.)
- `full`  → verbatim quote of the current chunk from the original source, in a fenced block.
- `back`  → re-render the previous chunk.
- `done`  → 3-line wrap-up: chunks covered, chunks skipped, suggested next move.

## Style rules

- Plain English. No filler ("Let's", "Now we will", "Great question"). Direct.
- No emoji.
- Bullets and one-liners over paragraphs.
- Mental Model is not always a diagram. Pick analogy, contrast, narrative, or first principles when those land harder. Diagrams are one of five forms, not the default.
- Contrast ("Not") is opt-in. Only include when the boundary is naturally sharp — never invent contrast.
- The Question frames the *problem*, not the artifact. "What does useEffect do?" is weak; "How do I run code outside React's render cycle without breaking it?" is the right shape.
- Never dump the original verbatim unless the user asks for `full`.
- If the source already contains a useful diagram, re-use it (don't reinvent good art); otherwise draw your own when a diagram is the right form.
- Match depth to context — if the user clearly knows the domain, skip the basics.
