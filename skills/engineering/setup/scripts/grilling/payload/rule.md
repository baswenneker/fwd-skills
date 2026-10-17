# Grilling: ask few, assume rest

`grilling` skill (also grill-me / grill-with-docs), per frontier decision:

1. No real choice (one option obvious, the other only on paper)
   -> assumption.
2. Technical choice with real alternatives -> question, even with a clear
   rec. Lead with what each option means for the user (speed, latency,
   accuracy, cost, memory, where it works); mechanism after, one line.
   Assume the user may not know the area.
3. Other choices (process, docs, naming, planning) -> question only if both:
   a. user could pick other than your rec: answer hinges on something not
      in code/docs/chat (preference, priority, plan);
   b. wrong guess, corrected after the round, undoes dependent decisions.
   Else -> assumption.
4. Unsure which -> question.

Assumptions: decide with your rec, list at end of round under "Aannames",
one line each with the reason, user corrects in one reply.
Listed assumption = branch visited, not "silently assumed".
