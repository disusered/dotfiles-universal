# Git Conventions

## Commit Messages
- Check and follow the existing commit style in the repository
- If no existing style, use Conventional Commits
- Limit to 80 characters
- No footers, signatures, or tool attribution
- Use imperative mood: "Add feature" not "Added feature"

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
