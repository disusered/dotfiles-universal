---
name: grill-me
description: Interview the user relentlessly about a plan or design until reaching shared understanding, resolving each branch of the decision tree. Use when user wants to stress-test a plan, get grilled on their design, or mentions "grill me".
---

# Grill Me

Interview me relentlessly about every aspect of this plan until
we reach a shared understanding. Walk down each branch of the design
tree resolving dependencies between decisions one by one.

If a question can be answered by exploring the codebase, explore the
codebase instead.

For each question, provide your recommended answer.

## Rules

- One question at a time. Wait for the answer before moving to the next branch.
- Start with the highest-leverage decision — the one that constrains the most downstream choices.
- If the answer reveals a sub-decision, drill into it immediately before returning to the parent branch.
- Do not accept vague answers. If "it depends" — resolve what it depends on right now.
- When you and I converge on a decision, state the resolved decision explicitly before moving on.
- Keep going until every leaf of the decision tree has a concrete, written resolution.
- At the end, output the full resolved decision tree as a summary.
