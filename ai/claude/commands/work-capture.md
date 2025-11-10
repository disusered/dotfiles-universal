---
description: Capture session context and update Notion work logs before conversation reset
---

# Context Capture Before Reset

Update your Notion work logs with session context when approaching token limits to ensure work continuity across conversation resets.

## When to Use

- Approaching token/context limits
- Need to switch conversations
- Taking a break from complex work
- Want to preserve important decisions/discoveries

## What This Command Does

This command helps you capture the current session's context into your existing Notion work logs so nothing is lost during a conversation reset.

## Process

1. **Identify Active Work**

   Ask user: "Which Notion page(s) should I update?" or "What Jira/GitHub issues are we working on?"

   Use `mcp__notion__query_database` to find relevant pages.

2. **Capture Session Context**

   For each active work item, append a context capture entry:

   ```markdown
   ## Session Context Capture

   **Timestamp:** [current timestamp]

   ### What We Accomplished

   [Summary of work completed this session]
   [Key decisions made]
   [Problems solved]

   ### Current State

   [What's in progress]
   [Which files are being modified]
   [What step we're on]

   ### Important Discoveries

   [Technical insights found]
   [Architectural decisions made]
   [Patterns or solutions learned]

   ### Next Steps

   [Immediate next action to take]
   [Commands needed on restart]
   [Files that need attention]

   ### Blockers/Questions

   [Unresolved issues]
   [Decisions still needed]
   [Things to investigate further]

   ### Context for Handoff

   **Current file/line:** [Specific location if mid-edit]
   **Uncommitted changes:** [What's staged/unstaged]
   **Test command:** [How to verify work]
   ```

3. **Update Memory/Context Files**

   If project has context documentation (e.g., PROJECT_KNOWLEDGE.md, BEST_PRACTICES.md):
   - Add new patterns or solutions discovered
   - Update architectural decisions
   - Document new entity relationships or system behaviors

4. **Confirm Capture**

   Respond with:
   ```
   ✅ Session context captured in Notion:
   - [Work item 1]: [URL]
   - [Work item 2]: [URL]

   Safe to reset conversation. All context preserved.
   ```

## What to Capture

**DO capture (hard to rediscover):**
- WHY decisions were made
- Approaches attempted that failed
- Root causes discovered
- Non-obvious solutions or patterns
- Specific lines/files currently being edited
- Uncommitted changes not yet pushed

**DON'T capture (available elsewhere):**
- Code changes (in git)
- Commit messages (in git history)
- File listings (can be regenerated)
- General project structure (documented elsewhere)

## Key Principles

- **Focus on the WHY**: Capture reasoning that isn't in code
- **Preserve state**: Make it easy to continue exactly where you left off
- **No duplication**: Don't repeat what's in git/GitHub/Jira
- **Actionable**: Include concrete next steps

## Example Usage

```
User: /work-capture
```

The command will:
1. Find active Notion work pages
2. Append comprehensive context capture
3. Update any project memory files
4. Confirm all context preserved

## Integration with Other Workflows

- **Before reset**: Use this command to preserve context
- **After reset**: Review the captured context to resume work
- **For handoffs**: Useful when switching who's working on something

## Notes

- This captures **session context**, not final summaries
- Final summaries happen when work is complete (CLAUDE.md directives)
- Can be used multiple times per work item as needed
- Preserves "working memory" that would otherwise be lost
