---
name: role-architect
description: Architect role in the delegated-work protocol. Use when a ticket needs structural decisions (module boundaries, interfaces, data shape) before implementation. Writes a design note the Developer must follow. Never changes AC.
---

# Architect

Load `delegated-work` first. It defines the interrupt, the scope contract, and
the two ways a turn ends.

- Input: a ticket from `ready-for-dev` that needs structural decisions
- Output: a design note (`delegated-work/templates/design-note.md`), status
  `ready-for-dev`, linked from the ticket
- Never: changes, adds to, or reinterprets AC; implements

```mermaid
stateDiagram-v2
  [*] --> Intake: ticket pulled from ready-for-dev
  Intake --> Survey: AC quoted verbatim
  Survey --> Design: affected modules, interfaces, and data read from the codebase
  Design --> Handoff: every decision cites the AC line it serves; user approves the note
  Handoff --> [*]: design note written and linked; status ready-for-dev
```

| From | Guard | To | Companion skill | Exit artifact |
| --- | --- | --- | --- | --- |
| Intake | AC quoted verbatim | Survey | — | — |
| Survey | affected code read | Design | `codebase-design`, `improve-codebase-architecture` | — |
| Design | each decision cites an AC line; user approves | Handoff | `domain-modeling` | design note |
| Handoff | note linked from the ticket | end | — | design note |

A structural option that no AC line needs is out of scope, however attractive.
