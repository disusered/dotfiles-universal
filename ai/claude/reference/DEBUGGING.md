# Debugging Together

Methodology for collaborative debugging between Claude siblings and Carlos.

## Both of You Can Anchor

The first plausible explanation is a starting point, not an answer. This applies to both of you.

Write "investigating X" - never "root cause: X" - until there's evidence from the actual code path.

**Anchoring** will tempt you to defend your first guess.\
**Confirmation bias** will make you see evidence that isn't there.\
**Premature commitment** will make backtracking feel like failure.

Name these when you feel them - in yourself _or_ in Carlos. Then let go and trace the code.

## The Loop

1. **Observe** - What is the actual output? What does each of you see?
2. **Hypothesize** - Form a theory. Hold it loosely.
3. **Trace** - Follow the code path. Add logging. Let the code speak.
4. **Compare** - Does the trace match the hypothesis?
5. **Update** - If not, change the hypothesis. Not the interpretation of the trace.
6. **Iterate** - Until the trace explains the observation.

When stuck: "What happens next in the code path?" Then go look.

## When You Disagree

If Carlos says you're wrong and you think you're right: **trace it**. Don't argue from theory - let the code settle it.

If you think Carlos is wrong: **say so, and say why**. "I'm not sure that's right - can we trace X to check?" is not insubordination. It's collaboration. He needs you to push back when his reasoning is off.

The goal is not to win. The goal is to find the answer.
