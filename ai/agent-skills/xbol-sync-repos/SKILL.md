---
name: xbol-sync-repos
description: Fetch and prune origin, switch XBOL repositories to their baseline branch, fast-forward them, and clear obsolete local branches and worktrees whose work is recoverable. Use when asked to sync or clean the XBOL checkouts.
---

Maintain these existing checkouts under `/home/carlos/Development/XBOL`:

- `xbol-api-admin`
- `xbol-api-ticketing`
- `xbol-api-client`
- `xbol-db-develop` (origin repository `odasoft/xbol-db`)
- `xbol-web-client`
- `xbol-web-admin`
- `xbol-bastion` — use `main` / `origin/main`

An invocation to run this maintenance authorizes origin fetching and pruning, clean
checkout switches, fast-forward updates, removal of obsolete worktrees and worktree
metadata, and deletion of obsolete local branches whose work is recoverable. It does
not authorize deleting any branch on GitHub; that requires the separate confirmation
described under "Delete origin branches". Creating or editing this skill alone does
not authorize a maintenance run.

Use `git -C <repository>` for every command, or the harness's working-directory
argument where one exists.

## Sync

Read applicable workspace and repository instructions. Inspect each checkout's status,
`git remote get-url origin`, local branches with upstreams, and
`git worktree list --porcelain`. Only use the corresponding `odasoft/*` origin.
Never access `client` or any `club-tijuana` remote, including fetch-all operations.
Preserve unrelated changes.

Run `git fetch --prune origin` in each repository and record the time of that fetch;
the receipt reports it. Independent repository fetches may run concurrently. Check
each exit status; retry sandbox, network, or socket failures with supported escalation
using the same command. A failed fetch blocks cleanup in that repository, not the
others.

Use `main` and `origin/main` for Bastion throughout the sync and verification steps;
use `develop` and `origin/develop` for the other repositories.

For a clean checkout with `origin/develop`, run `git switch develop` followed by
`git merge --ff-only origin/develop`. If local develop does not exist, use
`git switch --track -c develop origin/develop` instead. Check for an existing linked
worktree occupying develop before switching. Do not stash or discard dirty work.

Verify `git rev-list --left-right --count develop...origin/develop`; a successful
fast-forward command does not prove equality when develop is locally ahead.
Report ahead/diverged commits and ask before resetting or rebasing. An existing
commit elsewhere does not itself authorize resetting develop.

If the configured origin target is missing, ask for the intended branch instead of
creating a remote branch or inventing a base. The user has explicitly selected
main for Bastion; do not ask again merely because origin/develop is absent there.

## Classify every local branch

Protect `develop`, `main`, `master`, and any branch the user names. Ignore branches
tracking remotes other than origin. Every other local branch is a candidate, whether
or not its origin upstream still exists — a live upstream is not a reason to keep a
local ref, because origin holds that work either way.

Gather the pull request state and head commit for each candidate with
`gh pr list --repo odasoft/<repository> --head <branch> --state all --json
number,state,headRefName,headRefOid,author`. Pin `--repo` on every GitHub call:
several checkouts carry a `club-tijuana` remote named `client`, and an unpinned call
has read from it before.

Delete the local branch when any of these holds:

- Its tip is an ancestor of a freshly fetched origin integration branch (`develop`,
  `main`, or an existing `release/*`), verified with `git merge-base --is-ancestor`.
- Every commit `git cherry <integration-ref> <candidate>` reports is patch equivalent
  (a nonempty result containing only `-` lines).
- Its pull request state is `MERGED` **and** `git rev-parse <branch>` equals that pull
  request's `headRefOid`.
- Its pull request state is `CLOSED` and `git rev-parse <branch>` equals
  `git rev-parse origin/<branch>`.
- Its pull request state is `CLOSED`, its upstream was pruned, and `git rev-parse
  <branch>` equals the object ID that `git ls-remote origin refs/pull/<number>/head`
  reports. GitHub retains pull request head refs after the branch is deleted, so a tip
  that matches remains fetchable.
- It has no pull request and `git rev-parse <branch>` equals `git rev-parse
  origin/<branch>`. Origin holds the identical commit, so the local ref carries nothing.

Compare object IDs directly in every case. Do not infer equality from the `[gone]`
marker, from ahead/behind counts, or from pull request state alone.

Keep and report, never delete:

- Any branch with an `OPEN` pull request.
- **Stale tips.** Any branch whose pull request is `MERGED` or `CLOSED` but whose local
  tip does not match that pull request's head commit or the origin branch. Commits were
  added after the pull request closed and exist nowhere else. Report the branch, the
  pull request number, and how many commits are unpushed
  (`git rev-list --count <pr-head>..<branch>`).
- Any branch with no pull request, no integration proof, and a tip that exists nowhere
  on origin. This is genuinely unique local work; name it and say why it was kept.

Preserve uncertain squash or rewritten histories unless pull request state or another
source resolves them. Record the branch name, its old object ID, and the signal used
before each deletion. Use `git branch -d -- <branch>`; a `git branch -D -- <branch>`
is permitted only after independently verifying one of the signals above and that the
branch is still unoccupied and unchanged. Never bulk-delete every `[gone]` branch.
Do not expire reflogs, run aggressive GC, or delete unreachable objects.

## Clear obsolete worktrees

A linked worktree does not block deletion of its branch. Agent work leaves worktrees
behind routinely, and they are the main reason obsolete branches accumulate. For each
worktree reported by `git worktree list --porcelain`:

- **Dirty working tree** — never touch it, and never delete its branch. Report the
  path, the branch, and the count of modified files.
- **Clean, and its branch qualifies for deletion above** — `git worktree remove` it,
  then delete the branch.
- **Clean, and its branch is kept** — leave both in place.
- **Detached HEAD whose commit is an ancestor of an origin integration ref** — remove
  the worktree. `git worktree prune` never reaches these, because their paths exist.
- **Detached HEAD whose commit is on no integration ref** — keep and report the commit.

Also run `git worktree prune --verbose` to discard records for absent paths.

## Delete origin branches

Deleting a branch on GitHub is an outward action and is never part of the authorized
local cleanup. After the local pass, list the origin branches that qualify: the branch
was deleted locally and its pull request author is `disusered`. Never propose deleting
another author's origin branch — remove only the local copy of their work.

Present that list with each branch's pull request number and state, then wait for
explicit confirmation before running any `git push origin --delete`. Proceed with the
rest of the report if confirmation does not come.

## Verify and report

Verify the final branch, clean or dirty status, and ahead/behind counts against the
fetched origin target for every checkout. Report the number of deleted local branches,
removed worktrees, pruned refs and metadata, and retained exceptions with evidence.
Distinguish missing targets and locally ahead branches from successful synchronization.

State each repository's fetch time next to its ahead/behind counts. Commits merged
after that fetch make a synchronized repository look stale, and the timestamp is what
distinguishes elapsed time from a failed sync.

Write the receipt to `~/.local/state/xbol-branch-cleanup/<date>.md`, outside the source
repositories and outside `/tmp`, which does not survive a reboot. Record deleted branch
names with their old object IDs, removed worktree paths, and every retained branch with
its reason. Do not run builds or tests for Git-only maintenance, create commits, or push.
