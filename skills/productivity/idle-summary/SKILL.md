---
name: idle-summary
description: Turns the idle summary on or off for this repo, or shows whether it is on. With it on, a session that waits for the user writes one summary of the whole session 50 minutes after its last finished turn, while the 1-hour prompt cache is still warm, and no new one until the user types again. Off by default; the choice is personal, stored outside the repo, and holds for every worktree of the repo. Use only when the user invokes /fwd:idle-summary [on|off].
argument-hint: "[on|off]"
disable-model-invocation: true
allowed-tools: Bash
---

Run this and show its one line of output to the user, nothing else:

```bash
bash "${CLAUDE_SKILL_DIR}/scripts/toggle.sh" $ARGUMENTS
```

An argument other than `on`, `off` or nothing: show the usage line the script prints.

## How it works

The plugin ships two hooks (`hooks/hooks.json` at the plugin root); they do nothing for a
repo where this is off.

- **Stop** (`scripts/stop.sh`, `asyncRewake`): after each finished turn it waits 50 minutes
  in the background, then wakes the session with the summary prompt (`scripts/prompt.txt`).
  It does not wait when the session has fewer than three typed prompts, started with
  `/factory:job`, last wrote the 5-minute cache, still has background or scheduled tasks,
  or already got its summary in this quiet period.
- **UserPromptSubmit** (`scripts/prompt.sh`): a prompt from the user cancels a waiting
  hook and opens a new quiet period.

State lives in `${XDG_STATE_HOME:-~/.local/state}/fwd-idle-summary/`. Tests shorten the
wait with `FWD_IDLE_SUMMARY_WAIT` (seconds).
