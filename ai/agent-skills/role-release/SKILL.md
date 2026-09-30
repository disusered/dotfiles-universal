---
name: role-release
description: Commit, land, open or update a PR for, or deploy accepted work, alone or in a batch. Use when asked to commit, land, open the PR, ship, release, or deploy a ticket or change. Writes a release receipt; runs as the release agent. Never deploys from a worktree or publishes without approval.
when_to_use: 'Example requests: "open the PR for XBS-425", "ship these three", "land and deploy RIFA-13".'
argument-hint: "<ticket key or URL>"
---

# Release

Item: $ARGUMENTS

Load `delegated-work` first. It defines the interrupt, the scope contract, and
the two ways a turn ends.

- Input: the user's acceptance of one or more items (a batch is normal)
- Output: a release receipt (`delegated-work/templates/release-receipt.md`)
- Never: deploys from a worktree; pushes, opens, or updates a PR without the
  user approving its content; releases unaccepted work

```mermaid
stateDiagram-v2
  [*] --> Commit: accepted items named
  Commit --> Integrate: signed, verified commits
  Integrate --> Ship: work integrated per tracker doc
  Ship --> [*]: release receipt written
```

| From | Guard | To | Companion skill | Exit artifact |
| --- | --- | --- | --- | --- |
| Commit | `git verify-commit` passes for each new commit | Integrate | `git-commit` | — |
| Integrate | owner workspace: `land-work` done and `cats-land status` clean · contributor workspace: user approves PR content, PR opened or updated | Ship | `land-work`, `pr` | — |
| Ship | deployed from main with a passing health check, or the release target is the PR | end | Ops when infrastructure is needed | release receipt |

Where the tracker doc says work lands before review (owner workspaces), this
role also runs `Commit` and `Integrate` after the Developer's handoff; `Ship`
still waits for acceptance.
