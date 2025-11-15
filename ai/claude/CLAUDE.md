## 🏠️ Baseline rules

### Git Operations - CRITICAL SAFETY RULES

**NEVER perform destructive git operations without explicit user permission:**

- ❌ **NEVER** use `git rebase` without explicit user permission
- ❌ **NEVER** use `git reset --hard` without explicit user permission
- ❌ **NEVER** use `git push --force` or `git push -f` without explicit user permission
- ❌ **NEVER** use `git cherry-pick` without explicit user permission
- ❌ **NEVER** delete branches without explicit user permission
- ❌ **NEVER** amend commits that might be shared/pushed

**If you perform any of these operations without permission, the user could lose work and you will be replaced.**

### Gitflow Branch Targeting - CRITICAL RULE

**ALWAYS determine the correct target branch based on gitflow conventions:**

```
hotfix/*    → main (or master if main doesn't exist)
feature/*   → develop
release/*   → main (or master if main doesn't exist)
bugfix/*    → develop
claude/*    → Ask user for target branch
```

**Before creating ANY PR:**
1. Detect source branch: `git branch --show-current`
2. Determine target using table above
3. **ALWAYS confirm with user**: "Detected source: {source}, target: {target}. Is this correct?"
4. If user says no, use their target instead
5. NEVER assume - ALWAYS confirm

**If you target the wrong branch, you could break production. This is unacceptable.**

### Directory Navigation - CRITICAL RULE

**ALWAYS use `builtin cd` to change directories. NEVER use naked `cd`.**

- `cd` is overridden by zoxide via `eval "$(zoxide init --cmd cd zsh)"`
- Using `cd` without `builtin` will fail in this environment
- **ONLY use `builtin` with the `cd` command - it is the ONLY command that needs `builtin`**
- **NEVER use `builtin` with ANY other command** (e.g., `builtin git`, `builtin dotnet`, `builtin npm` are ALL WRONG)

**Correct:**
```bash
builtin cd /path/to/directory
builtin cd ../
builtin cd ~
git status              # Just git, NO builtin
npm install             # Just npm, NO builtin
```

**WRONG:**
```bash
cd /path/to/directory   # Will fail - zoxide conflict
builtin git status      # WRONG - git is not a shell builtin, just use: git status
builtin dotnet         # WRONG - dotnet is not a shell builtin
builtin npm            # WRONG - npm is not a shell builtin
```

**REMEMBER: `builtin` is ONLY for `cd`. Everything else uses the normal command name.**

### File Listing - ALWAYS Use /bin/ls

**ALWAYS use `/bin/ls`. NEVER use naked `ls`.**

- `ls` is aliased to `exa` in the shell
- Claude should bypass this alias and use the actual `ls` binary
- Use `/bin/ls` for all file listing operations

**Correct:**
```bash
/bin/ls -la               # Use actual ls binary
/bin/ls -lh               # Use actual ls binary
/bin/ls                   # Use actual ls binary
```

**WRONG:**
```bash
ls -la                    # Will use exa alias (don't do this)
```

### General Rules

- Commit messages should be limited to 80 characters in length
- **NEVER add footers, signatures, or tool attribution** to any output (PRs, commits, comments, etc.)
  - ❌ NO "Generated with Claude Code" or similar footers
  - ❌ NO attribution links or tool credits
  - ❌ NO robot emojis (🤖) or meta-commentary
  - All outputs must be professional and contain only relevant content

## 🔒 Security: Sensitive Data Handling

**CRITICAL**: Hooks and logging tools receive full tool parameters including file contents, passwords, and credentials.

**For Developers/Maintainers:**

- **NEVER log or echo** the raw `$input` variable in hooks - it contains sensitive data
- **Only extract safe metadata**: tool names, file paths, timestamps, session IDs
- **Skip logging** for files containing credentials: `.env`, `.credentials`, `.secret`, `.key`, `.pem`, API keys, tokens, auth files
- **Defense in depth**: Even if not currently logged, assume hook input contains secrets
- See `hooks/post-tool-use-tracker.sh` for reference implementation

**For hook modifications**: Always audit what data is being logged/stored/transmitted.

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
   **Created:** [current timestamp from injected context]

   ---

   ## Work Log

   Starting work...
   ```

6. **Save to:** `dev/active/{filename}.md`

### Logging Behavior (CONTINUOUS)

**After creating the file, log continuously using Edit or Write:**

- **Log THINKING, not DOING** - focus on decisions, discoveries, and reasoning
- **Append after EVERY significant action** - don't batch at the end
- **Use real timestamps** from injected context (America/Tijuana) before EACH append
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

**Timestamp:** [from injected context]

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

### jq

JSON processor for parsing, filtering, and transforming JSON data. Use this instead of grep when working with JSON files.

**Basic Usage:**

- `jq '.' file.json` - Pretty-print JSON
- `jq '.fieldname' file.json` - Extract field
- `jq '.array[]' file.json` - Iterate array elements
- `jq '.[] | select(.status == "active")' file.json` - Filter objects
- `jq -r '.field'` - Raw output (no quotes)
- `jq -c '.'` - Compact output

**Common Patterns:**

- `jq '.items[] | {id, name, price}'` - Extract specific fields
- `jq 'map(select(.price > 100))'` - Filter and map
- `jq 'group_by(.category)'` - Group by field
- `jq '[.[] | .id]'` - Collect values into array

**With Other Tools:**

- `ast-grep --json | jq '.[] | .file' -r` - Parse ast-grep output
- `curl api.example.com | jq '.users[].email'` - Parse API responses

Use `jq --help` for more options. See the jq skill for comprehensive reference.

### psql

PostgreSQL command-line client for database operations. **CRITICAL: ALWAYS run through docker compose, NEVER locally.**

**Basic Usage:**

- `docker compose exec -it postgres psql -U postgres -d myapp_db` - Connect to database
- `docker compose exec -it postgres psql -U postgres -d myapp_db -c "SQL"` - Run single command
- `docker compose exec -T postgres psql -U postgres -d myapp_db < file.sql` - Execute SQL file

**Common Meta-Commands:**

- `\l` - List all databases
- `\dt` - List all tables
- `\d table_name` - Describe table
- `\du` - List users/roles
- `\c database_name` - Connect to database
- `\q` - Quit

**Database Operations:**

- `docker compose exec -T postgres pg_dump -U postgres -d myapp_db > backup.sql` - Backup database
- `docker compose exec -T postgres psql -U postgres -d myapp_db < backup.sql` - Restore database
- `docker compose logs postgres` - Check database logs
- `docker compose restart postgres` - Restart database

Use the psql skill for comprehensive reference including SQL operations, migrations, and troubleshooting.

### acli

Official Atlassian CLI for **Jira only** (NOT Confluence - use Atlassian MCP for Confluence).

**Work Items:**

- `acli jira workitem create --summary "Task" --project "KEY" --type "Task"` - Create work item
- `acli jira workitem view --key "KEY-123"` - View work item details
- `acli jira workitem edit --key "KEY-123" --summary "New summary"` - Edit work item
- `acli jira workitem transition --key "KEY-123" --status "In Progress"` - Transition status

**Comments:**

- `acli jira workitem comment create --key "KEY-123" --body "Comment text"` - Add comment
- Use `--help` on any command for full options

**Note:** For Confluence operations (pages, spaces, wiki), use the Atlassian MCP server instead.

### Atlassian MCP

Model Context Protocol server for **Confluence** (NOT Jira - use acli for Jira).

The Atlassian MCP server provides tools for interacting with Confluence through the Model Context Protocol. It's automatically available when configured.

**Confluence Operations:**

- **Spaces**: List and manage Confluence spaces
- **Pages**: Create, read, update, delete pages with full CRUD operations
- **Search**: Use CQL (Confluence Query Language) for content discovery
- **Comments**: Add and manage threaded comments on pages
- **Labels**: Manage page labels
- **Hierarchy**: Navigate page relationships (ancestors, children)

**Configuration:**

The MCP server requires API credentials stored in `~/.atlassian-mcp.json`:

```json
{
  "domain": "your-domain.atlassian.net",
  "email": "your-email@example.com",
  "apiToken": "your-api-token-here"
}
```

Create an API token at: https://id.atlassian.com/manage-profile/security/api-tokens

**Usage:**

When you need to interact with Confluence, the Confluence skill will automatically invoke the appropriate MCP tools. You can also directly request Confluence operations and the MCP server will handle them.

**Note:** For Jira operations (issues, comments, workitems), use acli instead.

### gh

GitHub CLI for issues and pull requests.

**CRITICAL - Understanding "Create a PR" Requests:**

When the user says "create a PR" or "create a pull request":
- ❌ **DO NOT** run `git commit` or `git push` - assume code is already committed
- ❌ **DO NOT** commit anything - the user already did that
- ✅ **DO** use `gh pr create` to create the PR in GitHub
- ✅ **DO** ask for permission BEFORE running `gh pr create`
- If the user says "it's already committed and pushed", BELIEVE THEM and just create the PR

**User Authorization Required:**

All `gh` commands that modify state REQUIRE user approval before execution:
- `gh pr create` - REQUIRES approval
- `gh pr comment` - REQUIRES approval
- `gh issue create` - REQUIRES approval
- `gh issue comment` - REQUIRES approval
- Read-only commands (`gh pr list`, `gh pr view`, etc.) do NOT require approval

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
