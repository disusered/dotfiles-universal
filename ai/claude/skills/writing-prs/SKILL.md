---
name: writing-prs
description: Write or revise a GitHub pull request description. Use whenever opening a PR, editing a PR body, or being asked to "write up" / "describe" a change for review - including when the user just says "open a PR" or "push a PR" without mentioning the description. Also use when reviewing a PR body someone else drafted. Covers finding and following the repo's PR template, deciding what belongs in the body versus what GitHub already shows, and keeping the description readable by someone who was not in the conversation.
---

# Writing pull request descriptions

A PR description is read in a browser, next to the diff, by someone who was not in
your conversation. Most bad PR bodies fail one of those three facts: they repeat
what the diff already shows, they wrap like a terminal document, or they assume
context only the author has.

## Rule 0: the template wins

If the repo defines a PR template, it is authoritative. Use its sections, in its
order, in its language, every time. Everything else in this skill is subordinate:
those rules govern how you fill the template in, and what to do when there is no
template. They never justify dropping, renaming, reordering or "improving" a
section the template defines.

A template is the team's standing agreement about what reviewers want to see.
Preferences about PR style — yours, or the ones written below — do not override it.

Find it before writing anything:

```bash
ls .github/pull_request_template.md .github/PULL_REQUEST_TEMPLATE.md .github/PULL_REQUEST_TEMPLATE/ docs/pull_request_template.md 2>/dev/null
```

A Spanish template means a Spanish PR body. A template with a "Cambios
principales" section means your PR has one — see Rule 2 for what to put in it.

Templates ship with placeholder text: `Resolves #<número del issue>`, "Breve
descripción del cambio", example bullets. Fill every placeholder in, or take the
line out. Shipping one verbatim reads as a pasted form, and the reader cannot
tell whether you meant to leave it. When you genuinely cannot resolve one — you
have no issue number, or the remote is one you are not permitted to query —
remove the line and say so when you hand the body over, so the gap lands with the
person who can fill it rather than in the PR.

If there is no template, match the house style instead:

```bash
gh pr list --state merged --limit 10 --json title,body --jq '.[] | "=== \(.title)\n\(.body)\n"'
```

Read a few. Some repos want headings, some want two plain paragraphs. Follow what
merged PRs actually look like rather than inventing a format.

## Rule 1: write for someone who wasn't there

The reader has the diff, the repo, and the issue tracker. They do not have your
conversation, the requirements document you were handed, the review you ran, or
the numbering scheme you used while working.

So: no "§1.2 of the attached document", no "as discussed", no "the reviewer
found", no "requirement J2", no agent or session names. If a requirement drove the
change, say what it asks for in plain product language and link the issue so the
reader can go read it themselves.

Lead with the issue link. One line like
`Fixes [XBS-382](https://odasoftmx.atlassian.net/browse/XBS-382)` gives the reader
everything the internal shorthand was reaching for.

## Rule 2: explain what the diff cannot

The Files changed tab already lists every file and line, highlighted, with comment
threads. Prose that re-lists them is a worse copy of the tool the reader is already
looking at.

Spend the body on what the diff genuinely cannot show:

- The problem. What was broken or missing, and how it showed up.
- Why this fix rather than another — especially when you touched something shared,
  added a flag, or deliberately left something alone.
- Consequences a reviewer would not predict: behaviour that changes for existing
  data, an ordering dependency between PRs, a screen that now renders differently.

This is the test for a changes section. When the template defines one, write it —
filled with that kind of reasoning, grouped by intent rather than by file. When
no template defines one, only add it if you have that reasoning to give; otherwise
the diff covers it.

## Rule 3: do not hard-wrap

Commit messages wrap at 72 characters because git shows them in a terminal. A PR
body is markdown rendered in a browser; it is not stored in git and never read with
`git log`. Hard wrapping produces ragged text that reflows badly at every screen
width. Write full-length lines and let the browser wrap.

## Rule 4: leave out test and build evidence

Unless the template asks for it or the user asks for it on this PR, skip
"Validation", "Verification", "Testing" and "How to test" sections, and do not
paste build output or pass counts. CI reports status on the PR itself. If a test
detail genuinely affects review — a suite that cannot run, a deliberately updated
assertion — make it one sentence in the body, not a section.

## Rule 5: length

Most PRs need the issue link and one to three paragraphs. Reach for headings when
the template defines them, or when the change is large enough that a reviewer
would otherwise lose the thread. A short PR body is not lazy; it means the diff is
doing its job.

## Before submitting

Present the destination and content together — source branch, target branch, title
and full body — and get agreement before running `gh pr create`. Reuse that
approval if the proposal is unchanged.

## Example

Same change, written twice for a repo with no template.

**Weak** — restates the diff, references invisible context, hard-wrapped:

```
## What and why

Sponsor images could be uploaded for events but not for season passes.
`BundleMediaService` excluded `Sponsor` from `ManagedMediaTypes`, so the
reconcile endpoint rejected sponsor items. Requirement §1.2 of the attached
document calls this a new end-to-end requirement.

## Changes

- `BundleMediaService.cs`: add `AdminMediaType.Sponsor` to `ManagedMediaTypes`
- `BundleMediaService.cs`: call `ValidateZeroBasedOrders` for sponsors
- `BundleMediaService.cs`: project sponsors in `CreateMediaSet`
- `BundleService.cs`: include `Sponsor` in the media query
- `BundleMediaServiceTests.cs`: add four tests
```

**Better** — links the issue, explains the gap and the judgement call, trusts the diff:

```
Part of [XBS-368](https://odasoftmx.atlassian.net/browse/XBS-368). Land before the admin portal PR, which depends on this contract.

Sponsor logos could be uploaded for an event but not for a season pass or package: bundle media reconciliation silently rejected sponsor items and both read paths returned an empty list, so the season pass page on the website had nothing to show.

Bundle media now handles sponsors the same way event media already does, which leaves the two services functionally identical apart from naming. That matters for review: a sponsor row the form does not know about is now retired on the next save, exactly as it already is for events.
```

The second is shorter, and every sentence tells the reviewer something the diff cannot.
