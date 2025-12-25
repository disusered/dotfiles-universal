---
name: managing-git
description: Git operations with safety rules and gitflow targeting. Use when performing git commands, especially destructive operations like rebase, reset, force push, or when determining PR branch targets. CRITICAL - Always requests permission for destructive operations.
allowed-tools: Bash
---

# Managing Git

Git operations with critical safety rules and gitflow branch targeting for pull requests.

## When to Use This Skill

Load this skill when:

- **Performing destructive git operations** (rebase, reset, force push, branch deletion)
- **Determining PR branch targets** (gitflow conventions)
- **Committing changes** (message guidelines, no footers)
- **Creating pull requests** (requires gitflow targeting from this skill + managing-github skill)

**Integration:** Works with `managing-github` skill for PR creation. This skill provides gitflow targeting, managing-github handles the `gh pr create` command.

## Critical Safety Rules

**Destructive operations require explicit user permission:**
- `git rebase`
- `git reset --hard`
- `git push --force`
- `git cherry-pick`
- Branch deletion
- Amending shared commits

**Gitflow branch targeting:**
```
hotfix/*    → main
feature/*   → develop
release/*   → main
bugfix/*    → develop
```

Always confirm branch targets with user before creating PRs.

## Common Safe Operations

### Viewing Status and History

```bash
git status                          # Check working tree status
git log --oneline -n 10            # View recent commits
git log --graph --all              # View branch history
git diff                           # View unstaged changes
git diff --cached                  # View staged changes
git show <commit>                  # View specific commit
```

### Staging and Committing

```bash
git add <file>                     # Stage specific file
git add .                          # Stage all changes
git commit -m "message"            # Commit with message (80 char limit)
```

**Commit Message Guidelines:**

- Limit to 80 characters
- **NEVER add footers or signatures** (no "Generated with Claude Code", no robot emojis)
- Use imperative mood: "Add feature" not "Added feature"
- Be specific and concise

### Branching

```bash
git branch                         # List local branches
git branch -a                      # List all branches (local + remote)
git checkout -b <branch-name>      # Create and switch to new branch
git checkout <branch-name>         # Switch to existing branch
git branch --show-current          # Show current branch name
```

### Remote Operations

```bash
git fetch                          # Fetch remote changes
git pull                           # Fetch and merge
git push                           # Push to remote (safe)
git push -u origin <branch>        # Push new branch with tracking
```

**NEVER use `git push --force` without explicit permission.**

### Inspecting Changes

```bash
git show-branch                    # Show branch relationships
git log <file>                     # View file history
git blame <file>                   # Show line-by-line authorship
git diff <branch1>..<branch2>      # Compare branches
```

## Integration with managing-github

When creating pull requests:

1. **This skill (managing-git)** determines the target branch using gitflow conventions
2. **Confirm target with user** before proceeding
3. **managing-github skill** handles the actual `gh pr create` command

Both skills must be loaded for PR creation workflows.

## Reference

For complete git command reference and advanced operations, see:
- `REFERENCE.md` (complete command guide)
- Official Git documentation: https://git-scm.com/doc
