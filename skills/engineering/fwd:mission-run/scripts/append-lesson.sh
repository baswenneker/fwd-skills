#!/usr/bin/env bash
# Append a lesson to the MAIN repo's .claude/lessons/LESSONS.md in the strict
# repo format. Lessons are cross-mission repo memory, so they go to the main
# checkout (resolved via --git-common-dir, correct even when called from a worktree),
# never the mission branch. Not committed — the user/their hooks manage lessons commits.
# Args: <type> <scope> <context> <observation> <lesson>
#   type in: correction | insight | rule-gap | deviation
set -euo pipefail

TYPE="${1:?usage: append-lesson.sh <type> <scope> <context> <observation> <lesson>}"
SCOPE="${2:?scope required}"
CTX="${3:?context required}"
OBS="${4:?observation required}"
LES="${5:?lesson required}"
case "$TYPE" in correction|insight|rule-gap|deviation) ;; *) echo "bad type '$TYPE' (correction|insight|rule-gap|deviation)" >&2; exit 1 ;; esac

MAIN_ROOT="$(dirname "$(rtk git rev-parse --path-format=absolute --git-common-dir)")"
DIR="$MAIN_ROOT/.claude/lessons"
FILE="$DIR/LESSONS.md"
mkdir -p "$DIR"

if [[ ! -f "$FILE" ]]; then
  cat > "$FILE" <<'HDR'
# Lessons

Persistent memory across sessions. Newest entries at the bottom.

Format:

```
### YYYY-MM-DD | <type> | <scope>
**Context**: [what was happening]
**Observation**: [what went wrong / was observed]
**Lesson**: [what to do next time]
```

Types: `correction` | `insight` | `rule-gap` | `deviation`.
HDR
fi

{
  printf '\n### %s | %s | %s\n' "$(date -u +%F)" "$TYPE" "$SCOPE"
  printf '**Context**: %s\n' "$CTX"
  printf '**Observation**: %s\n' "$OBS"
  printf '**Lesson**: %s\n' "$LES"
} >> "$FILE"

echo "lesson appended to $FILE"
