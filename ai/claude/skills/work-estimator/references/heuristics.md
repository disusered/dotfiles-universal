# Estimation Heuristics & Prompts

## Codebase Agent Prompts

### Architecture Understanding
- "What's the project structure? Where are API endpoints defined?"
- "How is the data layer organized? What ORM patterns are used?"

### Feature Investigation
- "Find implementations of CRUD operations for similar entities"
- "How are filters/search implemented in existing endpoints?"
- "What validation is applied to similar entities?"

### Frontend Patterns
- "How are data tables implemented? What MudBlazor components?"
- "Find existing filter/search UI implementations"
- "How is API integration handled? What services exist?"

### Estimation Support
- "How complex is the existing implementation of [similar feature]?"
- "What dependencies would this feature have?"

## Estimation Heuristics

Instead of relying statically on hardcoded tables, use a **Dynamic Historical Heuristic** by querying past performance via the Jira MCP. 

### Dynamic Jira History Search

When calculating an estimate for a task or sub-task, follow these steps to see time invested vs time spent on similar historic tasks:

1. **Identify Keywords**: Extract key technical terms and action verbs from the current task description (e.g., "Pagination", "Search", "API integration", "CRUD").
2. **Search Historical Tasks**: Use `mcp__atlassian__searchJiraIssuesUsingJql` to find similar, completed tasks assigned to the user.
   - *Example JQL*: `assignee = currentUser() AND statusCategory = Done AND (text ~ "keyword1" OR text ~ "keyword2")`
3. **Analyze Time Invested vs. Time Spent**:
   - Extract the `timeoriginalestimate` (Initial Estimate/Time Invested) and `timespent` (Actual Time Logged) from the aggregated past issues.
   - Calculate the historical discrepancy ratio (e.g., if a similar task was initially estimated at 4h but actually took 6h, the developer is generally optimistic by a ratio of 1.5x for this type of task).
4. **Apply Heuristic**: Apply the calculated historical ratio and base average times to your proposed estimate.
   - Present this historical justification to the user (e.g., "Historically, you estimated X at 4h but spent 6h. I propose 6h for this similar task.").
   - *Fallback*: If no direct historical match is found, apply a default **~1.4x ratio** (developers are generally 40% optimistic historically).

### Common Fallback Baselines (If History is Unavailable)
- **Backend**: Basic endpoint (3-4h), Pagination/sorting (4h), Search/filter logic (4-5h), External API (4-6h)
- **Frontend**: Table/list (4h), Filters UI (6h), Services (4-5h), API integration (8h)
