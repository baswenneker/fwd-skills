---
name: changelog
description: Automatically generate and update CHANGELOG.md based on recent changes. Writes directly without asking for confirmation.
context: fork
model: haiku
allowed-tools: Bash, Read, Edit, Write
---

# Changelog

Automatically detect recent changes and update CHANGELOG.md. Write changes directly — do NOT ask for confirmation.

## Step 1: Read State

1. Read `CHANGELOG.md` if it exists. Note the latest date and documented commit hashes to avoid duplicates.
2. Run `rtk git log --format='%h %ai %s' -20` to get recent commits with dates.
3. Identify commits not yet in the changelog.

If no new commits found: report "Changelog is up to date" and stop.

## Step 2: Categorize

For each undocumented commit, create entries using these types:
- **[Added]**: New features, commands, files, or functionality
- **[Changed]**: Modifications to existing functionality
- **[Fixed]**: Bug fixes or corrections
- **[Removed]**: Deleted features or files
- **[Security]**: Security improvements

Guidelines:
- Use present tense ("Add" not "Added")
- Be specific: "Add export button to report page" not "Update files"
- Focus on user-facing changes — skip trivial refactors unless significant
- Group by ISO date (YYYY-MM-DD), most recent first

## Step 3: Update CHANGELOG.md

If CHANGELOG.md doesn't exist, create it with this header:
```markdown
# Changelog

All notable changes to this project.

## [Unreleased]
```

Add new entries under `## [Unreleased]`, grouped by date. Format:

```markdown
### YYYY-MM-DD

**Commit: abc1234**
- [Type] Change description
```

**Write directly** — do not present a draft or ask for review. Use Edit to insert new entries after the `## [Unreleased]` line, or Write if creating from scratch.

## Step 4: Confirm

Output a brief summary:
```
Changelog updated: N new entries added (commits abc1234..def5678)
```
