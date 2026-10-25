---
name: next-steps
description: Answers "en nu?" with a short, fixed status block in Dutch — what we are working on, where we stand, the next steps and who does each one — and ends with an offer to start, here or through the autocoder. Looks at the current session only and changes nothing. Invoke when the user asks "en nu?", "ok en nu?", "wat nu?", "wat is de status?", "waar staan we?", "what's next", or invokes /fwd:next-steps; the global next-steps rule from /fwd:setup also has Claude end every turn that finishes a piece of work with this block.
allowed-tools: Read, Bash
---

# Next steps

Tell the user, in a few lines, where the work of this session stands and what
happens next. The user asks "en nu?" because they lost track or want to
decide; the block must let them decide in one reply.

## Scope

- **Current session only.** Use what this conversation did and decided. Do not
  read other sessions, other repos or the Workcenter.
- **Check facts that may have moved.** Before writing "Waar we staan", verify
  what the conversation can no longer prove: `rtk git status` and the current
  branch, `gh pr view` for a PR this session opened, the state of a background
  task it started. Say the checked fact, not your memory of it.
- **Read-only.** The block changes nothing: no commit, no push, no issue, no
  file edit. Starting a step waits for the user's reply.

## Format

Print exactly this shape, in Dutch, with these four bold headings:

```
**Waar we mee bezig zijn**
<one sentence: the goal of this piece of work>

**Waar we staan**
- <done, running or stuck — with the fact that proves it>
- <…>

**Next steps**
1. Ik <step>.
2. Ik <step>.
3. Jij <step>.

Daarna <later steps in one sentence, with who does them>.

<closing line>
```

Rules per part:

- **Waar we staan** — one to three bullets. Each bullet names a fact the user
  can check: "PR #14 gemerged", "branch `feat/x` niet gepusht", "3 van 5 tests
  rood". Something stuck says what blocks it.
- **Next steps** — only the steps that come now, at most five. Each step
  starts with who does it: "Ik …" for Claude, "Jij …" for the user, "Ik …, jij
  …" for a step both take part in. Numbers run on, so the user can answer "doe
  1–2".
- **Daarna** — the steps after that, in one sentence. Leave it out when nothing
  follows.
- **Closing line** — see below.

No emoji, no status icons, no table, no extra headings. Keep the whole block
under ~1.000 characters. When the block ends a longer report, "Waar we staan"
does not repeat that report: one line per open point is enough.

## Closing line

Ends the block with what happens on the user's next reply.

- **Default:** `Zal ik beginnen?` — the user's "ok", "ja" or "doe maar" starts
  the "Ik" steps here, in this session.
- **Work fit for the autocoder** — more than a few lines, bounded, a clear
  done state — offers the autocoder as alternative:

  ```
  Ik begin hier en nu, tenzij je "autocoder", "autocoder nu" of "autocoder vanavond" zegt.
  ```

  On the reply: "autocoder" → run `/autocoder` in this session
  (`workcenter:autocoder`); "autocoder nu" → `workcenter:autocoder-issue`, picked
  up straight away; "autocoder vanavond" → `workcenter:autocoder-issue` for the
  evening run. Any other yes starts the steps here. Leave the autocoder out when
  the `workcenter` plugin is not installed.
- **Only the user can act** (a test, a decision, a merge) → no closing line; the
  "Jij" step says what is needed.
- **Nothing left** → replace the whole block with one line: `Alles is af:
  <fact>. Er staat niets meer open.` Never invent a step to fill the list.

## Example

```
**Waar we mee bezig zijn**
Een nieuwe skill `fwd:next-steps`. Die antwoordt op "en nu?" met een kort overzicht van de status.

**Waar we staan**
- Het ontwerp is afgesproken. De skill kijkt alleen naar de huidige sessie en wijzigt niets.
- Er is nog niets gebouwd. `main` is schoon en er is nog geen branch.

**Next steps**
1. Ik schrijf `SKILL.md` in `skills/productivity/next-steps/`.
2. Ik registreer de skill in `plugin.json` en `README.md`, en verhoog de versie.
3. Ik maak een PR op de branch `feat/next-steps`.

Daarna test jij de skill in een andere sessie met "ok en nu?". Als het goed is, merge ik de PR.

Ik begin hier en nu, tenzij je "autocoder", "autocoder nu" of "autocoder vanavond" zegt.
```
