## Baseline rules

- `cd` is not the default command, it is zoxide via `eval "$(zoxide init --cmd cd zsh)"`
- Use the shell's `builtin cd` to change directories, zoxide-bound `cd` will fail.
- `ls` is not the default command, it is bound to `exa`
- Commit messages should be limited to 80 characters in length

## Work Tracking with Notion MCP

**IMPORTANT**: This project uses the **Notion MCP** for ALL work and issue tracking. Do NOT use markdown TODOs, local files (`WORKLOG.md`, `JOURNAL.md`), or other tracking methods.

All work must be logged in the `disusered/Work-2a0d1aba3b728015ae84e9cfbffd2b2a` database. This database structure is what allows for sorting, filtering, and searching.

### Why Notion?

- **Centralized Tracking:** Provides a single source of truth for all work, context, status, and blockers.
- **Agent-Optimized:** The MCP allows you to programmatically read and write to this database, enabling you to find ready work and log context.
- **Artifact Generation:** This log is the **single source of truth** used to generate future artifacts, including Jira tickets, GitHub issues, and PR descriptions.
- **Prevents Confusion:** Avoids duplicate tracking systems and ensures all work history is captured in one place.
- **Database Structure:** All entries are items in a database. This allows for powerful filtering, sorting, and searching by properties like `Status`, `Priority`, or `Project`.

### Core Concepts

- **Check for ready work:** Query the database for pages that are unassigned or not 'Done' or 'Blocked'.
- **Create new work:** Create a new page in the database for any new task, bug, or feature.
- **Update status:** Update a page's `Status` property (e.g., to `In Progress`) as you claim and work on it.
- **Log context:** Append all significant findings, commands, and errors to the body of the page.
- **Complete work:** Update the page's `Status` to `Done` and add a final summary to the page body.

### Page Properties: Project

Use a `Select` or `Text` property (e.g., 'Project' or 'Repository') to tag every page to its corresponding codebase. This is **critical** for filtering and creating project-specific views.

### Page Properties: Type

Use the `Type` property to classify work:

- `bug` - Something broken
- `feature` - New functionality
- `task` - Work item (tests, docs, refactoring)
- `epic` - Large feature with subtasks
- `chore` - Maintenance (dependencies, tooling)

### Page Properties: Priority

Use the `Priority` property to rank work:

- `0` - Critical (security, data loss, broken builds)
- `1` - High (major features, important bugs)
- `2` - Medium (default, nice-to-have)
- `3` - Low (polish, optimization)
- `4` - Backlog (future ideas)

### Workflow for AI Agents

**MANDATORY: When starting ANY multi-step task, you MUST:**

1. **Create a Notion Page FIRST** (before any work):
   - Use the Notion MCP to create a page for the task.
   - Do this IMMEDIATELY when the user requests work.
   - Before running any commands or using any other tracking method.

2. **Log work AS YOU GO**:
   - Use the Notion MCP to **append to the page's content block**.
   - Do this after **EVERY significant command or finding**.
   - Do NOT wait until the end to log.
   - Capture exact commands, errors encountered, and solutions applied.
   - **CRITICAL: All references MUST be cross-linked:**
     - **Jira Issues:** Link using the full URL: `https://odasoftmx.atlassian.net/browse/<issue-id>` (e.g., `https://odasoftmx.atlassian.net/browse/PROJ-123`).
     - **GitHub Issues:** Link to the full issue URL (e.g., `https://github.com/owner/repo/issues/<number>`).
     - **Code References:** When logging file changes, link directly to the branch/SHA and line number in GitHub (e.g., `https://github.com/owner/repo/blob/sha/path/to/file.cs#L15`).

3. **Close when complete**:
   - Update the page's `Status` property to `Done`.
   - Append a final summary to the page content.

**Standard workflow:**

1. **Check ready work**: Query the database for ready, unblocked issues.
2. **Claim your task**: Update the page `Status` to `In Progress`.
3. **Work on it**: Implement, test, document, logging to the page content as you go.
4. **Discover new work?** Create a new, linked Notion page (e.g., using a `Discovered From` or `Blocks` relation).
5. **Complete**: Update the page `Status` to `Done`.

### Important Rules

- ✅ Use the Notion MCP for ALL task tracking.
- ✅ Create a Notion page **before** starting any work.
- ✅ Log significant findings, commands, and errors **as they happen**, with correct cross-links.
- ✅ Link discovered work using page relations.
- ✅ Check the database (e.g., query for ready work) before asking "what should I work on?"
- ❌ Do NOT create markdown TODO lists.
- ❌ Do NOT use local files (`WORKLOG.md`, `JOURNAL.md`).
- ❌ Do NOT use external issue trackers or duplicate tracking systems.
- ❌ Do NOT print a summary afterwards, only indicate the db is update and link to it.
