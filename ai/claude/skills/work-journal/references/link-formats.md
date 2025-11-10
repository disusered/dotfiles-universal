# Link Formatting Reference

## Overview

When logging work to Markdown files, follow these exact markdown formats for linking to external resources.

**CRITICAL DISTINCTION:**
- **Main tickets** (the primary Jira/GitHub issues this work resolves) → Go in file FRONTMATTER (`Jira:`, `Github:`)
- **Related/discovered items** (other tickets, commits, code files found during work) → Go in file BODY using formats below

**DO NOT** create a "Related Tickets" section that just repeats the main issue from frontmatter.

**DO** link to discovered related items, specific commits, or code files in your work log.

## Reference Type Formats

### Jira Issues

**Format:**
```markdown
[<issue-id>](https://odasoftmx.atlassian.net/browse/<issue-id>)
```

**Examples:**
```markdown
[SYS-123](https://odasoftmx.atlassian.net/browse/SYS-123)
[PROJ-2110](https://odasoftmx.atlassian.net/browse/PROJ-2110)
```

**When to use:**
- Discovered related Jira issues during investigation
- Linked dependencies or blockers
- Historical context from previous tickets

**Pattern for construction:**
- Base URL: `https://odasoftmx.atlassian.net/browse/`
- Issue ID: Project key + hyphen + number (e.g., `SYS-123`)
- Always uppercase project key

### GitHub Issues

**Format:**
```markdown
[#<issue-number>](https://github.com/<user>/<repo>/issues/<issue-number>)
```

**Examples:**
```markdown
[#123](https://github.com/odasoftmx/app/issues/123)
[#456](https://github.com/odasoftmx/sistema-escolar/issues/456)
```

**When to use:**
- Discovered related GitHub issues
- Referenced issues in commits or PRs
- Cross-repo dependencies

**Pattern for construction:**
- Base URL: `https://github.com/`
- Repository path: `{user}/{repo}` (e.g., `odasoftmx/app`)
- Issue suffix: `/issues/{number}`

**IMPORTANT:** If repository is unknown, you MUST ASK the user for the full repository name before constructing the URL.

### GitHub Code References

**Format:**
```markdown
[<relative-path>#L<lines>](<full-url-to-file-at-commit-sha>)
```

**Examples:**
```markdown
[src/auth/login.js#L45-L67](https://github.com/odasoftmx/app/blob/a1b2c3d4e5f67890abcdef1234567890abcdef12/src/auth/login.js#L45-L67)
[lib/validation.py#L23](https://github.com/odasoftmx/sistema-escolar/blob/abcdef1234567890/lib/validation.py#L23)
```

**When to use:**
- Referencing specific code that was changed
- Pointing to problem code identified during investigation
- Documenting examples or patterns found in codebase

**Pattern for construction:**
- Display text: `{relative-path}#L{start-line}` or `{relative-path}#L{start}-L{end}` for ranges
- URL: `https://github.com/{user}/{repo}/blob/{full-commit-sha}/{relative-path}#L{lines}`
- Use FULL commit SHA (40 characters) for URL stability
- Use relative path from repository root

**How to get commit SHA:**
```bash
git rev-parse HEAD
```

### GitHub Commits

**Format:**
```markdown
[<short-sha>](<full-commit-url>)
```

**Examples:**
```markdown
[a1b2c3d](https://github.com/odasoftmx/app/commit/a1b2c3d4e5f67890abcdef1234567890abcdef12)
[3f4e5d6](https://github.com/odasoftmx/sistema-escolar/commit/3f4e5d6789abcdef0123456789abcdef01234567)
```

**When to use:**
- Referencing commits that introduced bugs
- Documenting fix commits
- Linking to related changes

**Pattern for construction:**
- Display text: First 7 characters of commit SHA
- URL: `https://github.com/{user}/{repo}/commit/{full-commit-sha}`
- Use full 40-character SHA in URL

**How to get commit info:**
```bash
# Get short SHA (for display)
git log -1 --format=%h

# Get full SHA (for URL)
git log -1 --format=%H
```

## URL Construction Workflow

### For Jira Issues

1. Extract issue ID from user input (e.g., "Jira 2110" → "2110")
2. If issue ID lacks project key, determine context:
   - Ask user for full ID if ambiguous
   - Use project context if clear
3. Construct: `https://odasoftmx.atlassian.net/browse/{ISSUE-ID}`

### For GitHub Issues

1. Extract issue number from user input (e.g., "#123" → "123")
2. Determine repository:
   - Check current git repository: `git remote get-url origin`
   - Ask user if unknown or different repo
3. Parse repository (e.g., `git@github.com:odasoftmx/app.git` → `odasoftmx/app`)
4. Construct: `https://github.com/{user}/{repo}/issues/{number}`

### For Code References

1. Get current commit SHA: `git rev-parse HEAD`
2. Get repository from git remote
3. Note the file path (relative to repo root) and line numbers
4. Construct:
   - Display: `{relative-path}#L{lines}`
   - URL: `https://github.com/{user}/{repo}/blob/{sha}/{path}#L{lines}`

### For Commit References

1. Get commit info: `git log -1 --format="%h %H"`
2. Get repository from git remote
3. Construct:
   - Display: `{short-sha}`
   - URL: `https://github.com/{user}/{repo}/commit/{full-sha}`

## Common Patterns

### Referencing a Bug Fix

```markdown
Fixed authentication bug discovered in [SYS-2110](https://odasoftmx.atlassian.net/browse/SYS-2110).

Root cause identified in [src/auth/oauth.js#L156-L178](https://github.com/odasoftmx/app/blob/abc123.../src/auth/oauth.js#L156-L178).

Applied fix in commit [3f4e5d6](https://github.com/odasoftmx/app/commit/3f4e5d6789...).
```

### Linking Related Work

```markdown
This issue is related to [#234](https://github.com/odasoftmx/app/issues/234) which addressed a similar problem in the payment flow.

The original implementation was added in [a7b8c9d](https://github.com/odasoftmx/app/commit/a7b8c9d012...).
```

### Documenting Investigation

```markdown
Investigated [PROJ-1500](https://odasoftmx.atlassian.net/browse/PROJ-1500) for context.

Found problematic pattern in [lib/validation.py#L45](https://github.com/odasoftmx/sistema-escolar/blob/def456.../lib/validation.py#L45).
```

## Validation Checklist

Before including a link in work log file:

- [ ] Is this a **discovered** item (not the main issue)?
- [ ] Main issue is already in file frontmatter?
- [ ] URL is complete and correctly formatted?
- [ ] For GitHub links, repository is known/confirmed?
- [ ] For code references, using full commit SHA in URL?
- [ ] For code references, using short display text with `#L{lines}`?
- [ ] Link text is descriptive (issue ID, file path, short SHA)?

## Error Prevention

**DON'T:**
- ❌ Put main Jira/GitHub issue in body (it goes in properties)
- ❌ Use partial URLs (e.g., `/browse/SYS-123`)
- ❌ Guess repository names
- ❌ Use branch names in code URLs (use commit SHAs for stability)
- ❌ Forget line numbers in code references
- ❌ Use long SHAs in display text (use short 7-char version)

**DO:**
- ✅ Link to discovered/related items in body
- ✅ Use full, absolute URLs
- ✅ Ask for missing repository information
- ✅ Use commit SHAs for code stability
- ✅ Include line numbers for code references
- ✅ Use short SHAs in display text for readability
