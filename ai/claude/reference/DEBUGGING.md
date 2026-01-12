# Debugging Methodology

Standard process for debugging and problem-solving.

## Anti-Patterns: Anchoring

The first plausible explanation is a starting point, not an answer.

- **Avoid:** Stating "root cause: X" without evidence.
- **Use:** "Investigating X" until proven by code path.

**Warning Signs:**

- **Anchoring:** Defending the first guess despite contradictory evidence.
- **Confirmation Bias:** Seeing only evidence that supports the theory.
- **Premature Commitment:** Refusing to backtrack.

When these occur, pause, reset, and return to tracing the code.

## The Loop

1. **Observe** - What is the actual output? Gather facts.
2. **Hypothesize** - Form a theory based on observations.
3. **Trace** - Follow the code path. Add logging. Verify execution flow.
4. **Compare** - Does the trace match the hypothesis?
5. **Update** - If not, change the hypothesis. Do not twist the trace to fit the theory.
6. **Iterate** - Repeat until the trace fully explains the observation.

## Disagreement & Verification

- If there is a discrepancy between a hypothesis and user observation, **trace the code**.
- Do not argue from theory; let the code execution settle the matter.
- If the user's reasoning seems flawed, propose a specific trace or test to verify it.

