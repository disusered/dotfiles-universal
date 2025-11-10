---
description: Create strategic planning documentation for development initiatives in Notion
---

# Strategic Work Planning

Create a comprehensive strategic plan for the development initiative you describe (e.g., "refactor authentication system").

## What This Command Does

This command analyzes your codebase and creates detailed strategic planning documentation in Notion for complex development initiatives.

## Process

1. **Understand the Initiative**
   - Ask clarifying questions about scope and goals
   - Examine the codebase to understand current state
   - Identify key components and dependencies

2. **Create Notion Planning Page**
   - Use `mcp__notion__create_page` with the work database
   - Set properties:
     - Priority: Based on initiative impact
     - Project: The team/project name
     - Type: "epic" for large initiatives, "task" for smaller ones
     - Name: Brief description of the initiative
   - Set Status: "Not started" (planning phase)

3. **Generate Strategic Plan Content**

   Append comprehensive plan to the Notion page using `mcp__notion__append_to_page_content`:

   ```markdown
   ## Executive Summary

   [Brief overview: what, why, expected impact]

   ## Current State Analysis

   [Technical assessment of current implementation]
   [Pain points and gaps identified]
   [Dependencies and integration points]

   ## Implementation Phases

   ### Phase 1: [Name]
   **Goal:** [What this phase achieves]
   **Tasks:**
   1. [Task with effort estimate: S/M/L/XL]
   2. [Task with effort estimate]

   **Acceptance Criteria:**
   - [Specific, measurable criteria]

   **Dependencies:** [What must be done first]

   ### Phase 2: [Name]
   [Same structure as Phase 1]

   ## Risk Assessment

   **Technical Risks:**
   - [Risk] - Mitigation: [Strategy]

   **Schedule Risks:**
   - [Risk] - Mitigation: [Strategy]

   ## Success Metrics

   [How to measure completion and success]

   ## Resource Requirements

   [Team members, time estimates, external dependencies]
   ```

4. **Create Child Task Pages (Optional)**

   For each major task, offer to create child Notion pages with:
   - Parent: The planning page
   - Detailed breakdown of subtasks
   - Technical context and references

5. **Provide Notion URL**

   Respond with the planning page URL only:
   ```
   ✅ Strategic plan created in Notion: [URL]
   ```

## Key Principles

- **Self-contained plans**: Include all necessary context so anyone can understand the initiative
- **Phased approach**: Break large initiatives into manageable phases
- **Clear acceptance criteria**: Make success measurable
- **Risk awareness**: Identify and plan for potential blockers
- **Effort estimation**: Use S/M/L/XL sizing for tasks

## Example Usage

```
User: /work-plan refactor authentication to use JWT tokens
```

The command will:
1. Ask about current auth implementation
2. Examine relevant codebase files
3. Create strategic plan in Notion
4. Break down into phases with tasks
5. Provide Notion URL

## Integration with Other Workflows

- **After planning**: Use regular work logging (CLAUDE.md directives) when executing tasks
- **For updates**: Use the work-journal skill to create stakeholder/manager summaries
- **For tracking**: Update the planning page Status as phases complete

## Notes

- This is for **planning**, not **logging** - use CLAUDE.md directives for ongoing work
- Plans persist in Notion and can be referenced across conversations
- Update the plan as you learn more during implementation
