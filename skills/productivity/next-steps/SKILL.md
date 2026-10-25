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

- [PR #<n>](<url>): <one sentence: what it changes>
- [Issue #<n>](<url>): <one sentence: what it asks>

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

- **Waar we mee bezig zijn** — the goal sentence, then one bullet for every PR
  and issue the block names anywhere: the number as a markdown link to its URL
  (`[PR #15](https://…/pull/15)`, never the bare URL) and one sentence on what it
  is. Elsewhere in the block a number stands alone ("PR #15 is gemerged"),
  without explaining it again. No PR or issue named → no list.
- **Waar we staan** — one to three bullets. Each bullet names a fact the user
  can check: "PR #14 is gemerged", "branch `feat/x` niet gepusht", "3 van 5 tests
  rood". Something stuck says what blocks it.
- **Next steps** — only the steps that come now, at most five. Each step
  starts with who does it: "Ik …" for Claude, "Jij …" for the user, "Ik …, jij
  …" for a step both take part in. Numbers run on, so the user can answer "doe
  1–2".
- **Daarna** — the steps after that, in one sentence. Leave it out when nothing
  follows.
- **Closing line** — see below.

## Who does a step

- **Ik first.** A step Claude can do with its own tools is an "Ik" step — also
  when it runs on another machine over `ssh` (`ssh workcenter '<command>'`) or
  outside the repo. Look up the real command before handing it over: `<tool>
  --help`, the installed version, the configured source.
- **Jij only for what Claude cannot do:** restart Claude Code, open a new
  session, a decision, a merge the user wants to do themselves, a login, judging
  the result.
- **Every "Jij" step says how.** Under the step, indented:
  - where it happens: the Mac terminal, the Workcenter (`ssh workcenter`), or
    this Claude Code session with the `!` prefix (`! <command>` runs it here, so
    the output lands in the conversation);
  - the exact commands or keystrokes in a code block, ready to copy, with real
    names and paths — never a placeholder the user has to fill in;
  - what the user sees when it worked: a version number, a line in a file, a
    block at the end of a reply.

  For a test, give the exact message to type and what the answer must contain.

No emoji, no status icons, no table, no extra headings. Keep the whole block
under ~1.500 characters; the how-to under a "Jij" step is what may use the room. When the block ends a longer report, "Waar we staan"
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

## Examples

Claude does the work, the user only decides:

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

The user has a step left, with the how-to under it:

````
**Waar we mee bezig zijn**
De regel die het next-steps-blok vanzelf toont, op de Mac en de Workcenter.

- [PR #15](https://github.com/baswenneker/fwd-skills/pull/15): voegt `fwd:next-steps` toe, plus de regel die `fwd:setup` in `~/.claude/CLAUDE.md` zet.

**Waar we staan**
- PR #15 is gemerged; `main` staat op versie 1.2.0.
- De Workcenter draait nog plugin 1.1.0; de regel staat nergens in `~/.claude/CLAUDE.md`.

**Next steps**
1. Ik werk de plugin bij en zet de regel in `~/.claude/CLAUDE.md`, op de Mac en via `ssh workcenter`.
2. Jij herstart Claude Code en test of het blok vanzelf komt.
   - Waar: een nieuwe Claude Code-sessie in deze repo.
   - Typ:
     ```
     maak een bestand tmp/test.txt met de tekst hallo
     ```
   - Goed als: het antwoord eindigt met **Waar we mee bezig zijn** en **Next steps**, zonder dat je erom vroeg.

Zal ik beginnen?
````
