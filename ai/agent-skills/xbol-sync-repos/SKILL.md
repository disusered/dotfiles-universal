---
name: xbol-sync-repos
description: Fetch and prune the club-tijuana `client` remote, preserve unfinished work in signed local WIP commits, switch XBOL repositories to their baseline branch, fast-forward them, and clear recoverable obsolete local branches and worktrees. Use when asked to sync or clean the XBOL checkouts.
---

Maintain these existing checkouts under `/home/carlos/Development/XBOL`:

| Checkout             | Remote   | GitHub repository              | Baseline |
| -------------------- | -------- | ------------------------------ | -------- |
| `xbol-api-admin`     | `client` | `club-tijuana/xbol-api-admin`     | `dev`    |
| `xbol-api-ticketing` | `client` | `club-tijuana/xbol-api-ticketing` | `dev`    |
| `xbol-api-client`    | `client` | `club-tijuana/xbol-api-client`    | `dev`    |
| `xbol-web-client`    | `client` | `club-tijuana/xbol-web-client`    | `dev`    |
| `xbol-web-admin`     | `client` | `club-tijuana/xbol-web-admin`     | `dev`    |
| `xbol-db-develop`    | `client` | `club-tijuana/xbol-db`            | `main`   |
| `xbol-bastion`       | `origin` | `odasoft/xbol-bastion`            | `main`   |

`client` (`club-tijuana/*`) is the main remote. `origin` (`odasoft/*`) is deprecated;
Bastion is the only exception, because `club-tijuana/xbol-bastion` is still empty.
In the rest of this skill, "the remote" means the checkout's remote from the table.

**Main-based repositories.** A repository whose remote has no `dev` branch, such as
`xbol-db`, is main-based: its baseline is `main` and its integration refs are
`<remote>/main` and `<remote>/release/*`. That is a normal state, not a missing target.
Do not ask about it, create a `dev` branch, or look for `develop`.

An invocation to run this maintenance authorizes fetching and pruning the remote,
signed local WIP commits on preservation branches, checkout switches, fast-forward
updates, removal of obsolete worktrees and worktree metadata, and deletion of obsolete
local branches whose work is recoverable.
It does not authorize deleting any branch on GitHub; that requires the separate
confirmation described under "Delete remote branches". A standalone skill-edit
request does not authorize a maintenance run. When a skill repair is part of an
already-authorized incomplete sync, carry that authorization forward; do not treat
the edit as completion of the sync. Honor a user's instruction to limit work to the
skill or its isolated tests.

Use `git -C <repository>` for every command, or the harness's working-directory
argument where one exists.

## Sync

Read applicable workspace and repository instructions. Inspect each checkout's status,
`git remote get-url <remote>`, local branches with upstreams, and
`git worktree list --porcelain`. Confirm the remote URL points at the repository in the
table. Fetch only that remote: never fetch `origin` for a `client` checkout, and never
use fetch-all operations. Preserve unrelated changes.

Run `git fetch --prune <remote>` in each repository and record the time of that fetch;
the receipt reports it. Independent repository fetches may run concurrently. Check
each exit status; retry sandbox, network, or socket failures with supported escalation
using the same command. A failed fetch blocks cleanup in that repository, not the
others.

### Preserve dirty work with WIP commits

A dirty checkout is work to preserve and then synchronize, not a reason to skip the
repository. Inspect staged, unstaged, and untracked files, then create a signed local
WIP commit before switching branches. Do not create another worktree or stash.

- On an existing feature, hotfix, release, or other unprotected work branch, commit
  the unfinished changes on that branch and keep its ref.
- On `dev`, `main`, `master`, legacy `develop`, or detached HEAD, first create a
  preservation branch at the current HEAD. Follow workspace Git Flow naming; use
  `feature/<issue-key>-wip-<description>` when the issue is known, otherwise
  `feature/wip-<description>-<timestamp>`. Inspect refs and choose an unused name.
  Keep the baseline or legacy ref unchanged.
- Preserve all existing commit-worthy changes, including untracked source files.
  Inspect the diff and file list before staging. Honor repository exclusions for
  credentials, production data, generated output, and other prohibited artifacts;
  never force-add ignored files or discard excluded changes to get a clean status.
  If such files prevent completion, report the exact unresolved paths and required
  decision rather than silently skipping the repository.
- Stage the inspected paths and use an imperative message such as
  `chore: preserve WIP on ticket database indexes`, at most 80 characters. This is
  a preservation snapshot: do not rewrite the implementation or claim it is ready
  to merge. Run required commit checks and preserve existing hooks.
- Use `git commit -S` and verify the new commit with `git verify-commit HEAD`.
  A repository with `.jj` uses its documented signed Jujutsu workflow instead.
  Apply the execution recovery rules to signing or sandbox failures; preserve the
  configured signing backend. Failed signing or verification leaves the task
  incomplete.
- Record the branch, old HEAD, WIP commit ID, and preserved paths in the receipt.
  Confirm the snapshot includes the inspected changes and the checkout is clean
  before switching. If a hook changes files, account for and preserve those changes
  too. Protect every WIP preservation branch from this run's deletion pass, even if
  another integration proof would normally qualify it. Keep WIP commits local.

Apply this procedure to dirty base checkouts and dirty existing linked worktrees.
Existing worktrees with preserved unique work follow the retention rules below;
creating a new worktree is not part of preservation.

### Switch and fast-forward

Once the base checkout is clean, run `git switch <baseline>` followed by
`git merge --ff-only <remote>/<baseline>`. If the local baseline branch does not
exist, use `git switch --track -c <baseline> <remote>/<baseline>` instead.

If a linked worktree occupies the baseline, preserve any dirty work there first.
Release the baseline by detaching that linked worktree at its preserved HEAD, then
remove the clean auxiliary worktree so the base checkout can switch to the baseline.
Retain every preservation branch and unique commit; create a preservation branch
before removing a detached worktree whose HEAD otherwise has no retained local ref.
Record the removed path and retained commit. Never remove the base checkout.

Verify `git rev-list --left-right --count <baseline>...<remote>/<baseline>`; a
successful fast-forward command does not prove equality when the baseline is locally
ahead. Report ahead/diverged commits and ask before resetting or rebasing. An existing
commit elsewhere does not itself authorize resetting the baseline.

If the table's baseline is missing on the remote and the repository is not main-based,
ask for the intended branch instead of creating a remote branch or inventing a base.

## Classify every local branch

Protect `dev`, `main`, `master`, any branch the user names, and all WIP preservation
branches created or committed on during this run. Also protect a leftover
local `develop` from the odasoft era: do not sync, reset, or delete it; report its
object ID so the user can decide. Every other local branch is a candidate, whether it
tracks the remote, tracks `origin`, or has no upstream — a live upstream is not a
reason to keep a local ref, because the remote holds that work either way.

Gather the pull request state and head commit for each candidate with
`gh pr list --repo <github-repository> --head <branch> --state all --json
number,state,headRefName,headRefOid,author`, using the repository from the table. Pin
`--repo` on every GitHub call: checkouts still carry the deprecated `origin`, and an
unpinned call can read from the wrong repository.

The integration refs are the freshly fetched `<remote>/dev` (where it exists),
`<remote>/main`, and existing `<remote>/release/*`. Delete the local branch when any of
these holds:

- Its tip is an ancestor of an integration ref, verified with
  `git merge-base --is-ancestor`.
- Every commit `git cherry <integration-ref> <candidate>` reports is patch equivalent
  (a nonempty result containing only `-` lines).
- Its pull request state is `MERGED` **and** `git rev-parse <branch>` equals that pull
  request's `headRefOid`.
- Its pull request state is `CLOSED` and `git rev-parse <branch>` equals
  `git rev-parse <remote>/<branch>`.
- Its pull request state is `CLOSED`, its upstream was pruned, and `git rev-parse
  <branch>` equals the object ID that `git ls-remote <remote> refs/pull/<number>/head`
  reports. GitHub retains pull request head refs after the branch is deleted, so a tip
  that matches remains fetchable.
- It has no pull request and `git rev-parse <branch>` equals `git rev-parse
  <remote>/<branch>`. The remote holds the identical commit, so the local ref carries
  nothing.

Compare object IDs directly in every case. Do not infer equality from the `[gone]`
marker, from ahead/behind counts, or from pull request state alone.

Keep and report, never delete:

- Any branch with an `OPEN` pull request.
- **Stale tips.** Any branch whose pull request is `MERGED` or `CLOSED` but whose local
  tip does not match that pull request's head commit or the remote branch. Commits were
  added after the pull request closed and exist nowhere else. Report the branch, the
  pull request number, and how many commits are unpushed
  (`git rev-list --count <pr-head>..<branch>`).
- **Legacy odasoft work.** A branch that tracks `origin` and has no proof against the
  remote's integration refs or pull requests. Do not fetch `origin` to prove it; name
  it and say it predates the move to `club-tijuana`.
- Any branch with no pull request, no integration proof, and a tip that exists nowhere
  on the remote. This is genuinely unique local work; name it and say why it was kept.

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

- **Dirty working tree** — preserve its changes with the WIP procedure above, then
  classify the clean worktree. Keep its WIP branch and unique work. If preservation
  cannot finish, retain the worktree and branch and report maintenance as incomplete.
- **Clean, and its branch qualifies for deletion above** — `git worktree remove` it,
  then delete the branch.
- **Clean, and its branch is kept** — leave both in place.
- **Detached HEAD whose commit is an ancestor of an integration ref** — remove the
  worktree. `git worktree prune` never reaches these, because their paths exist.
- **Detached HEAD whose commit is on no integration ref** — keep and report the commit.

Also run `git worktree prune --verbose` to discard records for absent paths.

## Delete remote branches

Deleting a branch on GitHub is an outward action and is never part of the authorized
local cleanup. After the local pass, list the remote branches that qualify: the branch
was deleted locally and its pull request author is `disusered`. Never propose deleting
another author's remote branch — remove only the local copy of their work. Never
propose deletions on the deprecated `origin` for a `client` checkout.

Present that list with each branch's repository, pull request number, and state, then
wait for explicit confirmation before running any `git push <remote> --delete`.
Proceed with the rest of the report if confirmation does not come.

## Completion, verification, and report

Maintenance is complete only when all of these hold:

- Every managed repository has a successful fetch from its authorized remote,
  with the fetch time recorded.
- Every base checkout is on its configured baseline and
  `git status --porcelain` returns no entries.
- Every baseline equals the fetched remote baseline:
  `git rev-list --left-right --count <baseline>...<remote>/<baseline>` returns `0 0`.
- All unfinished work is preserved in verified signed local WIP commits on retained
  branches, and each WIP commit and branch is recorded in the persistent receipt.
- Every local branch and existing linked worktree has been classified; recoverable
  obsolete local branches and worktrees have been removed, with retained exceptions
  explained. Unique or active work retained on another branch does not block completion.
- The persistent receipt has been written successfully.

A dirty base checkout, wrong current branch, failed or unauthorized fetch, failed WIP
preservation, occupied baseline, or ahead/diverged/behind baseline means maintenance
is incomplete. Continue all independent authorized work, resolve recoverable failures,
and report the remaining repository, observed blocker, and smallest required action.
A list of exceptions does not make an unfinished synchronization complete. Remote
branch deletion is a separate approval-gated action and does not block local completion.

Verify the final branch, clean or dirty status, and ahead/behind counts against the
fetched baseline for every checkout. Report each repository's remote and baseline so a
main-based repository reads as normal. Report the number of deleted local branches,
removed worktrees, pruned refs and metadata, and retained exceptions with evidence.
Distinguish missing targets and locally ahead branches from successful synchronization.

State each repository's fetch time next to its ahead/behind counts. Commits merged
after that fetch make a synchronized repository look stale, and the timestamp is what
distinguishes elapsed time from a failed sync.

Write the receipt to `~/.local/state/xbol-branch-cleanup/<date>.md`, outside the source
repositories and outside `/tmp`, which does not survive a reboot. Record deleted branch
names with their old object IDs, removed worktree paths, and every retained branch with
its reason. Include WIP preservation branches, commit IDs, paths, and signature
verification results. Do not run builds or tests solely for Git maintenance beyond
required commit checks. Create only the authorized local WIP commits; push only
explicitly authorized remote branch deletions.

## Validate workflow changes

When changing WIP preservation or completion behavior, test the revised skill by
executing it in isolated Git repositories before reporting the repair as verified.
A frontmatter validator, a text review, or manually repairing a live checkout does
not demonstrate that the revised skill completes the workflow.

Cover dirty feature, dirty baseline, and dirty detached checkouts with staged,
unstaged, and untracked files, plus an ahead/diverged baseline. Check the resulting
Git state: exact file contents preserved in retained signed WIP commits, clean base
checkouts on equal fetched baselines, no new worktrees or stashes, and no rewritten
history. The diverged case must remain incomplete with its unique commits intact.
Check that the receipt records the result and preservation evidence. Restrict test
remotes and all mutations to fixtures; use the installed skill's procedure, not a
separate repair script. Report which cases actually ran and any failed checks.
