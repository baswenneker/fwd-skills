---
name: fwd:explain
description: Break down anything heavy — a plan, code file, diff, doc, stack trace, PR, URL, or concept — into a layered walkthrough. Big picture first (TL;DR + ASCII diagram + structure tree), then one chunk at a time on demand. Use when the input is too long to skim, when you've come back to something and lost the thread, or when ramping up on unfamiliar material.
argument-hint: <file | glob | "diff" | "pr 123" | URL | phrase | empty for most-recent-in-conversation>
allowed-tools: Read, Bash, Glob, Grep, WebFetch
---

# Explain

Take anything heavy and unfold it on demand: a one-screen overview first, then one chunk at a time when the user asks. The chunk shape changes per input type (phases for a plan, sections for a code file, files for a diff) — the layered structure stays the same.

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

- **TL;DR** — 2 sentences, what + why. Plain language, no jargon dump.
- **Core concept** — the one idea that drives the diagram. (Plan: *"three-layer cascade"*. Diff: *"moves auth out of middleware"*. Code: *"event-loop dispatcher"*. Stack: *"null deref in callback chain"*.)

Do **not** write any of this to the user yet. Hold it for Step 3.

## Step 3 — Render Layer 1 (Big Picture). Stop after.

Output four blocks, in order. Whole response under 40 lines.

**A. TL;DR** — 2 sentences max.

**B. Diagram** — ASCII art of the core concept. Pick the pattern that fits the content:

- Layer cascade (priority chain, fallbacks)
- Before / after (migration, refactor)
- Sequence (linear flow, request lifecycle)
- Tree (hierarchical decomposition)
- Box-and-arrow (data flow, call graph)
- Timeline (events, stack frames)

8–15 lines max. Use `┌─┐│└─┘` for boxes, `→ ↓ ─→` for arrows. No decoration. If a diagram won't add clarity, skip B and say `no diagram — <reason>` instead of forcing one.

**C. Structure tree** — one numbered line per chunk, prefixed with the noun:

```
1. Phase: <name>          (<N> files)
2. Phase: <name>          (<N> files)
...
```

(For diff: `1. File: <path>          (+12 −3)`. For code: `1. Section: <name>          (<N> defs)`. Same shape, different noun.)

**D. Menu** — verbatim:

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
- Diagrams must aid clarity. If a diagram doesn't help, skip it.
- Never dump the original verbatim unless the user asks for `full`.
- If the source already contains a useful ASCII diagram, re-use it (don't reinvent good art); otherwise draw your own.
- Match depth to context — if the user clearly knows the domain, skip the basics.
