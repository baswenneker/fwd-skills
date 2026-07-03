#!/usr/bin/env bash
# Compact inventory of .claude/rules/: for each *.md file print ONE line with:
#   <path>  <scope>  <first-heading>
# If .claude/rules/ is absent or contains no *.md files, print an explicit
# "geen regels gevonden" line. Never exits non-zero for missing rules.
# Read-only — writes nothing.
set -euo pipefail

# Resolve repo root from any cwd inside the repo (same pattern as sibling scripts).
REPO_ROOT="$(rtk git rev-parse --show-toplevel 2>/dev/null)"

RULES_DIR="$REPO_ROOT/.claude/rules"

# Collect *.md files (sorted, stable output).
if [[ ! -d "$RULES_DIR" ]]; then
  echo "geen regels gevonden — .claude/rules/ is leeg of afwezig"
  exit 0
fi

mapfile -t files < <(find "$RULES_DIR" -maxdepth 1 -name '*.md' | sort)

if [[ ${#files[@]} -eq 0 ]]; then
  echo "geen regels gevonden — .claude/rules/ is leeg of afwezig"
  exit 0
fi

for f in "${files[@]}"; do
  # Relative path from repo root.
  rel=".claude/rules/$(basename "$f")"

  # Extract paths: scope from YAML frontmatter (between the first --- pair).
  # Supports both inline ("paths: [\"a/**\"]") and block-style (- glob lines).
  scope=""
  in_front=0
  in_paths_block=0
  paths_values=()

  while IFS= read -r line; do
    if [[ $in_front -eq 0 && "$line" == "---" ]]; then
      in_front=1
      continue
    fi
    if [[ $in_front -eq 1 && "$line" == "---" ]]; then
      break
    fi
    if [[ $in_front -eq 1 ]]; then
      # Inline paths: paths: ["glob1", "glob2"] or paths: [glob1, glob2]
      if echo "$line" | grep -Eq '^paths:[[:space:]]*\['; then
        raw="$(echo "$line" | sed 's/^paths:[[:space:]]*//')"
        # Strip brackets and quotes, split on comma
        inner="$(echo "$raw" | sed 's/^\[//;s/\]$//')"
        # shellcheck disable=SC2207
        IFS=',' read -ra items <<< "$inner"
        for item in "${items[@]}"; do
          trimmed="$(echo "$item" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//;s/^"//;s/"$//')"
          [[ -n "$trimmed" ]] && paths_values+=("$trimmed")
        done
        in_paths_block=0
        continue
      fi
      # Block-style paths: key on its own line, then - glob entries
      if echo "$line" | grep -Eq '^paths:[[:space:]]*$'; then
        in_paths_block=1
        continue
      fi
      if [[ $in_paths_block -eq 1 ]]; then
        if echo "$line" | grep -Eq '^[[:space:]]*-[[:space:]]'; then
          item="$(echo "$line" | sed 's/^[[:space:]]*-[[:space:]]*//')"
          trimmed="$(echo "$item" | sed 's/^"//;s/"$//')"
          [[ -n "$trimmed" ]] && paths_values+=("$trimmed")
          continue
        else
          in_paths_block=0
        fi
      fi
    fi
  done < "$f"

  if [[ ${#paths_values[@]} -gt 0 ]]; then
    scope="$(IFS=', '; echo "${paths_values[*]}")"
  else
    scope="repo-wide"
  fi

  # First heading: first line starting with #.
  heading="$(grep -m1 '^#' "$f" || echo "(geen heading)")"

  printf '%s\t%s\t%s\n' "$rel" "$scope" "$heading"
done
