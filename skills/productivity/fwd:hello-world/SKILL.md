---
name: fwd:hello-world
description: Minimal demo skill — prints "Hello world" and nothing else. Use when the user invokes /fwd:hello-world, asks for the hello-world skill, or wants the smallest possible skill example to crib from when authoring their own.
---

When this skill is invoked, your entire response must be exactly:

```
Hello world
```

No preamble, no follow-up, no markdown formatting around the two words. Don't explain what the skill does; the user invoked it knowing what it does.

## Why this skill exists

It is the smallest viable example of a skill: YAML frontmatter (`name`, `description`) plus one behaviour rule. Use it as a template when scaffolding a new skill — copy the folder, rename, replace the rule.
