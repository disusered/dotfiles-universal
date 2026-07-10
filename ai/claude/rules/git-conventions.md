# Git Conventions

## Commit Messages
- Check and follow the existing commit style in the repository
- If no existing style, use Conventional Commits
- Limit to 80 characters
- No footers, signatures, or tool attribution
- Use imperative mood: "Add feature" not "Added feature"
- Use `git commit -S` for agent-created commits
- Verify agent-created commits with `git verify-commit HEAD`

## Branch Targeting (Gitflow)
```
hotfix/*    → main
feature/*   → develop
release/*   → main
bugfix/*    → develop
```

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
