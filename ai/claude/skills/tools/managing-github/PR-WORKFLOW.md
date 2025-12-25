# Pull Request Workflow

Step-by-step workflow for creating pull requests with git flow branch targeting validation.

## PR Creation Checklist

Copy this checklist when creating a PR:

```
PR Creation Progress:
- [ ] Step 1: Detect source branch (git branch --show-current)
- [ ] Step 2: Determine target from gitflow rules
- [ ] Step 3: ASK USER: "Source: X, target: Y. Correct?"
- [ ] Step 4: Wait for user confirmation
- [ ] Step 5: Request permission for gh pr create
- [ ] Step 6: Execute gh pr create with confirmed target
```

## Step 1: Detect Source Branch

```bash
# Get current branch
git branch --show-current
```

## Step 2: Determine Target Branch

Use the gitflow table to determine the correct target:

| Source Branch Pattern | Target Branch |
|----------------------|---------------|
| `hotfix/*` | `main` (or `master` if main doesn't exist) |
| `feature/*` | `develop` |
| `release/*` | `main` (or `master` if main doesn't exist) |
| `bugfix/*` | `develop` |
| `claude/*` | **Ask user for target branch** |

### Examples

```
Source: feature/add-login → Target: develop
Source: hotfix/security-fix → Target: main
Source: release/v1.0.0 → Target: main
Source: bugfix/null-check → Target: develop
Source: claude/refactor-api → Target: ??? (ask user)
```

## Step 3: Confirm With User

**ALWAYS ask the user to confirm branch targeting before proceeding.**

Example confirmation request:
```
Detected source branch: feature/add-oauth
Determined target: develop (from gitflow rules)

Is this correct?
```

Wait for confirmation, then proceed to Step 4 or update target if incorrect.

## Step 4: Wait for Confirmation

Do not proceed with Step 5 until user explicitly confirms.

## Step 5: Request Permission

**ALL `gh pr create` commands require user permission.**

Example permission request:
```
Ready to create PR:
- Title: "Fix OAuth token validation"
- Base: develop
- Head: feature/add-oauth

May I proceed with gh pr create?
```

Wait for approval before proceeding to Step 6.

## Step 6: Execute gh pr create

Once confirmed and approved, execute the command:

```bash
gh pr create --title "<title>" --body-file <file> --base <target>
```

### Common Options

```bash
# With body from file
gh pr create --title "Fix bug" --body-file pr-description.md --base develop

# With inline body
gh pr create --title "Add feature" --body "Description here" --base develop

# As draft
gh pr create --title "WIP: Refactor" --draft --base develop

# With labels
gh pr create --title "Fix" --base develop --label bug --label priority
```

## Human-in-Loop Feedback

The workflow has **two** human confirmation points:

### Confirmation 1: Branch Targeting
**Why**: Wrong target can break production

**When**: After detecting source/target but BEFORE executing gh pr create

**Question**: "Detected source: X, target: Y. Is this correct?"

### Confirmation 2: Command Permission
**Why**: Write operations require approval

**When**: After branch confirmation but BEFORE executing gh pr create

**Question**: "Ready to create PR... May I proceed?"

## Error Handling

### Wrong Target Detected

If user says target is wrong:

```
User: "No, target should be main, not develop"
```

Update target and re-confirm:

```
Updated target: main

Is this correct now?
```

### Not Ready to Create PR

If user says not ready:

```
User: "Wait, I need to update the PR description first"
```

Stop and wait for user to indicate ready:

```
Understood. Let me know when you're ready to create the PR.
```

### Git Operations Needed

If user says code isn't committed:

```
User: "I haven't committed yet"
```

Remind user to commit first:

```
Please commit and push your changes first. Then I can create the PR.
```

## Integration with work-journal Skill

For PR descriptions from work logs:

1. Use work-journal skill to generate PR description
2. Save to temp file (e.g., `/tmp/pr-description.md`)
3. Follow PR creation checklist
4. Use `--body-file /tmp/pr-description.md` in gh pr create

## Common Mistakes

Avoid:
- Creating PR without confirming branch target
- Creating PR without user permission
- Running git commit/push (assume already done)
- Adding footers or signatures to PR body
- Targeting wrong branch from gitflow
