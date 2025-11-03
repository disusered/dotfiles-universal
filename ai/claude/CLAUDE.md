## 🏠️ Baseline rules

- `cd` is not the default command, it is zoxide via `eval "$(zoxide init --cmd cd zsh)"`
- Use the shell's `builtin cd` to change directories, zoxide-bound `cd` will fail.
- `ls` is not the default command, it is bound to `exa`
- Commit messages should be limited to 80 characters in length

## ⚡ Core Directives: Notion Work Tracking

**IMPORTANT**: This project uses the **Notion MCP** for ALL work and issue tracking.

- ✅ **ALWAYS** create a Notion page **before** starting any multi-step task.
- ✅ **ALWAYS** log work, commands, errors, and findings **as they happen** (append to the page), not at the end.
- ❌ **DO NOT** use markdown TODOs, local files (`WORKLOG.md`), or other tracking methods.
- ❌ **DO NOT** guess properties like `Priority` or `Project`. If they are not provided, you **MUST stop and ask the user** for them.
- ❌ **DO NOT** print a summary of the work logged when you finish. Repeating the logged information is redundant. **Report completion ONLY with the URL.**
  - **Correct Response:** "✅ Task complete. The work has been logged to Notion: [URL]"
  - **Incorrect Response:** "Perfect! I've logged... Summary: ... Title: ... Status: ... Content includes: ..."

---

## ⚙️ Notion Database

- **Data Source URL:** `collection://2a0d1aba-3b72-8031-aedc-000b7ba2c45f`
- **CRITICAL:** All agents **MUST** use this Data Source URL in the `parent` argument for creating or querying pages.
  - **Example:** `"parent": {"data_source_id": "2a0d1aba-3b72-8031-aedc-000b7ba2c45f"}`

---

## Workflow: How to Log Work

**MANDATORY: When starting ANY multi-step task, you MUST follow this order:**

### 1. Create Page FIRST

Before running any other commands:

- Use the Notion MCP to create a page for the task.
- **Parent:** Must be `{"data_source_id": "2a0d1aba-3b72-8031-aedc-000b7ba2c45f"}`.
- **Missing Info:** If `Priority`, `Project`, `Type`, `Jira issue #`, or `Github issue #` are unclear or not provided in the user's request, **STOP and ASK THE USER** for the missing information before creating the page. Do not guess.

#### **Handling Issue URL Properties (`Github issue #`, `Jira issue #`)**

The database has properties named `Github issue #` and `Jira issue #` which are **URL type**, not Text or Number. You must provide a full, valid URL when setting these properties. This is the **ONLY** place you log the main ticket IDs.

- **After the user provides an issue number** (e.g., "Jira 2110" or "GitHub #123"):
  1. You **MUST** construct the full URL before setting the property.
  2. **Jira URL:** Use `https://odasoftmx.atlassian.net/browse/<issue-number>`
     - Example: User says "Jira 2110" -> Set `Jira issue #` property to `https://odasoftmx.atlassian.net/browse/2110`
  3. **GitHub URL:** Use `https://github.com/<user>/<repo>/issues/<issue-number>`
     - **Action:** If the GitHub `<user>/<repo>` is unknown, you **MUST stop and ask the user** for the "full GitHub repository name" (e.g., `odasoftmx/sistema-escolar`) before you can construct the URL.
     - Example: User says "GitHub #123" and you know the repo is `odasoftmx/app` -> Set `Github issue #` property to `https://github.com/odasoftmx/app/issues/123`

### 2. Log AS YOU GO

- Use the Notion MCP to **append to the page's content block** (page body).
- Do this after **EVERY significant command, finding, or error**. Do NOT wait until the end.
- **CRITICAL:** Do NOT create a "Related Tickets" section that just repeats the main `Jira issue #` or `Github issue #` from the page properties.
- **DO** link to _other_ relevant items (discovered issues, specific commits, or code files) in the body of your log, using the formats below.

| Reference Type     | **Required Markdown Format (in Notion page body)**                                                                                                                        |
| :----------------- | :------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| **Jira Issues**    | `[<issue-id>](https://odasoftmx.atlassian.net/browse/<issue-id>)` <br> (e.g., `[SYS-123](https://odasoftmx.atlassian.net/browse/SYS-123)`)                                |
| **GitHub Issues**  | `[#<issue-number>](https://github.com/user/repo/issues/<issue-number>)` <br> (e.g., `[#123](https://github.com/odasoftmx/app/issues/123)`)                                |
| **GitHub Code**    | `[<relative-path>#L<lines>](<full-url-to-file-at-commit-sha>)` <br> (e.g., `[src/file.js#L10-L20](https://github.com/odasoftmx/app/blob/a1b2c3d4e5/src/file.js#L10-L20)`) |
| **GitHub Commits** | `[<short-sha>](<full-commit-url>)` <br> (e.g., `[a1b2c3d](https://github.com/odasoftmx/app/commit/a1b2c3d4e5...)`)                                                        |

### 3. Close When Complete

- Update the page's `Status` property to `Done`.
- Append a final summary _to the page content_ (not to the user).
- **Final Response:** Report to the user _only_ that the task is complete and provide the URL. (See `Core Directives` for the exact format).

---

## LReference: Page Properties

### Type

Use the `Type` property to classify work:

- `bug`: Something broken
- `feature`: New functionality
- `task`: Work item (tests, docs, refactoring)
- `epic`: Large feature with subtasks
- `chore`: Maintenance (dependencies, tooling)

### Priority

Use the `Priority` property to rank work:

- `0`: Critical (security, data loss, broken builds)
- `1`: High (major features, important bugs)
- `2`: Medium (default, nice-to-have)
- `3`: Low (polish, optimization)
- `4`: Backlog (future ideas)
