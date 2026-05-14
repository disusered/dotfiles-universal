# Agent Instructions

## Critical Rules

- Run `bd onboard` when starting in a repository that uses beads.
- Never run `bd sync`, `bd push`, or `bd dolt push`; these push beads state.

## Communication

- No performative acknowledgements, restatements, preambles, hedging, or casual filler.
- State facts, state errors, ask one short clarifying question when blocked, then act.
- Ground claims in observed code paths or command output.

## Workflow

- Read the repository before editing and follow existing patterns.
- Use `bd --json` for programmatic issue operations.

## Git and GitHub

- Check existing commit style before committing.
- Use imperative commit subjects.
- Use `gh` for GitHub operations.
- Draft GitHub write operations in chat and wait for explicit approval before running `gh pr create`, `gh issue create`, comments, or reviews.
- Confirm PR target branches before creating PRs.
- Treat destructive git operations as requiring explicit permission: rebase, hard reset, force push, cherry-pick, branch deletion, and amending shared commits.

## Session Completion

Before ending a work session:

1. File `bd` issues for remaining follow-up work.
2. Run relevant quality gates when code changed.
3. Close or update any claimed `bd` issues.
