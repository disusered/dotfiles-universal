## 🏠️ Baseline rules

- `cd` is not the default command, it is zoxide via `eval "$(zoxide init --cmd cd zsh)"`
- Use the shell's `builtin cd` to change directories, zoxide-bound `cd` will fail.
- `ls` is not the default command, it is bound to `exa`
- Commit messages should be limited to 80 characters in length

## ⚡ Core Directives: Work Tracking

**IMPORTANT**: This project uses **Markdown files** for ALL work and issue tracking.

**LANGUAGE RULE**: ALL work logs, planning files, and internal communication MUST be in **ENGLISH**. Spanish is ONLY for external-facing artifacts (PR descriptions, manager summaries, stakeholder updates) created via the work-journal skill.

### When to Track Work (PROACTIVE)

**AUTOMATICALLY create a work log file BEFORE starting ANY of these tasks:**

- Investigation/debugging (multi-step)
- Feature development
- Bug fixes
- Code refactoring
- Any work requiring multiple commands/steps

**You MUST create the file BEFORE executing commands, not after.**

### Creating the Work Log File

1. **Check if file already exists (avoid duplicates):**
   - Search `dev/active/` for existing work logs by Jira/GitHub issue IDs
   - **Canonical identifiers**: Jira issue # and GitHub issue # are authoritative
   - If file exists for the issue: UPDATE it, don't create new
   - If no issue IDs: Search by similar title, but prefer creating new

2. **Gather required properties:**
   - **Priority** (0-4): Ask user if not clear from context
   - **Project**: Ask user which team/project this belongs to
   - **Type**: Infer from context or ask (bug/feature/task/epic/chore)
   - **Jira** (optional): Ask "Is there a Jira issue for this?" if not mentioned (blank is OK)
   - **Github** (optional): Ask if not mentioned, ask for repo if needed

3. **Generate clean filename (avoid redundancy):**
   - Extract issue number from GitHub/Jira if present
   - Use kebab-case: `fix-categorias-ordenar.md`
   - Keep filename concise and descriptive
   - Don't include issue numbers in filename (they're in frontmatter)

4. **If Priority, Project, or Type missing: STOP and ASK the user**

5. **Create file using Write tool:**

   ```markdown
   # [Brief description]

   **Status:** In Progress
   **Priority:** 0-4
   **Project:** Team/Project name
   **Type:** bug|feature|task|epic|chore
   **Jira:** https://odasoftmx.atlassian.net/browse/ID (optional)
   **Github:** https://github.com/user/repo/issues/NUM (optional)
   **Created:** [timestamp from TZ='America/Tijuana' date '+%Y-%m-%d %H:%M']

   ---

   ## Work Log

   Starting work...
   ```

6. **Save to:** `dev/active/{filename}.md`

### Logging Behavior (CONTINUOUS)

**After creating the file, log continuously using Edit or Write:**

- **Log THINKING, not DOING** - focus on decisions, discoveries, and reasoning
- **Append after EVERY significant action** - don't batch at the end
- **Use real timestamps** from `TZ='America/Tijuana' date '+%Y-%m-%d %H:%M'` before EACH append
- **Chronological only** - ALWAYS append to end, NEVER restructure

**What to Log:**

- Approaches attempted and WHY chosen
- Failures and root cause analysis
- Decisions made and reasoning
- Technical insights/discoveries
- Alternative approaches considered and WHY rejected
- Code snippets ONLY IF explanatory (showing bug logic, design pattern)

**What NOT to Log (Busywork):**

- Commit message writing/editing/rewriting
- PR text revisions
- Git operations (push, pull, checkout, branch, merge, rebase, add, etc.)
- File saves, basic file edits
- Running tests (only log significant RESULTS)
- Installing dependencies
- Formatting code
- Any information available in Git/GitHub/Jira logs

**Philosophy:** Document DECISIONS and DISCOVERIES, not ACTIONS. If it's in git history, DON'T duplicate it.

**Entry Format:**

```markdown
### [Descriptive entry name - NO metadata like dates/issue#s]

**Timestamp:** [from TZ='America/Tijuana' date '+%Y-%m-%d %H:%M']

**Context:** [What you were investigating]

**Finding/Decision:** [What you discovered/decided and WHY]

**Notes:** [Implications, next steps]
```

### Completing Work

**When to mark as "Done":**

- ✅ Work is fully complete AND merged (or no PR needed)
- ❌ NOT when PR is created (work is still In Progress until merged)
- ❌ NOT when code is committed but not merged

**Marking complete:**

1. Append final summary to work log file
2. Update Status field to "Done" in the file
3. Move file from `dev/active/` to `dev/completed/`
4. Respond ONLY with: `✅ Task complete. The work has been logged to: dev/completed/{filename}.md`
5. **DO NOT print the work summary** - it's already in the file

### Required Properties

- **Priority** (0-4): 0=Critical, 1=High, 2=Medium, 3=Low, 4=Backlog
- **Project** (string): Team or project name
- **Type** (enum): `bug`, `feature`, `task`, `epic`, or `chore`

**GitHub and Jira prompts:**

- **Ask if not known/mentioned**: "Is there a Jira/GitHub issue for this?"
- If user already mentioned issue number in context, don't re-ask
- Blank/empty answers are acceptable - just omit from frontmatter
- If GitHub issue provided, MUST ask for repo (user/repo format)

### Work Log Directories

- **Active work:** `dev/active/` - All in-progress work logs
- **Completed work:** `dev/completed/` - Finished and merged work
- **Artifacts:** `dev/artifacts/` - PR descriptions, summaries, stakeholder updates

---

### Specialized Outputs (Use Skills)

For PR descriptions, manager summaries, or stakeholder updates:

- **Invoke the `work-journal` skill** and specify the workflow
- These require templates, iteration, and approval
- See `~/.claude/skills/work-journal/` for details

## 🔧 Tools

### acli

Official Atlassian CLI for Jira work items and comments.

**Work Items:**

- `acli jira workitem create --summary "Task" --project "KEY" --type "Task"` - Create work item
- `acli jira workitem view --key "KEY-123"` - View work item details
- `acli jira workitem edit --key "KEY-123" --summary "New summary"` - Edit work item
- `acli jira workitem transition --key "KEY-123" --status "In Progress"` - Transition status

**Comments:**

- `acli jira workitem comment create --key "KEY-123" --body "Comment text"` - Add comment
- Use `--help` on any command for full options

### gh

GitHub CLI for issues and pull requests.

**Issues:**

- `gh issue list` - List issues
- `gh issue view <number>` - View issue details
- `gh issue comment <number>` - Add comment to issue
- `gh issue edit <number> --add-label <label>` - Add labels
- `gh issue edit <number> --remove-label <label>` - Remove labels

**Pull Requests:**

- `gh pr list` - List PRs
- `gh pr view <number>` - View PR details
- `gh pr create` - Create new PR
- `gh pr comment <number>` - Add comment to PR
- `gh pr review <number>` - Start a review
- `gh pr review <number> --approve` - Approve PR
- `gh pr review <number> --request-changes` - Request changes
- `gh pr review <number> --comment` - Comment-only review

**Use `--help` on any command for full options**
