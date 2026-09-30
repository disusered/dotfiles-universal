---
name: role-<name>
description: <What the role does, in the words users type>. Use when asked to <verbs and example objects, e.g. ticket keys>. Writes <output artifact>; runs as the <name> agent.
when_to_use: 'Example requests: "<request 1>", "<request 2>".'
argument-hint: "<ticket key or URL>"
---

# <Role>

Item: $ARGUMENTS

Load `delegated-work` first. It defines the interrupt, the scope contract, and
the two ways a turn ends.

- Input: <minimum input>, at any status; <upstream artifact> too when one exists
- Output: <artifact> (`templates/<file>.md`), status `<next status>`
- Never: <what this role does not do>

```mermaid
stateDiagram-v2
  [*] --> Intake: <minimum input located>
  Intake --> <State>: <checkable guard>
  <State> --> Handoff: <checkable guard>
  Handoff --> [*]: <artifact> written; status set
```

| From | Guard | To | Companion skill | Exit artifact |
| --- | --- | --- | --- | --- |
| Intake | <guard> | <State> | <skill> | — |
| <State> | <guard> | Handoff | <skill> | <artifact> |
