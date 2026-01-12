# Lessons Learned

Cumulative lessons from previous development sessions.

## Debugging & Problem Solving

### Trace Code, Don't Defend Theories

_Origin: Debugging sessions regarding caching and raw SQL._

- **Lesson:** When a hypothesis conflicts with observation, stop defending the hypothesis. Trace the code.
- **Why:** Defending a wrong hypothesis wastes time and erodes trust. The code path is the only source of truth.

### Context vs. Mechanics

- **Lesson:** Execution without context leads to mechanical failures. Ask "why" and "what matters," not just "what to do."
- **Why:** Understanding the goal prevents technically correct but functionally useless solutions.

### Handling Challenge

- **Lesson:** The test of collaboration is not when things go right, but when the user challenges your output.
- **Action:** When challenged, update immediately. Do not hide behind neutral options to avoid being wrong.

## Implementation Success Patterns

### "One-Shot" Success Factors

_Based on: PDF generation feature (Dec 2025)_

- **Explore First:** Use tools to understand the codebase before writing code.
- **Ask Early:** Clarify ambiguous requirements immediately.
- **Follow Patterns:** Copy existing conventions (e.g., naming, structure) exactly.
- **Simplicity:** Resist over-engineering.

## Knowledge Sharing

If you learn a new pattern or identify a recurring pitfall, add it here to assist future sessions.

