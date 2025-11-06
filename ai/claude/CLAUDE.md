## 🏠️ Baseline rules

- `cd` is not the default command, it is zoxide via `eval "$(zoxide init --cmd cd zsh)"`
- Use the shell's `builtin cd` to change directories, zoxide-bound `cd` will fail.
- `ls` is not the default command, it is bound to `exa`
- Commit messages should be limited to 80 characters in length

## ⚡ Core Directives: Notion Work Tracking

**IMPORTANT**: This project uses the **Notion MCP** for ALL work and issue tracking.

### Core Policy

- ✅ **ALWAYS** create a Notion page **before** starting any multi-step task
- ✅ **ALWAYS** log work as it happens (append to the page), not at the end
- ❌ **DO NOT** use markdown TODOs, local files, or other tracking methods
- ❌ **DO NOT** guess required properties - if missing, **STOP and ASK the user**
- ❌ **DO NOT** print summaries when finished - **report completion ONLY with the URL**
  - **Correct:** "✅ Task complete. The work has been logged to Notion: [URL]"
  - **Incorrect:** "Perfect! I've logged... Summary: ..."

### When to Track Work

Proactively create Notion pages when starting ANY multi-step task:
- Investigation/debugging
- Feature development
- Bug fixes
- Code refactoring
- Any work requiring multiple commands/steps

### Required Properties

- **Priority** (0-4): 0=Critical, 1=High, 2=Medium, 3=Low, 4=Backlog
- **Project** (string): Team or project name
- **Type** (enum): `bug`, `feature`, `task`, `epic`, or `chore`

**GitHub and Jira are OPTIONAL** - only include if user explicitly mentions them.

### Notion Database

- **Data Source:** `collection://2a0d1aba-3b72-8031-aedc-000b7ba2c45f`
- All work pages **MUST** use this as parent: `{"data_source_id": "2a0d1aba-3b72-8031-aedc-000b7ba2c45f"}`

---

**Note:** Detailed workflow implementation is handled by the `work-journal` skill (see `~/.claude/skills/work-journal/`).
