---
name: next-steps
description: Answers "en nu?" with a short status block in Dutch -- one fact about where we stand, then one numbered list of next steps in the order they happen, with the user's own steps marked JIJ -- and ends with an offer to start, here or through the autocoder. Looks at the current session only and changes nothing. Invoke when the user asks "en nu?", "ok en nu?", "wat nu?", "wat is de status?", "waar staan we?", "what's next", or invokes /fwd:next-steps. The short form of this block already ends every finished turn through the fwd-skills output style (installed by /fwd:setup); this skill is the full version, with the fact check and the autocoder offer.
allowed-tools: Read, Bash
---

# Next steps

Tell the user, in a few lines, where the work of this session stands and what
happens next. The user asks "en nu?" because they lost track or want to
decide; the block must let them decide in one reply, and see at one glance
which steps are theirs.

## Scope

- **Current session only.** Use what this conversation did and decided. Do not
  read other sessions, other repos or the Workcenter.
- **Check facts that may have moved.** Before writing the Stand line, verify
  what the conversation can no longer prove: `rtk git status` and the current
  branch, `gh pr view` for a PR this session opened, the state of a background
  task it started. Say the checked fact, not your memory of it.
- **Read-only.** The block changes nothing: no commit, no push, no issue, no
  file edit. Starting a step waits for the user's reply.

## Format

Print exactly this shape, in Dutch:

```
**Stand:** <one fact the user can check>

1. Ik <step>.
2. Ik <step>.
3. **JIJ:** <step>
   - Waar: <where it happens>
   - Typ: `<exact command>`
   - Goed als: <what the user sees>
4. Ik <step>.

<closing line>
```

Rules:

- **One numbered list, in the order things happen.** Never group by who does
  it: the user must see that step 3 comes after 1 and 2 and before 4. Numbers
  run on, so "doe 1-2" works. At most five steps.
- **Who does a step.** "Ik" in plain text for Claude, **JIJ:** in bold for the
  user, so the user's own steps stand out at a glance. A step both take part in
  is split in two steps.
- **Ik first.** A step Claude can do with its own tools is an "Ik" step -- also
  when it runs on another machine over `ssh` (`ssh workcenter '<command>'`) or
  outside the repo. Look up the real command before handing it over: `<tool>
  --help`, the installed version, the configured source.
- **JIJ only for what Claude cannot do:** restart Claude Code, open a new
  session, a decision, a merge the user wants to do themselves, a login,
  judging the result.
- **Every JIJ step says how**, indented under the step:
  - **Waar**: the Mac terminal, the Workcenter (`ssh workcenter`), or this
    Claude Code session with the `!` prefix (`! <command>` runs it here, so the
    output lands in the conversation);
  - **Typ**: the exact commands or keystrokes in a code block, ready to copy,
    with real names and paths -- never a placeholder the user has to fill in;
  - **Goed als**: what the user sees when it worked: a version number, a line
    in a file, a block at the end of a reply.

  For a test, give the exact message to type and what the answer must contain.
- **Stand** is one line with a fact the user can check: "PR #14 is gemerged",
  "branch `feat/x` niet gepusht", "3 van 5 tests rood". Something stuck says
  what blocks it. A PR or issue the block names gets its number as a markdown
  link (`[PR #15](https://…/pull/15)`, never the bare URL) and one sentence on
  what it is. When the block ends a longer report, Stand does not repeat that
  report.
- **Size.** No emoji, no table, no extra headings. Under ~600 characters; the
  how-to under a JIJ step is what may use the room.

## Closing line

Ends the block with what happens on the user's next reply.

- **Default:** `Zal ik beginnen met 1-2?` -- name the steps Claude can start
  now. The user's "ok", "ja" or "doe maar" starts them here, in this session.
- **Work fit for the autocoder** -- more than a few lines, bounded, a clear
  done state -- offers the autocoder as alternative:

  ```
  Ik begin hier en nu, tenzij je "autocoder", "autocoder nu" of "autocoder vanavond" zegt.
  ```

  On the reply: "autocoder" → run `/autocoder` in this session
  (`workcenter:autocoder`); "autocoder nu" → `workcenter:autocoder-issue`, picked
  up straight away; "autocoder vanavond" → `workcenter:autocoder-issue` for the
  evening run. Any other yes starts the steps here. Leave the autocoder out when
  the `workcenter` plugin is not installed.
- **No "Ik" step in the list** (only the user can act) → no closing line; the
  JIJ step says what is needed.
- **Nothing left** → replace the whole block with one line: `Alles is af:
  <fact>. Er staat niets meer open.` Never invent a step to fill the list.

## Examples

Claude does the work, the user only decides:

```
**Stand:** het ontwerp is afgesproken; `main` is schoon en er is nog geen branch.

1. Ik schrijf `SKILL.md` in `skills/productivity/next-steps/`.
2. Ik registreer de skill in `plugin.json` en `README.md`, en verhoog de versie.
3. Ik maak een PR op de branch `feat/next-steps`.
4. **JIJ:** test de skill in een andere sessie met "ok en nu?".
   - Waar: een nieuwe Claude Code-sessie in een andere repo.
   - Typ: `ok en nu?`
   - Goed als: het antwoord begint met **Stand:** en bevat een genummerde lijst.

Ik begin hier en nu, tenzij je "autocoder", "autocoder nu" of "autocoder vanavond" zegt.
```

The user has a step in the middle:

````
**Stand:** [PR #15](https://github.com/baswenneker/fwd-skills/pull/15) (voegt `fwd:next-steps` toe) is gemerged; de Workcenter draait nog plugin 1.1.0.

1. Ik werk de plugin bij op de Workcenter.
2. Ik zet de output style aan in `~/.claude/settings.json`.
3. **JIJ:** herstart Claude Code en test of het blok vanzelf komt.
   - Waar: een nieuwe Claude Code-sessie in deze repo.
   - Typ: `maak tmp/test.txt met de tekst hallo`
   - Goed als: het antwoord eindigt met **Stand:** en een genummerde lijst, zonder dat je erom vroeg.

Zal ik beginnen met 1-2?
````
