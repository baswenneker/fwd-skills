#!/usr/bin/env bash
# install.sh - Tell the next clone how to turn the hooks on: a marker-bracketed
# "Git hooks" section in README.md (created when the repo has none). git runs no
# hook on a clone, by design, so `pre-commit install` is a step someone must take.
#
# Usage:
#   install.sh --scope project
#
# Idempotent: the section between <!-- fwd:setup-precommit:start/end --> is
# replaced on a re-run. Skipped (↷) when .pre-commit-config.yaml is the repo's own:
# the section would describe hooks that are not there. Exit 2 on corrupt markers.

set -euo pipefail

SCOPE=""
while [[ $# -gt 0 ]]; do
    case "$1" in
        --scope)
            [[ $# -ge 2 ]] || { echo "install: --scope needs an argument" >&2; exit 64; }
            SCOPE="$2"
            shift 2
            ;;
        *)
            echo "install: unknown argument: $1" >&2
            exit 64
            ;;
    esac
done

if [[ "$SCOPE" != "project" ]]; then
    echo "install: --scope must be 'project' (the README belongs to one repo)" >&2
    exit 64
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MD_BLOCK="$SCRIPT_DIR/../../../setup/scripts/lib/md-block.sh"
PROJECT_ROOT="${CLAUDE_PROJECT_DIR:-$(pwd)}"
CONFIG="$PROJECT_ROOT/.pre-commit-config.yaml"
README="$PROJECT_ROOT/README.md"

if [[ ! -f "$CONFIG" ]] || [[ "$(head -n 1 "$CONFIG")" != "# Written by /fwd:setup-precommit."* ]]; then
    echo "↷ .pre-commit-config.yaml is not this skill's, README left alone → describe the hooks by hand"
    exit 0
fi

payload="$(mktemp)"
trap 'rm -f "$payload"' EXIT
{
    cat <<'EOF'
## Git hooks

This repo checks every commit with [pre-commit](https://pre-commit.com). After
a clone, run this once:

```sh
pre-commit install
```

No `pre-commit` yet? `uv tool install pre-commit` (or `pipx install pre-commit`).
The hook tools install themselves on the first commit, at the versions pinned in
`.pre-commit-config.yaml`.

- **Every commit:** gitleaks blocks secrets. File checks stop merge-conflict
  markers, large files, private keys and broken YAML, JSON or TOML. Formatters
  fix whitespace, line endings and code style.
- **Commit message:** follows [Conventional Commits](https://www.conventionalcommits.org)
  (`feat: ...`, `fix: ...`).
EOF
    if grep -q 'id: osv-scanner' "$CONFIG"; then
        cat <<'EOF'
- **Every push:** osv-scanner blocks the push when a dependency has a known
  vulnerability. It needs the network.
EOF
    fi
    cat <<'EOF'

When a formatter changes a file, the commit stops: check the change, `git add`
it and commit again. To skip the hooks once: `git commit --no-verify` or
`git push --no-verify`.
EOF
} > "$payload"

before="$(cat "$README" 2>/dev/null || true)"
if ! out="$(bash "$MD_BLOCK" install "$README" setup-precommit "$payload" 2>&1)"; then
    printf '%s\n' "$out" | sed 's|re-run /fwd:setup\.|re-run /fwd:setup-precommit.|' >&2
    exit 2
fi
if [[ "$(cat "$README")" == "$before" ]]; then
    echo "✔ Git hooks section already up to date, no change → $README"
else
    echo "✔ Git hooks section → $README"
fi
