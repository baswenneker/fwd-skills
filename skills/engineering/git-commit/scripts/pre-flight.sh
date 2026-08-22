#!/usr/bin/env bash
# Pre-flight scan for risky files before staging. If clean, stages everything.
#
# What counts as risky:
#   - env-file     untracked .env / .env.<anything> EXCEPT the allowlist
#                  (.env.example, .env.template, .env.sample, .env.dist)
#   - log-file     untracked *.log
#   - key-file     untracked *.key / *.pem / *.p12 / *.pfx / *.crt / *.cer
#   - secret-name  untracked file whose basename matches
#                  (secret|token|credential|password|api[_-]?key)
#   - large-file   any non-deleted file larger than 1 MiB (1048576 bytes)
#
# Notes:
#   - Filename-based checks only fire for untracked files (status "??"). Files
#     that are already tracked are assumed reviewed — modifying them never
#     trips env-file / log-file / key-file / secret-name.
#   - The size check fires for tracked AND untracked files (any non-deletion).
#
# Output is read by the SKILL.md body. Lines:
#   no-changes
#   git-failed: <message>
#   risky-files:
#   - <path> — <reason …>
#   ok

set -uo pipefail

ENV_ALLOWED='^\.env\.(example|template|sample|dist)$'
ENV_PATTERN='(^|/)\.env(\..+)?$'
SECRET_RE='(secret|token|credential|password|api[_-]?key)'
KEY_EXT='\.(key|pem|p12|pfx|crt|cer)$'
LOG_EXT='\.log$'
LARGE_BYTES=1048576

# --untracked-files=all is required: without it git collapses a new directory into a
# single "?? dir/" line, so a risky file inside it (config/.env.production) passes every
# name check below and still gets staged by `git add -A`.
if ! status_output=$(rtk git status --porcelain --untracked-files=all 2>&1); then
  printf 'git-failed: %s\n' "${status_output//$'\n'/ }"
  exit 0
fi

# rtk rewrites empty status output to the literal line "ok" — strip that artifact,
# or a clean tree skips the no-changes exit. Real porcelain lines are never exactly "ok".
status_output="$(grep -vx 'ok' <<<"$status_output" || true)"

if [[ -z "$status_output" ]]; then
  echo "no-changes"
  exit 0
fi

risky=()

while IFS= read -r line; do
  [[ ${#line} -lt 4 ]] && continue
  status="${line:0:2}"
  pathpart="${line:3}"

  # Renames are reported as "old -> new" — keep the new path.
  if [[ "$pathpart" == *' -> '* ]]; then
    pathpart="${pathpart##* -> }"
  fi
  # Strip surrounding quotes (git status quotes paths with special chars).
  if [[ "$pathpart" == \"*\" ]]; then
    pathpart="${pathpart#\"}"
    pathpart="${pathpart%\"}"
  fi

  basename="${pathpart##*/}"
  reasons=()

  if [[ "$status" == "??" ]]; then
    if [[ "$pathpart" =~ $ENV_PATTERN ]] && ! [[ "$basename" =~ $ENV_ALLOWED ]]; then
      reasons+=("env-file")
    fi
    [[ "$pathpart" =~ $LOG_EXT ]] && reasons+=("log-file")
    [[ "$pathpart" =~ $KEY_EXT ]] && reasons+=("key-file")
    [[ "$basename" =~ $SECRET_RE ]] && reasons+=("secret-name")
  fi

  if [[ "$status" != " D" && "$status" != "D " && "$status" != "DD" ]]; then
    if [[ -f "$pathpart" ]]; then
      size=$(stat -f%z "$pathpart" 2>/dev/null || stat -c%s "$pathpart" 2>/dev/null || echo 0)
      [[ "$size" -gt "$LARGE_BYTES" ]] && reasons+=("large-file")
    fi
  fi

  if [[ ${#reasons[@]} -gt 0 ]]; then
    risky+=("$pathpart — ${reasons[*]}")
  fi
done <<< "$status_output"

if [[ ${#risky[@]} -gt 0 ]]; then
  echo "risky-files:"
  for r in "${risky[@]}"; do
    echo "- $r"
  done
  exit 0
fi

if ! stage_output=$(rtk git add -A 2>&1); then
  printf 'git-failed: %s\n' "${stage_output//$'\n'/ }"
  exit 0
fi

echo "ok"
