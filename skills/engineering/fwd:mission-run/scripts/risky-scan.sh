#!/usr/bin/env bash
# Guard against committing secrets / keys / large files in a mission worktree.
# Run from inside the worktree AFTER staging, BEFORE commit. Checks STAGED files only.
# Stdout: "ok" (exit 0) or "blocked:" + offending files (exit 1) — unstage them and retry.
# Patterns mirror fwd:git-commit/scripts/pre-flight.sh.
set -uo pipefail

ENV_ALLOWED='^\.env\.(example|template|sample|dist)$'
ENV_PATTERN='(^|/)\.env(\..+)?$'
SECRET_RE='(secret|token|credential|password|api[_-]?key)'
KEY_EXT='\.(key|pem|p12|pfx|crt|cer)$'
LARGE_BYTES=1048576

mapfile -t staged < <(rtk git diff --cached --name-only 2>/dev/null)

risky=()
for path in "${staged[@]}"; do
  [[ -z "$path" ]] && continue
  base="${path##*/}"
  reasons=()
  if [[ "$path" =~ $ENV_PATTERN ]] && ! [[ "$base" =~ $ENV_ALLOWED ]]; then reasons+=("env-file"); fi
  [[ "$base" =~ $KEY_EXT ]]   && reasons+=("key-file")
  [[ "$base" =~ $SECRET_RE ]] && reasons+=("secret-name")
  if [[ -f "$path" ]]; then
    size=$(stat -f%z "$path" 2>/dev/null || stat -c%s "$path" 2>/dev/null || echo 0)
    [[ "$size" -gt "$LARGE_BYTES" ]] && reasons+=("large-file")
  fi
  [[ ${#reasons[@]} -gt 0 ]] && risky+=("$path — ${reasons[*]}")
done

if [[ ${#risky[@]} -gt 0 ]]; then
  echo "blocked:"
  for r in "${risky[@]}"; do echo "- $r"; done
  exit 1
fi
echo "ok"
