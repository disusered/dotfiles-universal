---
name: work-journal
description: Generate audience-specific communications from Markdown work logs. Use when creating PR descriptions, or generating status updates for managers and stakeholders. (Note: Basic work logging is handled by CLAUDE.md directives, not this skill.)
allowed-tools: Read, Write, Edit, Bash, Skill
---

# Work Journal Communication Generation

## Purpose

This skill generates audience-appropriate communications from Markdown work logs that were created using CLAUDE.md directives.

**IMPORTANT:** This skill does NOT handle basic work logging. That's handled automatically by CLAUDE.md directives.

## Language Rule

**CRITICAL - READ THIS CAREFULLY:**

**ALL agent ↔ user communication: ENGLISH ONLY**
**ALL work log content: ENGLISH ONLY**
**ONLY final artifact outputs: SPANISH**

| Content Type | Language |
|-------------|----------|
| Questions to user | English |
| Confirmations | English |
| Work log entries | **ENGLISH** |
| PR descriptions | Spanish |
| Manager summaries | Spanish |
| Stakeholder updates | Spanish |

**NEVER translate existing work logs to Spanish. Work logs stay in English.**

## Supported Workflows

1. **PR Descriptions** - Generate technical PR descriptions in Spanish for code review
2. **Manager Summaries** - Generate strategic summaries in Spanish for managers
3. **Stakeholder Updates** - Generate non-technical updates in Spanish for stakeholders

## How This Skill Works

**Model-Invoked Activation:**
This skill activates when you detect that the user's request matches one of the supported workflows above.

**Identify the workflow by keywords:**
- "PR description", "pull request", "create PR" → PR Description
- "manager summary", "resumen para manager", "jefe" → Manager Summary
- "stakeholder update", "post to github", "actualización" → Stakeholder Update

**Then dispatch to the appropriate template.**

**Note:** If user mentions "log work" or "track work", that's handled by CLAUDE.md, not this skill.

## Tool Skills Integration

**When you need to use CLI tools, invoke the appropriate tool skill:**

### For Jira operations:
```
Invoke the `jira` skill when you need to:
- View Jira issues
- Add comments to Jira issues
- Query Jira issues
```

### For GitHub operations:
```
Invoke the `gh` skill when you need to:
- View GitHub issues or PRs
- Create PRs
- Add comments to issues/PRs
```

**Example workflow:**
1. User requests: "Create manager summary and post to Jira"
2. Generate manager summary (this skill)
3. Invoke `jira` skill to learn how to use acli
4. Use `acli jira workitem comment create` to post summary to Jira

**Note:** These tool skills provide detailed CLI syntax and examples via progressive disclosure, keeping this skill focused on tone and presentation.

---

## Critical Rules (Apply to ALL Workflows)

### NEVER Update Status to "Done"

**CRITICAL: Creating artifacts does NOT complete work.**

- ❌ **NEVER update work log Status to "Done"**
- ❌ **NEVER mark work as "Done" when creating PR descriptions**
- ❌ **NEVER mark work as "Done" when creating manager summaries**
- ❌ **NEVER mark work as "Done" when creating stakeholder updates**

**These are communication artifacts. They document work, but don't complete it.**

**Work is ONLY marked "Done" when:**
- Code is merged AND deployed
- OR work doesn't require a PR and is fully complete
- NOT when PR is created
- NOT when summaries/updates are posted

### Information Flow Security (CRITICAL)

**CRITICAL: Internal tracking info MUST NOT leak to external channels.**

**Information flow rules:**
- ✅ **Jira (internal) → can reference GitHub** (e.g., Jira comment can link to GitHub issue)
- ❌ **GitHub (public) → MUST NOT reference Jira** (e.g., PR descriptions NEVER include Jira links)
- ❌ **Stakeholder updates (external) → MUST NOT reference Jira or work logs** (only user-facing info)
- ✅ **Manager summaries (internal, posted to Jira) → can reference anything**

**What to EXCLUDE from public artifacts (PRs, stakeholder updates):**
- ❌ Jira issue numbers or URLs
- ❌ Work log file paths
- ❌ Internal tracking IDs
- ❌ Commit SHAs (in PR descriptions)
- ❌ Any reference to internal tools

**What CAN be included in public artifacts:**
- ✅ GitHub issue numbers (in PR descriptions only)
- ✅ User-facing impact descriptions
- ✅ Technical context (for PRs)

### Emoji Usage Policy

**CRITICAL: Minimize emoji usage across all outputs.**

- ❌ **NEVER** use emojis in headings or section titles
- ❌ **NEVER** use decorative emojis (✨, 🎉, 🔥, etc.)
- ✅ **ONLY** use functional emojis in bullet lists (✅, ❌, ⚠️) and **sparingly**
- ✅ If in doubt, don't use emojis

**Example:**

❌ BAD: `## 🎯 Logros Clave` → Use: `## Logros Clave`
❌ BAD: `- ✅ Feature completada exitosamente 🎉` → Use: `- Feature completada exitosamente`
✅ ACCEPTABLE (sparingly): `- ✅ Tests passing` or `- ❌ Build failed`

### Footer and Attribution Policy

**CRITICAL: NEVER add footers, signatures, or tool attribution to any artifact.**

- ❌ **NEVER** add "Generated with Claude Code" or similar footers
- ❌ **NEVER** add attribution links or tool credits
- ❌ **NEVER** add signatures, timestamps, or meta-commentary at the end of artifacts
- ❌ **NEVER** add robot emojis (🤖) or similar decorative elements
- All artifacts (PR descriptions, manager summaries, stakeholder updates) must end with actual content, not meta-information about how they were created
- This is unprofessional and could get the user fired

### File Integration Rules

1. **Read Work Logs**
   - Use Read tool to read work log files from `dev/active/`
   - Extract metadata from frontmatter (Jira, GitHub, Project, etc.)
   - Read work log entries (chronological)

2. **Create Artifact Files**
   - All artifacts (PR descriptions, summaries, updates) go in `dev/artifacts/`
   - Filename format: `{work-log-name}-{artifact-type}-{timestamp}.md`
   - Get timestamp from injected context (format: YYYY-MM-DD-HHMM)

3. **File-Only Confirmations**
   - Final response: `✅ [Artifact type] created: dev/artifacts/{filename}.md`
   - DO NOT reprint the artifact content (it's in the file)

### Link Formatting Rules

- Use exact formats from `references/link-formats.md`
- Jira: `https://odasoftmx.atlassian.net/browse/{ID}`
- GitHub: `https://github.com/{user}/{repo}/issues/{NUM}`

---

## Workflow 1: PR Description Generation

**When to use:** User wants to create a GitHub Pull Request description

**Template:** `templates/pr-description.md`

**Language:** All communication in English, artifact output in Spanish

**CRITICAL WORKFLOW OVERVIEW:**
1. User provides work log filename
2. **GITFLOW TARGETING (NEVER SKIP)**: You detect source branch and determine target using gitflow (hotfix/* → main, feature/* → develop)
3. **ALWAYS CONFIRM**: Ask user "Detected source: {source}, target: {target}. Is this correct?" and WAIT for response
4. You READ the work log (English, read-only)
5. You analyze git changes
6. You generate a Spanish PR description (once, get user approval)
7. You SAVE to `dev/artifacts/{work-log-name}-pr-{timestamp}.md`
8. You ASK permission to create PR
9. If approved, you create the PR in GitHub with that exact text **using the confirmed target branch**
10. **YOU DO NOT UPDATE STATUS - work stays "In Progress" until merged**

**CRITICAL: Targeting wrong branch (e.g., hotfix → develop) can break production. NEVER skip confirmation.**

### Process:

1. **Gather inputs (English)**
   - Ask: "What's the work log filename (in dev/active/)?"
   - Detect current branch: `git branch --show-current`
   - **Determine target branch using git-flow conventions (NEVER IGNORE):**
     ```
     hotfix/*    → main (or master if main doesn't exist)
     feature/*   → develop
     release/*   → main (or master if main doesn't exist)
     bugfix/*    → develop
     claude/*    → Ask user for target branch
     ```
   - **ALWAYS confirm with user**: "Detected source branch: {source}, target branch: {target}. Is this correct?"
   - **WAIT for user confirmation before proceeding**
   - If user says no or provides different target: Use their target instead
   - **CRITICAL: Targeting wrong branch can break production - this is unacceptable**
   - **CRITICAL: You are using an existing work log file**

2. **Analyze context (READ-ONLY)**
   - Use Read tool to read work log file
   - **CRITICAL: The work log is READ-ONLY - you will NOT modify it**
   - Extract from metadata: Jira, GitHub, Project
   - Extract from content: Technical Summary, Goal, Root Cause

3. **Analyze changes (the "what")**
   - Use git tools to inspect changes:
     ```bash
     git diff origin/{target}...{source}
     git log origin/{target}..{source} --oneline
     ```
   - Understand conceptually: goal, approach, reasoning

4. **Draft PR description in Spanish (generate ONCE)**
   - Use format from `templates/pr-description.md`
   - **GENERATE THE DESCRIPTION ONCE - don't regenerate after user approves**
   - **VERIFY output language is Spanish before proceeding**
   - Structure: Resumen, Trabajo Relacionado, Contexto Técnico, Notas para Revisores
   - Tone: Technical, concise, focused on WHY not WHAT
   - **CRITICAL: No line numbers, no file lists, no "Cambios Realizados" section**

5. **Iterate with user (English)**
   - Present draft (in Spanish)
   - Ask (in English): "Does this PR description capture the changes correctly?"
   - Adjust based on feedback
   - Repeat until approved

6. **Save artifact file**
   - Get timestamp from injected context (format: YYYY-MM-DD-HHMM)
   - Get work log base name: e.g., `CM-2765-fix-oauth` from `dev/active/CM-2765-fix-oauth.md`
   - **Save to:** `dev/artifacts/{base-name}-pr-{timestamp}.md`
   - **Content:** The EXACT Spanish PR text approved by user in step 5

7. **Ask permission to create PR**
   - Ask (in English): "Should I create the PR now? (y/n)"
   - If user says no: Stop here and provide artifact file path
   - If user says yes: Proceed to step 8

8. **Create PR in GitHub**
   - **CRITICAL: If user says code is already committed/pushed, DO NOT commit again**
   - **CRITICAL: "Create a PR" means use gh pr create, NOT git commit**
   - **CRITICAL: Use the target branch you confirmed with user in step 1**
   - **NEVER use git rebase, git push --force, or any destructive git operations**
   - **Create PR using gh CLI:**
     ```bash
     gh pr create --base {CONFIRMED_TARGET} --head {source} --title "{title}" --body "{EXACT approved PR text in Spanish from step 6}"
     ```
   - **Verify the body contains NO footers or "Generated with" signatures**
   - **CRITICAL: DO NOT modify work log file**
   - **CRITICAL: DO NOT update Status to "Done"**
   - Creating a PR does NOT complete the work - it stays "In Progress" until merged

9. **Confirm (English)**
   - If PR was created: `✅ PR created: [GitHub PR URL]`
   - `✅ PR description saved to: dev/artifacts/{filename}.md`
   - `⚠️ Work remains "In Progress" - NOT marked as Done (will be Done after merge)`

---

## Workflow 2: Manager Summary Generation

**When to use:** User wants to generate a Spanish summary for a technical manager

**Template:** `templates/manager-summary.md`

**Language:** All communication in English, artifact output in Spanish

**CRITICAL WORKFLOW OVERVIEW:**
1. User provides work log filename or Jira issue
2. You FIND the work log file (search dev/active/ if needed)
3. You READ the work log (it's in English, don't touch it)
4. You generate a Spanish manager summary (once, concisely)
5. You SAVE to `dev/artifacts/{work-log-name}-manager-{timestamp}.md`
6. You post the summary to Jira as a comment
7. **YOU DO NOT UPDATE STATUS - manager summaries don't complete work**

### Process:

1. **Find the work log file (English)**
   - **CRITICAL: You are FINDING an existing work log file**
   - If user provides filename: Use that directly
   - If user provides Jira URL: Search `dev/active/` for file with that Jira in metadata
   - Use: `grep -l "Jira: .*{jira-id}" dev/active/*.md`
   - If not found: STOP and tell user no work log exists

2. **Analyze context (READ-ONLY)**
   - Use Read tool to read work log file
   - **CRITICAL: The work log is READ-ONLY - you will NOT modify it**
   - Extract from ENGLISH work log:
     - Context (what system/component)
     - Technical root cause (conceptual, not line-by-line)
     - Solution applied (logical changes)
     - Metrics/data
     - Next steps/blockers

3. **Draft manager summary in Spanish (generate ONCE)**
   - Use format from `templates/manager-summary.md`
   - **GENERATE THE SUMMARY ONCE - don't regenerate**
   - **VERIFY output language is Spanish before proceeding**
   - **CRITICAL RULES:**
     - BE CONCISE - 2-3 paragraphs max, clear and direct
     - DO NOT FABRICATE - Only summarize from sources
     - CONCEPTUAL SUMMARY, NOT DIFF - Explain logic, not line changes
     - NO GITHUB DUPLICATION - No code snippets, line numbers, SHAs
     - NO DECORATIVE FORMATTING - No emojis, no excessive bullets
     - NO INVENTED DATES
     - WRITE LIKE A HUMAN - Clear, direct, professional
   - Tone: Strategic, high-level, business-impact focused, CONCISE

4. **Save artifact AND post to Jira**
   - Get timestamp from injected context (format: YYYY-MM-DD-HHMM)
   - Get work log base name from filename
   - **Save to:** `dev/artifacts/{base-name}-manager-{timestamp}.md`
   - **Content:** The EXACT Spanish summary from step 3
   - **Post comment to Jira using acli:**
     ```bash
     acli jira workitem comment create --key "{jira-issue-key}" --body "{EXACT Spanish manager summary from step 3}"
     ```
   - Extract Jira issue key from work log metadata
   - **CRITICAL: DO NOT modify work log file**
   - **CRITICAL: DO NOT update Status to "Done"**
   - DO NOT ask for approval (one-shot action)

5. **Confirm (English)**
   - `✅ Manager summary posted to Jira: [Jira issue URL]`
   - `✅ Manager summary saved to: dev/artifacts/{filename}.md`
   - DO NOT reprint the summary text

---

## Workflow 3: Stakeholder Update Generation

**When to use:** User wants to create a non-technical update for stakeholders

**Template:** `templates/stakeholder-update.md`

**Language:** All communication in English, artifact output in Spanish

**CRITICAL WORKFLOW OVERVIEW:**
1. User provides work log filename
2. You READ the work log (English, read-only)
3. You generate a Spanish stakeholder update (once, get user approval)
4. You SAVE to `dev/artifacts/{work-log-name}-stakeholder-{timestamp}.md`
5. You post the update to GitHub issue as a comment
6. **YOU DO NOT UPDATE STATUS - stakeholder updates don't complete work**

### Process:

1. **Gather inputs (English)**
   - Ask: "What's the work log filename (in dev/active/)?"
   - If missing: STOP and ASK

2. **Analyze work log (READ-ONLY)**
   - Use Read tool to read work log file
   - **CRITICAL: The work log is READ-ONLY - you will NOT modify it**
   - Focus on:
     - Business Impact / Goal sections
     - User-facing changes
   - Ignore:
     - Implementation details
     - Code specifics
     - Architecture

3. **Draft stakeholder update in Spanish (generate ONCE)**
   - Use format from `templates/stakeholder-update.md`
   - **GENERATE THE UPDATE ONCE - don't regenerate after user approves**
   - **VERIFY output language is Spanish before proceeding**
   - **Tone:** Professional, non-technical, business value focused, CONCISE
   - **Avoid:** Technical jargon (OAuth, API, token, endpoint, etc.)
   - **DO NOT FABRICATE:** Only summarize what's in the work log

4. **Iterate with user (English)**
   - Present draft (in Spanish)
   - Ask (in English): "Does this stakeholder update communicate the changes clearly?"
   - Adjust based on feedback
   - Repeat until approved

5. **Save artifact AND post to GitHub**
   - Get timestamp from injected context (format: YYYY-MM-DD-HHMM)
   - Get work log base name from filename
   - **Save to:** `dev/artifacts/{base-name}-stakeholder-{timestamp}.md`
   - **Content:** The EXACT Spanish update approved by user in step 4
   - **Post comment to GitHub issue using gh CLI:**
     ```bash
     gh issue comment {issue-number} --body "{EXACT approved Spanish stakeholder update from step 4}"
     ```
   - Extract issue number from work log metadata
   - Ensure you're in the correct repository or use `--repo user/repo` flag
   - **CRITICAL: DO NOT modify work log file**
   - **CRITICAL: DO NOT update Status to "Done"**

6. **Confirm (English)**
   - `✅ Stakeholder update posted to GitHub: [GitHub issue URL]`
   - `✅ Stakeholder update saved to: dev/artifacts/{filename}.md`

---

## References

When you need detailed information:

- **Link formats:** Read `references/link-formats.md` for Jira/GitHub/code/commit URL construction patterns
- **PR description:** Read `templates/pr-description.md` for PR format and tone guidelines
- **Manager summary:** Read `templates/manager-summary.md` for Spanish manager format and critical rules
- **Stakeholder update:** Read `templates/stakeholder-update.md` for non-technical Spanish format

**Note:** For basic work logging instructions, see CLAUDE.md (not this skill).

---

## Common Patterns

### Multi-Output Request

**User:** "I finished the OAuth fix. Create PR description and manager summary."

**Your response:**
1. Identify both outputs requested: PR + manager summary
2. Detect branches and confirm with user
3. Read work log file once (shared context)
4. Load `templates/pr-description.md`
5. Generate PR description
6. Iterate with user until approved
7. Save artifact
8. Ask permission to create PR
9. If approved, create PR
10. Load `templates/manager-summary.md`
11. Generate manager summary
12. Save artifact and post to Jira immediately (no approval needed)
13. Confirm both completed

---

## Error Handling

### File Read Fails
- Verify filename is correct
- Check file exists in dev/active/
- Ask user for the correct filename

### Artifact Save Fails
- Ensure dev/artifacts/ directory exists (create if needed)
- Check markdown is valid
- Retry the operation

### User Blocks During Iteration
- If user rejects draft, ask what to change
- Make adjustments
- Re-present for approval
- Don't proceed until approved

---

## Success Criteria

You've completed your job when:

- ✅ For PR: Draft approved by user, artifact saved, PR created in GitHub (only if user approves PR creation), paths provided
- ✅ For manager summary: Summary generated, comment posted to Jira using `acli`, artifact saved, paths provided (in Spanish)
- ✅ For stakeholder update: Draft approved by user, comment posted to GitHub issue using `gh issue comment`, artifact saved, paths provided

---

## Important Notes

- **NEVER Update Status:** Creating artifacts (PR descriptions, manager summaries, stakeholder updates) does NOT complete work. NEVER modify work log Status. Work stays "In Progress" until merged and deployed.
- **Language Awareness:** All artifacts (PR, manager, stakeholder) use Spanish. Agent ↔ user communication uses English.
- **Approval Gates:** PR descriptions and stakeholder updates require user approval for content AND for posting to GitHub. Manager summaries are one-shot (no approval).
- **Work Logging:** Basic work logging is NOT handled by this skill - see CLAUDE.md for those directives.
- **URL Construction:** Always use full, absolute URLs per `references/link-formats.md`.
- **No Redundant Content:** Never reprint artifact content; just provide file path.
