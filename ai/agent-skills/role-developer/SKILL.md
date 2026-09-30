---
name: role-developer
description: Implement, build, fix, or adjust a ticket or change, including fixing review or QA findings on work already in progress. Use when asked to implement, build, fix, change, adjust, or redesign a ticket (XBS-425, .../browse/XBS-425). Enforces the traceability gate and scope audit and writes a review package with per-AC evidence; runs as the developer agent. Never edits, relaxes, or reinterprets AC.
when_to_use: 'Example requests: "implement XBS-430", "fix the findings on XBS-425", "adjust the dashboard per my notes", "fix the bug in RIFA-13".'
argument-hint: "<ticket key or URL>"
---

# Developer

Item: $ARGUMENTS

Load `delegated-work` first. It defines the interrupt, the scope contract, and
the two ways a turn ends.

- Input: a ticket or a user instruction, at any status, plus any design note,
  review report, or QA report already in the item's folder; findings in those
  reports and the user's notes are planned like AC lines
- Output: a review package (`delegated-work/templates/review-package.md`),
  status `ready-for-review`
- Never: edits, relaxes, tightens, or reinterprets AC; changes data or fixtures
  to make behavior appear

```mermaid
stateDiagram-v2
  [*] --> Intake: ticket and existing artifacts read
  Intake --> Sync: AC quoted verbatim
  Sync --> Plan: baseline synced; stranded work known
  Plan --> Build: traceability gate — every planned change cites an AC line or user instruction
  Build --> Verify: code builds; tests run
  Verify --> Build: an AC lacks evidence produced this turn
  Verify --> Build: scope audit finds unsourced behavior (remove it)
  Verify --> Handoff: every AC has evidence from the running review instance; every hunk has a source; the instance responds and is opened for the user
  Handoff --> [*]: review package written; status ready-for-review
```

| From | Guard | To | Companion skill | Exit artifact |
| --- | --- | --- | --- | --- |
| Intake | AC quoted verbatim | Sync | tracker per tracker doc | — |
| Sync | baseline synced | Plan | `xbol-sync-repos`, `cats-land status` | — |
| Plan | every planned change has a source | Build | — | source map (draft) |
| Build | builds; tests run | Verify | `implement`, `tdd`, `diagnosing-bugs` | — |
| Verify | per-AC evidence this turn from the running review instance; scope audit clean; instance responds and is opened for the user | Handoff | `code-review` (spec axis), `run` | — |
| Handoff | package written | end | — | review package |

## Traceability gate (Plan)

List every planned change: files, endpoints, permissions, migrations, UI
controls, defaults, filters, fallbacks, empty states. Beside each, quote the AC
line or the user instruction it serves. An item with no source is removed, or
it enters the interrupt as a question to the AC owner. It is never built.

## Evidence (Verify)

For each AC: identify the command or action that proves it, run it this turn,
read the output, then record it. Rank evidence: screenshot, then command
output, then assertion. A check that did not run this turn is not evidence.

## Scope audit (Verify)

Diff against the base. Map every hunk to its source in the source map. Any
hunk without one is removed before handoff.
