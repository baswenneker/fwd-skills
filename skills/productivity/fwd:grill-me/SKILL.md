---
name: fwd:grill-me
description: Interview the user relentlessly about a plan or design until reaching shared understanding, resolving each branch of the decision tree. Use when user wants to stress-test a plan, get grilled on their design, or mentions "grill me".
---

Interview me relentlessly about every aspect of this plan until we reach a shared understanding. Walk down each branch of the design tree, resolving dependencies between decisions one-by-one. For each question, provide your recommended answer.

Ask one question at a time.

Don't assume the user remembers the broader context of what's being grilled. Make each question self-contained: name the part of the plan or design it touches, why this decision matters, and what each option actually means in plain terms. Avoid jargon or shorthand the user hasn't already used.

Don't fix or estimate a number of questions up front, and don't number them. Keep asking, one at a time, until every branch of the design tree is resolved and nothing material is left ambiguous — then stop. Let the plan's complexity set the length: a simple plan may need only a few questions, a complex one many more. Don't pad with marginal questions to feel thorough, and don't stop while a real decision is still open.

If a question can be answered by exploring the codebase, explore the codebase instead. If a question can be answered by consulting documentation, consult the documentation, or use websearch or context7 mcp instead.

**Numbered options for any discrete question.** Whenever a question has a finite set of answers — binary ("A or B?") or multiple-choice — present them as a numbered list (`1.`, `2.`, `3.`, …) so the user can reply with a single digit. Never close a question with prose like "do we go with A or B?" — surface A and B as `1.` and `2.` instead. Mark your recommended option with `(recommended)` at the end of its line.
Open-ended questions (e.g. naming, free-form copy) stay open — skip enumeration when no natural discrete options exist.

For non-trivial discrete questions, follow the layout in [`references/QUESTION_FORMAT.md`](references/QUESTION_FORMAT.md).

The user replies with `y` to accept your recommendation, the option number for a different choice, or a free-form description of a new option.


