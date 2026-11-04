---
name: setup-precommit
description: Sets a repo up with pre-commit hooks. Runs unattended — zero prompts, project-local. Writes a .pre-commit-config.yaml with file checks and whitespace fixers (pre-commit-hooks), gitleaks, a Conventional Commits check on the message, autofixing formatters for the languages it finds (ruff for Python, shfmt and shellcheck for shell, Prettier for TypeScript/JS/HTML/CSS/JSON, the project's own ESLint and Prettier when package.json lists them). A JS/TS repo without Prettier first gets .prettierrc.json and one formatting commit, skipped in git blame, actionlint for GitHub workflows, hadolint for Dockerfiles, and osv-scanner on every push (blocks on a known CVE) when the repo has a lockfile. Runs `pre-commit install`, adds a "Git hooks" section to README.md that tells the next clone to run `pre-commit install`, and removes what the retired /fwd:setup-review left (its workflows, the Workcenter push hook, "review": true). Idempotent; rewrites a config it wrote itself, never one the repo wrote. Prints a fixed-format Dutch summary from the bundled OUTPUT.md template. Runs on Haiku. Use only when the user invokes /fwd:setup-precommit explicitly; /fwd:setup points at it while the repo has no config, or has one whose hook this clone never installed.
context: fork
model: haiku
allowed-tools: Bash
disable-model-invocation: true
---

# fwd:setup-precommit

Set the repo up with pre-commit hooks, with zero prompts. Four features, one batch,
one fixed-format summary. Each installer lives in `scripts/<feature>/install.sh`,
accepts only `--scope project`, and is idempotent. Separate from `/fwd:setup` so it
can run on its own.

## Apply + report

!`bash "${CLAUDE_SKILL_DIR}/scripts/apply-all.sh" && echo "---OUTPUT-TEMPLATE---" && cat "${CLAUDE_SKILL_DIR}/OUTPUT.md"`

## Instructions

The block above already ran all four installers. That already happened, do not run
them again. It contains two parts:

1. **Above `---OUTPUT-TEMPLATE---`**: one `### <feature>` report per installer
   (`exit=`, `stdout:`, `stderr:`), always in this order: `prettier`, `precommit`,
   `readme`, `legacy` — followed by a `### tracked` block (touched files that git tracks).
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

- **prettier** — tracked files with uncommitted changes; no commit yet; HEAD not on a branch; a merge, rebase or cherry-pick under way; `npx` missing; Prettier failed on a file (every file is restored).
- **precommit** — `lefthook.yml` (lefthook owns the git hooks; nothing is written); `jq` missing (needed to read `package.json`); not a git repository; `pre-commit` missing and `uv` missing too (or `uv tool install pre-commit` failed); `core.hooksPath` set (husky), which makes `pre-commit install` refuse; `pre-commit install` failed.
- **readme** — corrupt `<!-- fwd:setup-precommit:start/end -->` markers in `README.md`.
- **legacy** — none.

## What each feature installs

- **prettier** — only in a repo with JS/TS/CSS/HTML files and no Prettier config, no Prettier in `package.json` and no `biome.json` whose formatter is on (Biome formats there, and the Prettier hook stays out too; `"formatter": {"enabled": false}` makes Biome a linter only); otherwise skipped (`↷`). Writes `.prettierrc.json` (`printWidth` 120; `singleQuote` when import lines mostly use single quotes), formats every tracked file the Prettier hook covers with the pinned Prettier (`npx --yes prettier@<PRETTIER_REV>`), and commits that as `style: format with Prettier` (`--no-verify`). When that changed code, a second commit adds its id to `.git-blame-ignore-revs` (GitHub reads it) and `blame.ignoreRevsFile` points local git blame at it. Without this baseline the Prettier hook would rewrite every file a commit touches, in code that was never formatted that way. Branches that started earlier get merge conflicts in the reformatted files; stderr says so.
- **precommit** — `.pre-commit-config.yaml`, read from the stacks found when it is written. A config this skill wrote (first line `# Written by /fwd:setup-precommit.`) or the old `/fwd:setup-review` wrote is rewritten on every run, so a new language or a raised pinned version arrives with a re-run; deleting the first line makes it the repo's own. Hooks below the line `  # Own hooks below this line: a re-run of /fwd:setup-precommit keeps them.` survive a rewrite, so a repo can add its own `repo: local` hooks (a typecheck, a linter) and still get updates. A top-level `exclude:` line (generated files no hook may touch) survives too. A config the repo wrote is skipped (`↷`).
  - Every repo, every commit: `trailing-whitespace`, `end-of-file-fixer`, `check-merge-conflict`, `check-added-large-files`, `detect-private-key`, `check-yaml` (syntax only), `check-json` (not tsconfig or editor settings, which allow comments), `check-toml`, `gitleaks` (staged changes). The fixers leave lockfiles, `vendor/` and minified files alone.
  - Every repo, the commit message: `conventional-pre-commit` (stage `commit-msg`).
  - Per stack, every commit, fixers first: `ruff-check --fix` and `ruff-format` (Python); `shfmt --write -i <the indent the scripts already use>` and `shellcheck` (`.sh`/`.bash`); `actionlint` (`.github/workflows/`); `hadolint` (a Dockerfile); Prettier `--write` on JS, TS, CSS, SCSS, Less, HTML, Vue and JSON — the project's own through `npx --no-install` (`yarn` under Plug'n'Play) when `package.json` lists it, else the pinned `mirrors-prettier`, but only next to a Prettier config (the prettier feature writes one); the project's own `eslint --fix` when `package.json` lists ESLint. Markdown and YAML are not reformatted.
  - With a lockfile osv-scanner reads, every push: `osv-scanner scan source --recursive .`. A known vulnerability blocks the push; exit 128 ("no packages found", a `go.mod` without dependencies) passes.
  - `default_install_hook_types: [pre-commit, commit-msg, pre-push]`, so a plain `pre-commit install` in another clone installs all three. Installs `pre-commit` with `uv tool install pre-commit` when missing, then runs `pre-commit install`.
- **readme** — a `## Git hooks` section in `README.md` between `<!-- fwd:setup-precommit:start -->` and `<!-- fwd:setup-precommit:end -->`: run `pre-commit install` after a clone, what runs when, and how to skip once. git runs no hook on a clone, by design, so this is the step the next clone must take. Created with the README when there is none; skipped (`↷`) next to a config the repo wrote. Uses `setup/scripts/lib/md-block.sh`.
- **legacy** — removes what `/fwd:setup-review` left: `.github/workflows/fwd-review.yml` and `fwd-osv-weekly.yml` (only with its first line), `.claude/fwd/review-push.sh`, and `"review"` in `.claude/fwd/plugin.json` (the file goes when that was its only key). Empty directories it leaves behind go too.

## Invariants

- Invoked explicitly only (`disable-model-invocation: true`); zero prompts (`allowed-tools: Bash`).
- **Project scope only.** Everything goes into the repo (`.pre-commit-config.yaml`, `README.md`) or its `.git/hooks/`, apart from `uv tool install pre-commit`. The files are meant to be committed: another clone needs the config.
- **No CI and no merge check.** The hooks run on the developer's machine only; `--no-verify` skips them.
- **Plain `git`**, not `rtk git` — a deliberate exception to the repo rule, recorded in CLAUDE.md: these scripts run in other people's repos where rtk may be missing, and the generated hooks run on other machines.
- Pinned versions and stack detection live once, in `scripts/lib/stack.sh`.
- `scripts/apply-all.sh` always exits 0 and always runs all four installers, `prettier` first so the config sees its `.prettierrc.json`.
- Commits only the Prettier baseline (the formatting commit and the `.git-blame-ignore-revs` commit), and only on a clean tree. Everything else stays uncommitted.
- Tests: `bash tests/run-tests.sh` (throwaway repos; the test that needs the network and a real `pre-commit` skips itself without it, or with `FWD_TEST_OFFLINE=1`).
