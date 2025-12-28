# GitHub Conventions

## Tool Usage
Always use `gh` CLI for GitHub operations. Do not use curl or web scraping.

## PR and Issue Modifications

**All write operations require user authorization:**
1. Compose the PR/issue content
2. **Post in chat for review**
3. Wait for explicit approval before submitting

This applies to:
- `gh pr create`
- `gh issue create`
- `gh issue comment`
- `gh pr comment`
- `gh pr review`

## PR Creation Workflow
1. Detect source branch
2. Determine target from gitflow conventions (see git-conventions.md)
3. **Post PR details in chat and ask permission**
4. Execute only after explicit approval

## Content Style
- Check existing PR/issue style in the repository
- Follow project's communication conventions
- No footers, signatures, or tool attribution
