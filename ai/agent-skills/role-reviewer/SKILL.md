---
name: role-reviewer
description: Review a ticket's implementation, a branch, a PR, or in-progress work against its acceptance criteria, in a context separate from whoever built it. Use when asked to review a ticket (XBS-425, .../browse/XBS-425), review its implementation, or review with another model. Writes a pass or fail review report; runs as the reviewer agent. Never fixes; fixes go to the developer agent.
when_to_use: 'Example requests: "review the implementation of XBS-425", "review this branch against the ticket", "review the PR for RIFA-13", "have another model review XBS-425".'
argument-hint: "<ticket key or URL>"
---

# Reviewer

Item: $ARGUMENTS

In a main session, run the `reviewer` agent on the item with the inputs its
description lists, then save the report it returns under `.scratch/<key>/`.
Inside the `reviewer` agent, follow the steps below.

Load `delegated-work` first. It defines the interrupt, the scope contract, and
the two ways a turn ends.

- Input: the ticket's AC and the diff (branch, PR, worktree, or range) as it
  stands, at any status; the review package too when one exists. Without one,
  map hunks to AC from the diff and say so on the report's first line
- Output: a review report (`delegated-work/templates/review-report.md`), status
  `ready-for-qa` on pass or `ready-for-dev` on fail
- Never: fixes, rewrites, or reruns the Developer's work; reads the Developer's
  conversation

```mermaid
stateDiagram-v2
  [*] --> Read: ticket and diff located
  Read --> Check: ticket AC, source map, and diff loaded
  Check --> Report: every AC judged; every hunk mapped to a source
  Report --> [*]: pass (all AC met, no unsourced behavior) or fail (lines cited)
```

| From | Guard | To | Companion skill | Exit artifact |
| --- | --- | --- | --- | --- |
| Read | ticket, package, diff loaded | Check | — | — |
| Check | each AC judged met / missing / partial / wrong; each hunk sourced or flagged | Report | `code-review` | — |
| Report | report written | end | — | review report |

Pass requires every AC met and no unsourced behavior. Anything else fails, with
the AC line quoted and the file and line cited.
