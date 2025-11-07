## 🏠️ Baseline rules

- `cd` is not the default command, it is zoxide via `eval "$(zoxide init --cmd cd zsh)"`
- Use the shell's `builtin cd` to change directories, zoxide-bound `cd` will fail.
- `ls` is not the default command, it is bound to `exa`
- Commit messages should be limited to 80 characters in length

## ⚡ Core Directives: Notion Work Tracking

**IMPORTANT**: This project uses the **Notion MCP** for ALL work and issue tracking.

### When to Track Work (PROACTIVE)

**AUTOMATICALLY create a Notion page BEFORE starting ANY of these tasks:**
- Investigation/debugging (multi-step)
- Feature development
- Bug fixes
- Code refactoring
- Any work requiring multiple commands/steps

**You MUST create the page BEFORE executing commands, not after.**

### Creating the Notion Page

1. **Validate properties first:**
   ```bash
   python ai/claude/skills/work-journal/scripts/validate_properties.py --priority X --project "Y" --type Z [--jira ID] [--github NUM --repo user/repo]
   ```

2. **If Priority, Project, or Type missing: STOP and ASK the user**

3. **Create page using `mcp__notion__notion-create-pages`:**
   ```json
   {
     "parent": {"data_source_id": "2a0d1aba-3b72-8031-aedc-000b7ba2c45f"},
     "pages": [{
       "properties": {
         "Name": "Brief description",
         "Priority": 0-4,
         "Project": "Team/Project name",
         "Type": "bug|feature|task|epic|chore",
         "Jira issue #": "https://odasoftmx.atlassian.net/browse/ID" (optional),
         "Github issue #": "https://github.com/user/repo/issues/NUM" (optional),
         "Status": "In Progress"
       },
       "content": "## Work Log\n\nStarting work...\n"
     }]
   }
   ```

### Logging Behavior (CONTINUOUS)

**After creating the page, log continuously using `mcp__notion__append_to_page_content`:**

- **Log THINKING, not DOING** - focus on decisions, discoveries, and reasoning
- **Append after EVERY significant action** - don't batch at the end
- **Use real timestamps** from `TZ='America/Tijuana' date '+%Y-%m-%d %H:%M'` before EACH append
- **Chronological only** - ALWAYS append to end, NEVER restructure or read entire page

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

When finished:
1. Append final summary to page content
2. Update Status property to "Done" using `mcp__notion__update_page_properties`
3. Respond ONLY with: `✅ Task complete. The work has been logged to Notion: [URL]`
4. **DO NOT print the work summary** - it's already in Notion

### Required Properties

- **Priority** (0-4): 0=Critical, 1=High, 2=Medium, 3=Low, 4=Backlog
- **Project** (string): Team or project name
- **Type** (enum): `bug`, `feature`, `task`, `epic`, or `chore`

**GitHub and Jira are OPTIONAL** - only include if user explicitly mentions them.

### Notion Database

- **Data Source:** `collection://2a0d1aba-3b72-8031-aedc-000b7ba2c45f`
- All work pages **MUST** use this as parent

---

### Specialized Outputs (Use Skills)

For PR descriptions, manager summaries, or stakeholder updates:
- **Invoke the `work-journal` skill** and specify the workflow
- These require templates, iteration, and approval
- See `~/.claude/skills/work-journal/` for details

## 🔧 Tools

### jiratui

CLI for Jira issues and comments.

**Commands:**
- `jiratui issues` - List/query issues
- `jiratui comments <issue-key>` - View/add comments
- Use `--help` on any command for options

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
