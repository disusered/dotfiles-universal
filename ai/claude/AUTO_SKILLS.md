# Automatic Skill Activation System

This document explains the automatic skill activation system integrated from the [claude-code-infrastructure-showcase](https://github.com/diet103/claude-code-infrastructure-showcase) repository, adapted for Markdown-based work logging.

## Overview

The automatic skill activation system uses hooks and configuration to suggest relevant skills based on:

- **User prompts** - Keywords and intent patterns in your requests
- **File changes** - Types of files being edited

This ensures Claude automatically recommends the right skills without explicit invocation.

**Key Adaptation:** This implementation uses **Markdown files** for work logging instead of Notion, following the showcase's file-based approach.

## Components

### 1. Skill Rules Configuration

**File:** `ai/claude/skills/skill-rules.json`

Defines when skills should be activated based on:

- **Prompt triggers**: Keywords and regex patterns in user messages
- **Priority levels**: critical, high, medium, low
- **Enforcement**: suggest (recommend) or block (require)
- **Skill types**: domain (workflow), tool (CLI), guardrail (validation)

**Example:**

```json
{
  "work-journal": {
    "type": "domain",
    "enforcement": "suggest",
    "priority": "high",
    "triggers": {
      "promptTriggers": {
        "keywords": ["PR description", "manager summary"],
        "intentPatterns": ["generate.*pr.*description"]
      }
    }
  }
}
```

### 2. Hooks

#### skill-activation-prompt (UserPromptSubmit)

**Files:**

- `ai/claude/hooks/skill-activation-prompt.sh`
- `ai/claude/hooks/skill-activation-prompt.ts`

**What it does:**

- Runs before Claude processes your prompt
- Checks if your message matches any skill triggers
- Suggests relevant skills with priority information
- Provides examples of how to invoke them

**Example output:**

```
## Detected Relevant Skills

### High Priority (Recommended)

**work-journal** - Generate audience-specific communications
  - Type: domain
  - Match: keyword

**Action Required:**
Consider using the Skill tool with command "work-journal"
```

#### post-tool-use-tracker (PostToolUse)

**File:** `ai/claude/hooks/post-tool-use-tracker.sh`

**What it does:**

- Runs after file modifications (Edit, Write, MultiEdit)
- Logs file changes to session cache
- Tracks which files and languages were modified
- Skips markdown files (documentation)

**Cache location:** `ai/claude/.cache/tool-use/`

#### inject-time (UserPromptSubmit)

**File:** `ai/claude/hooks/inject-time.sh`

**What it does:**

- Runs before Claude processes every prompt
- Reads JSON input from stdin (per hook specification)
- Injects current time (America/Tijuana timezone) as additional context
- Eliminates need for Claude to run `date` commands during work logging

**Why this approach:**

- UserPromptSubmit hooks inject context visible to Claude throughout the conversation
- Context injection avoids permission prompts entirely (no command execution)
- Follows official pattern from https://code.claude.com/docs/en/hooks.md
- Simpler and more reliable than PreToolUse hooks intercepting Bash commands

### 3. Slash Commands

#### /work-plan

**File:** `ai/claude/commands/work-plan.md`

**Purpose:** Create strategic planning documentation in Markdown

**Use when:** Planning large initiatives, refactors, or complex features

**What it does:**

- Analyzes codebase for current state
- Creates comprehensive plan in dev/active/
- Breaks work into phases with tasks
- Includes risk assessment and success metrics

**Example:**

```
/work-plan refactor authentication to use JWT tokens
```

#### /work-capture

**File:** `ai/claude/commands/work-capture.md`

**Purpose:** Capture session context before conversation reset

**Use when:**

- Approaching token limits
- Taking a break
- Switching conversations

**What it does:**

- Updates work log files with session context
- Captures decisions, discoveries, and next steps
- Preserves "working memory" across resets
- Documents current state and blockers

**Example:**

```
/work-capture
```

## Configured Skills

### work-journal

**Type:** Domain workflow

**Triggers when you mention:**

- "PR description", "pull request description"
- "manager summary", "resumen para manager"
- "stakeholder update", "post to github"

**What it does:** Generates audience-specific communications from Markdown work logs

### gh

**Type:** CLI tool

**Triggers when you mention:**

- "github", "gh issue", "gh pr"
- "pull request", "create issue"
- "comment on issue"

**What it does:** Provides GitHub CLI reference and syntax

### jira

**Type:** CLI tool

**Triggers when you mention:**

- "jira", "acli"
- "jira issue", "jira comment"
- "workitem"

**What it does:** Provides Jira CLI (acli) reference and syntax

### ast-grep

**Type:** CLI tool

**Triggers when you mention:**

- "ast-grep", "search code"
- "find function", "find class"
- "structural search", "find all uses"

**What it does:** Provides structural code search reference and patterns

## How It Works

### User Experience Flow

1. **You type a request** mentioning keywords like "create PR description"
2. **skill-activation-prompt hook runs** and detects "PR description" matches work-journal
3. **Claude receives notification** showing work-journal is relevant
4. **Claude uses the Skill tool** to load work-journal automatically
5. **You get the right workflow** without explicitly requesting it

### Behind the Scenes

```
User Input → UserPromptSubmit Hook → skill-rules.json Check → Matched Skills → Claude Context
                                                                                      ↓
                                                                              Skill Tool Invocation
                                                                                      ↓
                                                                            Correct Workflow Activated
```

## Customization

### Adding New Skills

1. **Create the skill** in `ai/claude/skills/[skill-name]/SKILL.md`

2. **Add to skill-rules.json:**

```json
{
  "your-skill": {
    "type": "domain",
    "enforcement": "suggest",
    "priority": "medium",
    "description": "What your skill does",
    "triggers": {
      "promptTriggers": {
        "keywords": ["keyword1", "keyword2"],
        "intentPatterns": ["regex.*pattern"]
      }
    }
  }
}
```

3. **Test:** Try using the keywords in a prompt and verify the hook suggests your skill

### Modifying Triggers

Edit `ai/claude/skills/skill-rules.json`:

- **Add keywords:** Direct substring matches (case-insensitive)
- **Add patterns:** Regex patterns for intent matching
- **Change priority:** critical/high/medium/low
- **Change enforcement:** suggest (recommend) or block (require)

### Disabling Hooks

Edit `ai/claude/settings.json` and remove the hook entries:

```json
{
  "hooks": {
    // Comment out or remove to disable
    // "UserPromptSubmit": { ... }
  }
}
```

## Requirements

### For skill-activation-prompt hook

- Node.js and npx (for running TypeScript)
- tsx package: `npm install -g tsx`

Or install dependencies locally:

```bash
cd ai/claude/hooks
npm init -y
npm install tsx @types/node
```

### For post-tool-use-tracker hook

- bash
- jq (JSON processor)

## Troubleshooting

### Hook not running

1. **Check permissions:**

   ```bash
   ls -l ai/claude/hooks/*.sh
   # Should show -rwxr-xr-x
   ```

2. **Make executable if needed:**

   ```bash
   chmod +x ai/claude/hooks/*.sh
   ```

3. **Check settings.json syntax:**

   ```bash
   cat ai/claude/settings.json | jq .
   ```

### Skill not suggested

1. **Check skill-rules.json:**
   - Is the skill listed?
   - Are keywords spelled correctly?
   - Is the JSON valid?

2. **Test the trigger:**
   - Try the exact keyword from skill-rules.json
   - Check if pattern is case-sensitive

3. **Check hook output:**
   - Hooks run silently by default
   - Add `set -x` to shell scripts for debugging

### TypeScript errors

1. **Install dependencies:**

   ```bash
   cd ai/claude/hooks
   npm install tsx @types/node
   ```

2. **Check Node.js version:**

   ```bash
   node --version
   # Should be v16 or higher
   ```

## Credits

This automatic skill activation system is adapted from the [claude-code-infrastructure-showcase](https://github.com/diet103/claude-code-infrastructure-showcase) repository by diet103, with modifications for our Markdown-based workflow.

Key adaptations:

- Changed directory structure from `.claude/` to `ai/claude/`
- Adapted for **Markdown work logging** instead of Notion (following showcase's file-based approach)
- Configured skills for our specific tools (gh, acli, ast-grep)
- Simplified post-tool-use-tracker for our use case
- Updated hooks format for latest Claude Code version

## See Also

- [CLAUDE.md](./CLAUDE.md) - Core directives and work logging
- [skills/work-journal/SKILL.md](./skills/work-journal/SKILL.md) - Work journal skill documentation
- [skills/tools/gh/SKILL.md](./skills/tools/gh/SKILL.md) - GitHub CLI skill
- [skills/tools/ast-grep/SKILL.md](./skills/tools/ast-grep/SKILL.md) - ast-grep skill
