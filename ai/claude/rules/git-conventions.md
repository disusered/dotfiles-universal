# Git Conventions

## Commit Messages

- Check and follow the existing commit style in the repository
- If no existing style, use Conventional Commits
- Limit to 80 characters
- No footers, signatures, or tool attribution
- Use imperative mood: "Add feature" not "Added feature"
- Use `git commit -S` for agent-created commits
- Verify agent-created commits with `git verify-commit HEAD`

## Branch Names and Targeting

- Follow the repository's documented branch convention when one exists
- Otherwise use GitFlow-style names in the form `<type>/<lowercase-kebab-case-description>`
- Use only these fallback types: `feature`, `bugfix`, `hotfix`, and `release`
- Never invent or add tool or agent identity prefixes such as `agent/`, `claude/`, `codex/`, or `copilot/`
- Describe the work in the branch name, not the actor performing it
- Inspect existing local and remote branches and identify the default branch before creating a branch or choosing a PR target
- Target `develop` from `feature/*` and `bugfix/*` only when the repository actually has and uses `develop`; otherwise target the default branch
- Target the production branch, usually `main`, from `hotfix/*` and `release/*`

Always confirm branch targets with user before creating PRs.

## Destructive Operations

**Require explicit user permission:**
- `git rebase`
- `git reset --hard`
- `git push --force`
- `git cherry-pick`
- Branch deletion
- Amending shared commits

## Remote Operations

- Do not run `git pull`, `git pull --rebase`, or `git push` as routine cleanup.
- Run remote git operations only when the user explicitly asks.
