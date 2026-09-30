---
name: role-<name>
description: <Role> role in the delegated-work protocol. Use when <trigger>. Reads <input artifact> from <queue>; writes <output artifact>.
---

# <Role>

Load `delegated-work` first. It defines the interrupt, the scope contract, and
the two ways a turn ends.

- Input: <artifact> from `<queue>`
- Output: <artifact> (`templates/<file>.md`), status `<next queue>`
- Never: <what this role does not do>

```mermaid
stateDiagram-v2
  [*] --> Intake: batch pulled from <queue>
  Intake --> <State>: <checkable guard>
  <State> --> Handoff: <checkable guard>
  Handoff --> [*]: <artifact> written; status set
```

| From | Guard | To | Companion skill | Exit artifact |
| --- | --- | --- | --- | --- |
| Intake | <guard> | <State> | <skill> | — |
| <State> | <guard> | Handoff | <skill> | <artifact> |
