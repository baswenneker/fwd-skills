---
name: fwd:setup
description: Setup wizard for HeadingFWD's optional Claude Code conventions. Asks the user which features to install (currently smartlint Stop-hook), copies bundled payload files into .claude/hooks/, and merges the matching JSON snippet into ~/.claude/settings.json (user-global) or .claude/settings.local.json (project-local). Idempotent and modular — each feature lives in scripts/<feature>/. Use only when the user invokes /fwd:setup explicitly.
disable-model-invocation: true
---

# fwd:setup

Walk the user through installing HeadingFWD's optional conventions. Each feature is independent: the wizard asks per feature, copies its bundled payload to `<scope>/.claude/hooks/`, and merges its JSON snippet into the right settings file. Re-running the skill is safe — installers detect existing entries and skip.

## Process

### 1. Pick the install scope

Ask the user via `AskUserQuestion`:

- **Project-local** — payload to `<cwd>/.claude/hooks/`, settings into `<cwd>/.claude/settings.local.json`. Default this option when the cwd is inside a git repository (check with `git rev-parse --is-inside-work-tree` first).
- **User-global** — payload to `~/.claude/hooks/`, settings into `~/.claude/settings.json`. Pick this when the user wants the hook to apply everywhere they run Claude Code.

Pass the chosen scope as `--scope user` or `--scope project` to each feature installer.

### 2. Smartlint Stop-hook

Ask via `AskUserQuestion` whether to install the smartlint Stop-hook. Use the option's `preview` field to show the JSON snippet that will be merged so the user knows exactly what lands in their settings file:

```json
{
  "hooks": {
    "Stop": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "test -f \"<HOOK_DIR>/smart-lint-wrapper.sh\" || exit 0; \"<HOOK_DIR>/smart-lint-wrapper.sh\"",
            "timeout": 180000
          }
        ]
      }
    ]
  }
}
```

Where `<HOOK_DIR>` resolves to `$HOME/.claude/hooks` (user) or `$CLAUDE_PROJECT_DIR/.claude/hooks` (project).

If the user picks **Yes**, run:

```
bash "${CLAUDE_SKILL_DIR}/scripts/smartlint/install.sh" --scope <scope>
```

The installer's exit code tells you what happened:

- **0** — installed (fresh) or refreshed (exact match already in settings; payload re-copied to pick up bundled updates).
- **2** — collision: an existing smart-lint Stop-hook with a different command was found. The installer printed the conflicting entry to stderr and refused to merge. Do **not** retry automatically — relay the warning verbatim to the user with the suggested fix (remove the existing entry, re-run `/fwd:setup`).
- **other non-zero** — argument or I/O error; surface the stderr.

If **No**, skip silently.

### 3. Summary

After all selected installers have run, print a short summary:

- Which features were installed
- Which settings file was updated
- Where the payload files live
- Note that re-running `/fwd:setup` is safe (idempotent)

## Invariants

- Skill is invoked explicitly only — `disable-model-invocation: true` keeps the wizard out of automatic-trigger flows.
- Each feature installer lives at `scripts/<feature>/install.sh`, accepts `--scope user|project`, and is idempotent.
- Merging respects existing settings: the shared `scripts/lib/merge-json.sh` deep-merges objects, concatenates arrays, and lets new scalars win on conflict. Each installer also dedupe-checks its own hook before calling the merger so re-runs do not double the array.
- `jq` is required for safe merging. When missing, the merger backs up the target to `<file>.bak` and replaces it with the new snippet (matches the fallback in `fwd-claude-code/fwd/bin/setup.sh`).
- Hook commands use literal `$HOME` (user) or `$CLAUDE_PROJECT_DIR` (project) — Claude Code's shell expands them at hook runtime.

## Adding a new feature later

1. Create `scripts/<feature>/install.sh` (accept `--scope`, copy payload to `<scope>/.claude/hooks/` or wherever it belongs, dedupe-check, then call `../lib/merge-json.sh`).
2. Drop the files to install in `scripts/<feature>/payload/` (with `__HOOK_DIR__` placeholders if relevant).
3. Add an `AskUserQuestion` block in this SKILL.md that gates the installer, and update the summary to mention it.
