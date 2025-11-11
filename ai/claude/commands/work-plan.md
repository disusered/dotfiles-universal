---
description: Create strategic planning documentation for development initiatives in Markdown
---

# Strategic Work Planning

Create a comprehensive strategic plan for the development initiative you describe (e.g., "refactor authentication system").

## What This Command Does

This command analyzes your codebase and creates detailed strategic planning documentation in Markdown for complex development initiatives.

## Process

**CRITICAL: DO NOT use the Task tool or launch any agents during this command. Use only direct tools (Read, Grep, Glob, Bash, ast-grep) for all operations.**

**LANGUAGE: ALL content (questions, planning file, communication) MUST be in ENGLISH. Spanish is ONLY for final artifacts (PR descriptions, manager summaries, stakeholder updates) via the work-journal skill.**

1. **Understand the Initiative**
   - Ask clarifying questions about scope and goals
   - Examine the codebase to understand current state (using Read, Grep, Glob, ast-grep directly)
   - Identify key components and dependencies

2. **Gather Metadata (Ask Once)**
   - **Priority** (0-4): Ask user if not clear from context
   - **Project**: Ask user which team/project this belongs to
   - **Type**: Ask user (epic/task/feature)
   - **Jira** (optional): Ask "Is there a Jira issue for this?"
   - **Github** (optional): Ask if not mentioned

3. **Create Planning Work Log**
   - Use Write tool to create file in `dev/active/`
   - Filename format: `{date}-plan-{brief-description}.md`
   - Set metadata from step 2:
     - Priority: 0-4
     - Project: The team/project name
     - Type: "epic" for large initiatives, "task" for smaller ones
     - Status: "Not started" (planning phase)
     - Jira: URL if provided
     - Github: URL if provided

4. **Generate Strategic Plan Content**

   Write comprehensive plan to the work log file:

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

5. **Create Child Task Files (Optional)**

   For each major task, offer to create separate work log files in `dev/active/`:
   - Filename: `{parent-name}-task-{N}-{description}.md`
   - Detailed breakdown of subtasks
   - Technical context and references

6. **Provide File Path**

   Respond with the planning file path only:
   ```
   ✅ Strategic plan created: dev/active/{filename}.md
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
3. Create strategic plan in Markdown file
4. Break down into phases with tasks
5. Provide file path

## Integration with Other Workflows

- **After planning**: Use regular work logging (CLAUDE.md directives) when executing tasks
- **For updates**: Use the work-journal skill to create stakeholder/manager summaries
- **For tracking**: Update the planning file Status in metadata as phases complete

## Notes

- This is for **planning**, not **logging** - use CLAUDE.md directives for ongoing work
- Plans persist in `dev/active/` and can be referenced across conversations
- Update the plan file as you learn more during implementation
