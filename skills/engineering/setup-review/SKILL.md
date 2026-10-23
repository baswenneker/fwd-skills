---
name: setup-review
description: Sets a GitHub repo up for automated checks and for the Workcenter reviewer. Runs unattended — zero prompts, project-local. Installs the pre-commit framework with a generated .pre-commit-config.yaml (gitleaks on every commit, a format check per language found, ESLint/Prettier through the project's own npx, a pre-push hook that runs `ssh workcenter reviewer --now <repo> <branch>` in the background), GitHub Actions workflows (pre-commit on all files, gitleaks over the PR's commits, osv-scanner for dependency CVEs, lint and tests, plus a weekly osv-scanner run), and the opt-in flag "review": true in .claude/fwd/plugin.json. Idempotent; never overwrites a config or workflow the repo already has, and says what it skipped. Prints a fixed-format Dutch summary from the bundled OUTPUT.md template. Runs on Haiku. Use only when the user invokes /fwd:setup-review explicitly; /fwd:setup points at it while the repo has no .pre-commit-config.yaml.
context: fork
model: haiku
allowed-tools: Bash
disable-model-invocation: true
---

# fwd:setup-review

Set the repo up for automated checks and for the Workcenter reviewer, with zero
prompts. Three features, one batch, one fixed-format summary. Each installer lives in
`scripts/<feature>/install.sh`, accepts only `--scope project`, and is idempotent.
Separate from `/fwd:setup` so it can run on its own.

## Apply + report

!`bash "${CLAUDE_SKILL_DIR}/scripts/apply-all.sh" && echo "---OUTPUT-TEMPLATE---" && cat "${CLAUDE_SKILL_DIR}/OUTPUT.md"`

## Instructions

The block above already ran all three installers. That already happened, do not run
them again. It contains two parts:

1. **Above `---OUTPUT-TEMPLATE---`**: one `### <feature>` report per installer
   (`exit=`, `stdout:`, `stderr:`), always in this order: `precommit`, `workflow`,
   `review-flag` — followed by a `### tracked` block (touched files that git tracks).
2. **Below `---OUTPUT-TEMPLATE---`**: the fixed report template (`OUTPUT.md`) — read
   its own instructions and fill in every placeholder from part 1.

Print the filled-in template **verbatim** as your only response. Do not add
commentary before or after it, do not call any tool, do not ask a question.

Per-feature exit code semantics (the same as `/fwd:setup`):

- **0** — installed, already present, or skipped (a stdout line starting with `↷`).
- **2** — collision: the installer refused. It printed the cause and a remediation
  hint to `stderr`. Relay that verbatim per `OUTPUT.md`; do **not** retry.
- **other non-zero** — argument or I/O error. Same handling as a collision.

Feature-specific collision causes:

- **precommit**, **workflow** — `jq` missing (needed to read `package.json`).
- **precommit** — not a git repository; `pre-commit` missing and `uv` missing too (or `uv tool install pre-commit` failed); `core.hooksPath` set (husky), which makes `pre-commit install` refuse; `pre-commit install` failed.
- **workflow** — none; an existing workflow file is skipped (`↷`), not a collision.
- **review-flag** — `"review"` explicitly set to something other than `true` in `.claude/fwd/plugin.json`; that file is not a JSON object; `jq` missing.

## What each feature installs

- **precommit** — `.pre-commit-config.yaml`, only when the repo has none (one it wrote itself, recognised by its first line, counts as present; one the repo wrote is skipped with `↷`, and gitleaks and the push hook are then not added). Hooks: `gitleaks` (staged changes, every commit); `ruff-format --check` for Python; `gofmt` and `cargo fmt --check` as `language: system`; Prettier and ESLint as `language: system` hooks calling `npx --no-install` (`yarn` under Yarn Plug'n'Play), only when `package.json` lists them, so they lint with the project's own version — a JS repo without Prettier gets no format check, since it has no formatter of its own to run; `fwd-review-push` on the `pre-push` stage. `default_install_hook_types` lets a plain `pre-commit install` on another machine install both hooks. Copies `payload/review-push.sh` to `.claude/fwd/review-push.sh`. Installs `pre-commit` with `uv tool install pre-commit` when missing, then runs `pre-commit install`. `pre-commit` was chosen over `lefthook` because it installs and pins the hook tools itself: the same versions on the Mac, the Workcenter and CI.
- **push hook** (`.claude/fwd/review-push.sh`) — first asks `ssh workcenter reviewer --check`, waiting at most 5 seconds: a reviewer that cannot run (a scanner missing, `gh` logged out) prints what is missing in the terminal, and the hook stops there. Then runs `ssh -o BatchMode=yes workcenter reviewer --now <owner/repo> <branch>` detached and exits 0; the push never waits for the review. The hook has `verbose: true`, because pre-commit hides what a passing hook prints; a config this skill wrote earlier without it gets it on a re-run. No SSH access, no `ssh`, a check slower than 5 seconds, a tag push, a non-GitHub remote or a branch name with shell characters → nothing happens (the Workcenter timer picks the PR up).
- **workflow** — `.github/workflows/fwd-review.yml` on `pull_request`: `pre-commit run --all-files` (toolchains for the system hooks set up first); a `gitleaks` job over the PR's commits (`base..head`) with a pinned, checksum-checked release, because the pre-commit hook only scans staged changes and would miss a key committed with `--no-verify`; `osv-scanner` through `google/osv-scanner-action`'s PR workflow (`upload-sarif: false`, so private repos without code scanning work); lint and tests per stack (Node scripts `lint`/`test`, Python with `uv.lock`, Go, Rust). `.github/workflows/fwd-osv-weekly.yml`: a weekly osv-scanner run for new CVEs in unchanged dependencies. Both osv-scanner jobs only when a lockfile or manifest osv-scanner reads exists — without one it fails. Each file only when absent.
- **review-flag** — `"review": true` in `.claude/fwd/plugin.json`, the file smart-lint reads its switch from. `bin/reviewer` on the Workcenter reviews only repos with this flag.

## Invariants

- Invoked explicitly only (`disable-model-invocation: true`); zero prompts (`allowed-tools: Bash`).
- **Project scope only.** Everything goes into the repo (`.pre-commit-config.yaml`, `.claude/fwd/`, `.github/workflows/`) or its `.git/hooks/`, apart from `uv tool install pre-commit`. The files are meant to be committed: the Workcenter reads the flag from its own clone, and CI and other machines need the config.
- **Never overwrites.** A config or workflow file that exists is left alone. Stacks are read once, when a file is written; to regenerate, delete the file and re-run.
- **Plain `git`**, not `rtk git` — a deliberate exception to the repo rule, recorded in CLAUDE.md: these scripts run in other people's repos where rtk may be missing, and the generated hook and workflows run on other machines and in CI.
- Pinned versions and stack detection live once, in `scripts/lib/stack.sh`, shared by `precommit` and `workflow`.
- `scripts/apply-all.sh` always exits 0 and always runs all three installers.
- GitHub only. GitLab (Lely repos) comes later, separately.
- Tests: `bash tests/run-tests.sh` (throwaway repos; tests that need the network and a real `pre-commit` skip themselves without it, or with `FWD_TEST_OFFLINE=1`).
