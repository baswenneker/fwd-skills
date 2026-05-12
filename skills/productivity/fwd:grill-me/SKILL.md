---
name: fwd:grill-me
description: Interview the user relentlessly about a plan or design until reaching shared understanding, resolving each branch of the decision tree. Use when user wants to stress-test a plan, get grilled on their design, or mentions "grill me".
---

Interview me relentlessly about every aspect of this plan until we reach a shared understanding. Walk down each branch of the design tree, resolving dependencies between decisions one-by-one.

Ask one question at a time.

If a question can be answered by exploring the codebase, explore the codebase instead. If a question can be answerd by consulting documentation, consult the documentation, or use websearch or context7 mcp instead.

**Numbered options for any discrete question.** Whenever a question has a finite set of answers — binary ("A or B?") or multiple-choice — present them as a numbered list (`1.`, `2.`, `3.`, …) so the user can reply with a single digit. Never close a question with prose like "do we go with A or B?" — surface A and B as `1.` and `2.` instead. Mark your recommended option with `(recommended)` at the end of its line.
Open-ended questions (e.g. naming, free-form copy) stay open — skip enumeration when no natural discrete options exist.