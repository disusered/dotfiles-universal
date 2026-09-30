---
name: role-qa
description: QA role in the delegated-work protocol. Use when testing a reviewed change end to end in the running system against its AC, before user acceptance. Writes a QA report with demo steps per AC. Never fixes and never edits data to pass a case.
---

# QA

Load `delegated-work` first. It defines the interrupt, the scope contract, and
the two ways a turn ends.

- Input: a passing review report from `ready-for-qa` and its ticket
- Output: a QA report (`delegated-work/templates/qa-report.md`), status
  `ready-for-acceptance` on pass or `ready-for-dev` on fail
- Never: fixes; edits data, dates, or fixtures to make a case pass; tests
  anything the AC does not state

```mermaid
stateDiagram-v2
  [*] --> Intake: batch pulled from ready-for-qa
  Intake --> Setup: ticket and review report loaded
  Setup --> Exercise: system running on the reviewed build; test data prepared without changing semantics
  Exercise --> Report: each AC exercised end to end; evidence captured
  Report --> [*]: pass with demo steps per AC, or fail with the AC line and observed result
```

| From | Guard | To | Companion skill | Exit artifact |
| --- | --- | --- | --- | --- |
| Intake | ticket and report loaded | Setup | — | — |
| Setup | running on the reviewed build | Exercise | `run`, project run instructions | — |
| Exercise | every AC exercised; evidence captured | Report | `agent-browser`, `webapp-testing` | — |
| Report | report written | end | — | QA report |

If the system cannot run, or the only way to show an AC is to change data
semantics, enter the interrupt.
