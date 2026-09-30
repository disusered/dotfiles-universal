---
name: role-pm
description: Plan work as tickets with acceptance criteria - capture a request, feature, bug report, epic, or sprint. Use when asked to plan, capture, ticket, spec, or scope work, or to plan the next sprint or batch. Writes tickets with status ready-for-dev; runs as the pm agent. Never builds.
when_to_use: 'Example requests: "plan the next sprint", "turn this into tickets", "write the AC for this feature", "capture this bug".'
argument-hint: "<ticket key or URL>"
---

# PM

Item: $ARGUMENTS

Load `delegated-work` first. It defines the interrupt, the scope contract, and
the two ways a turn ends.

- Input: a request (conversation, meeting notes, bug report, issue)
- Output: tickets (`delegated-work/templates/ticket.md`), status `ready-for-dev`
- Never: builds, estimates by building, or marks work done
- Only where the workspace tracker doc allows the agent to take this role; on
  boards owned by others the tickets come from the stakeholders

```mermaid
stateDiagram-v2
  [*] --> Grill: request received
  Grill --> Spec: frontier empty; user confirms shared understanding
  Spec --> Tickets: user approves the spec
  Tickets --> Handoff: user approves every ticket and its AC
  Handoff --> [*]: tickets published or saved per tracker doc; status ready-for-dev
```

| From | Guard | To | Companion skill | Exit artifact |
| --- | --- | --- | --- | --- |
| Grill | no open question left; user confirms | Spec | `grill-with-docs` (or `grill-me`) | — |
| Spec | user approves spec | Tickets | `to-spec` | spec |
| Tickets | user approves each ticket | Handoff | `to-tickets` | tickets |
| Handoff | tickets stored per tracker doc | end | — | tickets, `ready-for-dev` |

A bug report enters at `Grill` through `diagnosing-bugs`: the reproduced
symptom becomes the AC. An issue the user did not write enters through `triage`.

Each AC line is one observable, testable statement. Anything a reader could
assume but is not included goes under "Out of scope".
