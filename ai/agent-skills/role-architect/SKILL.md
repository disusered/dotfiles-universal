---
name: role-architect
description: Make the structural decisions a ticket needs before implementation - module boundaries, interfaces, data shape. Use when asked to design or architect a ticket, or when a ticket cannot be built without those decisions. Writes a design note the Developer follows; runs as the architect agent. Never changes AC.
when_to_use: 'Example requests: "design the data model for XBS-430", "how should we structure RIFA-13 before building it".'
argument-hint: "<ticket key or URL>"
---

# Architect

Item: $ARGUMENTS

Load `delegated-work` first. It defines the interrupt, the scope contract, and
the two ways a turn ends.

- Input: a ticket that needs structural decisions, at any status
- Output: a design note (`delegated-work/templates/design-note.md`), status
  `ready-for-dev`, linked from the ticket
- Never: changes, adds to, or reinterprets AC; implements

```mermaid
stateDiagram-v2
  [*] --> Intake: ticket read
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
