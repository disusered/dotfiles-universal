---
name: work-estimator
description: Interactive workflow for estimating Jira stories in a sprint, tracking progress with Beads and generating structured outputs. Use when starting a new sprint estimation or continuing estimation work.
---

# Work Estimator

## Overview

This skill guides the estimation of Jira stories for a specific sprint. It orchestrates the process using **Beads** to track progress, creates structured documentation for each issue, and generates CSV estimates for Project Management.

## Workflow

### Step 1: Sprint Initialization & Beads Setup

1. **Identify Sprint**:
    - Search for active/future sprints using `mcp__atlassian__searchJiraIssuesUsingJql` (or ask user).
    - Confirm the target Sprint Name with the user.

2. **Initialize Tracking**:
    - Check if a Beads Epic exists for this sprint: `bd list --type epic`.
    - If not, create one: `bd create "Estimate Sprint: {SprintName}" type=epic`.

3. **Populate Issues**:
    - Fetch assigned stories for the sprint: `assignee = currentUser() AND project = XBOL AND sprint = "{SprintName}" AND issuetype = Story`.
    - For each story found:
      - Check if a bead exists: `bd list --search "{IssueKey}"`.
      - If not, create a bead: `bd create "Estimate {IssueKey}: {Summary}" --type task --priority high`.
      - Link it to the Sprint Epic (if possible/supported via `bd` or just mentally associate).

### Step 2: Estimation Loop

Iterate through the **Open Beads** for this sprint. For each bead (Issue), practice **Progressive Disclosure** (guide the user step-by-step without overwhelming them, pausing for confirmation before moving to the next phase):

1. **Context & Setup**:
    - Mark bead as `in_progress`: `bd update {BeadID} --status in_progress`.
    - Fetch full Jira details: `mcp__atlassian__getJiraIssue`.
    - _Action_: Present a brief summary of the Jira ticket to the user and ask if they are ready to explore it. **Wait for response.**

2. **Interactive Exploration**:
    - **Clarify**: Ask user for high-level requirements/inputs/outputs if not clear in Jira. **Wait for response if asking.**
    - **Explore Codebase**:
      - Ask user for Backend/Frontend paths if unknown.
      - **Parallel Investigation**: Use `codebase_investigator` or parallel `grep_search`/`glob` calls to find similar patterns, existing services, and UI components.
      - Refer to `references/heuristics.md` for specific prompts and patterns to look for.
    - **Analysis**:
      - Identify "Known Knowns" (patterns to reuse).
      - Identify "Known Unknowns" (dependencies, missing info).
      - Challenge assumptions (simpler approach?).
      - Record all findings in the bead notes: `bd update {BeadID} --notes "..."` .
    - _Action_: Present a concise summary of the analysis and technical understanding to the user. Ask if they agree before proceeding to breakdown. **Wait for response.**

3. **Dynamic Breakdown & Estimation**:
    - **Propose Breakdown**: Propose a FrontEnd/BackEnd sub-task breakdown to the user. **Wait for feedback and iterate until agreed.**
    - **Historical Research**: Search Jira for similar past issues assigned to the user using the Jira MCP to see time invested vs time spent (refer to `references/heuristics.md` for the exact method).
    - **Propose Estimates**: Present the historical findings and the proposed estimates for the current sub-tasks. **Wait for user approval.**
    - Update bead notes with final breakdown and estimates: `bd update {BeadID} --notes "..."` .

4. **Output Generation**:
    - Generate a stand-alone CSV file `Estimates/{SprintName}_{IssueKey}_{Date}_estimate.csv`:

      ```csv
      Summary,Assignee,Issue Type,Original Estimate,Parent id
      {task description},carlos.rosquillas@odasoft.com.mx,Sub-task,{seconds},XBOL-XXX
      ```

    - Mark bead as `done`: `bd close {BeadID} --reason "Estimation complete"`.

### Step 3: Consolidation

Once all beads are closed:

1. Concatenate all `*_estimate.csv` files for the sprint into a single master CSV: `Estimates/{SprintName}_Master_{Date}.csv`.
2. Present the master CSV to the user for final review.
3. (Optional) Ask if user wants to upload sub-tasks to Jira (using `mcp__atlassian__createJiraIssue`).

## References

- **Heuristics & Prompts**: See `references/heuristics.md` for estimation data and investigation prompts.
