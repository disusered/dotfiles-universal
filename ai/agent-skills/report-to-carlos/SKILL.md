---
name: report-to-carlos
description: Use before reporting back on delegated or long-running work — a release, a migration, an investigation, a batch of PRs, or any turn that ends with "here is what happened". Also use when handing a blocker back, when a permission or approval gate stops you, or when a session ends with work unfinished. Replaces narrative status reports with a blocker-first handoff.
---

# Reporting back

Carlos reads reports to decide what to do next. Everything that does not serve that
decision is noise he has to skim past. Three sections, in this order, and nothing else.

## 1. Blocked

If anything is stopping, this goes first and nothing precedes it.

State what is blocked, then give the exact thing that unblocks it — a command he can paste
after `!`, a URL he can click, or a decision with the real options spelled out. Test the
command before you print it. A wrong command wastes a round trip and reads as carelessness.

If nothing is blocked, omit the section. Do not write "no blockers".

## 2. Landed

One line per artifact, with the identifier that lets him find it: a PR URL, a commit SHA, a
published version, an issue key and its new status. Group by repository when there is more
than one.

Verification evidence belongs here, compressed to the number that matters — "30/30 tests",
"validate clean over 51 concepts". Not the command you ran, not the log, not the reasoning.

## 3. Next

Only work that continues the job in hand. If the job is finished, say so and stop.

Never list unrelated findings here. A red pipeline in another repository, a stale document
you noticed, an architectural question you formed an opinion about — those are separate
conversations, and raising them inside a status report reads as changing the subject before
closing the current thing.

## Never

- **Trivia framed as insight.** "Worth knowing", "one thing I hit", "for future reference".
  If it does not change what he does, cut it.
- **Process narration.** What you tried, what you considered, which tool you reached for,
  how long something took.
- **Restating the plan.** He approved it. He knows what it says.
- **Segues.** Do not pivot to a new topic in the same message that closes an old one.
- **Asking permission you already have.** An approval covers the job through to completion.
  See the memory note `one-approval-covers-the-whole-job`.
- **Padding an actionable with prose.** "You may want to consider whether it would make
  sense to…" is not an actionable. "Run this: `<command>`" is.

## Ending a session with work unfinished

Same three sections, plus the state a fresh agent needs to resume: which branches exist and
where they point, what is committed versus pushed, which working copies are dirty. Point at
paths and SHAs. Do not restate content that already lives in a plan file, a PR body, an ADR,
or a commit message — reference it.
