# obsolete/

Skills and agents that are **no longer registered in the plugin** (removed from
`.claude-plugin/plugin.json` on 2026-09-10) but kept in the repo as reference.
Nothing here is loaded by Claude Code; the `fwd:` slash commands for these
skills no longer exist after a plugin update.

| Kind | Name | Why archived |
| --- | --- | --- |
| skill | `mission-plan`, `mission-run` | unattended multi-agent missions; retired together with their agents |
| skill | `steps-plan`, `steps-run` | attended step-by-step counterpart of missions; retired together with their agents |
| skill | `plan` | plan-contract planner (`/fwd:plan`), retired |
| skill | `codex-review-plan`, `codex-review-implementation` | adversarial Codex reviews of a plan / a diff, retired |
| skill | `skill-eval` | black-box skill self-evaluation, retired |
| skill | `explain`, `premortem`, `unsure` | interaction modes, retired |
| agent | `mission-coder`, `mission-reviewer`, `mission-scribe`, `mission-user-tester` | only spawned by `mission-run` |
| agent | `steps-reviewer`, `steps-doubt` | only spawned by `steps-run` |
| script | `scripts/check-agent-norms.sh` | drift guard for the shared blocks in the files above |

The folder layout mirrors the live tree (`obsolete/skills/<category>/<name>/`,
`obsolete/agents/<name>.md`) so a skill can be moved back with a single
`git mv` plus a line in `plugin.json`. Cross-skill script paths inside this
folder (`mission-plan` → `../mission-run/scripts/boot-app.sh`,
`codex-review-implementation` → `../codex-review-plan/scripts/resolve-plan-artifact.sh`)
still resolve because the pairs moved together.

`scripts/check-agent-norms.sh` (run from anywhere: `bash obsolete/scripts/check-agent-norms.sh`)
compares the hand-copied blocks `## Shared tool prohibitions`, `## Shared Codex handoff`
and `## Gedeelde taalregel` across the files here and fails on any drift.
