# Question format

For non-trivial discrete questions in `/fwd:grill-me`, structure your message to the user like this (literal markdown to emit):

```markdown
<question>

<Short intro: why this question matters and the gist of the options.>

## Current state (optional)
_Describe the relevant current implementation. Link or quote code with file:line references._

## What's at stake / what could go wrong
_Show why this decision matters and what breaks if we pick poorly. Code examples welcome._

## Options (recommendation: option 1)
1. Option 1: <description> (recommended)
   - code snippet (if useful)
   - impact on other parts of the system
   - why this option wins (cite best practices/rules, or contrast with the alternatives)
   - downsides (performance, complexity, etc.)

2. Option 2: <description>
   …

## Recommendation
Based on the analysis above, I recommend option 1 because <repeat the key reasons it wins and why the downsides are acceptable in this case>.
```

Notes:
- Use this layout only when the question has discrete, comparable options worth weighing. Skip for naming, free-form copy, or trivial yes/no follow-ups — those stay short.
- The "Current state" section is optional; include it when the existing implementation is load-bearing on the decision.
- Mark exactly one option with `(recommended)`, matching the heading's `(recommendation: option N)` note.
