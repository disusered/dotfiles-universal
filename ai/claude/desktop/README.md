# Desktop instructions and skills

`instructions.md` is the maintained personal instruction text for Claude Desktop
and web, tuned for Fable 5.1. Merge it with existing account preferences through
Settings → Instructions for Claude. It is model-neutral where the account may
use another model. Keep project-specific context in the appropriate project.

Claude Code uses the shared global AGENTS source, Plain English output style,
and Opus configuration instead. Its Fable advisor pattern is in `../ADVISOR.md`.
Editing dotfiles does not update Desktop account settings or uploaded skills.

Build the direct skill-upload archives with:

```sh
python3 ai/claude/desktop/package-skills.py
```

Upload the applicable archives from `dist/` through Customize → Skills. Update
an existing matching skill instead of enabling duplicates. These three packages
are local installation artifacts. The local OKF skill needs the appropriate local repository server.

The organization's `okf-shared-bundle` plugin is synced from the private
`iteramind/agent-plugins` GitHub repository. Update its canonical source at
`plugins/okf-shared-bundle/skills/okf-shared-bundle/SKILL.md` in that repository.
Do not upload a personal ZIP or enable a duplicate skill. The hosted connector
remains the tool connection. Local edits do not reach GitHub sync until published
through the repository's authorized workflow.

Keep the installer receipts local: record the saved preference and installed
skill names/versions or hashes after reading them back from the UI. Do not
claim installation from a successful package build alone. If UI access is
blocked, these files remain ready for installation.

Sources:

- [Fable 5.1 prompting](https://platform.claude.com/docs/en/build-with-claude/prompt-engineering/prompting-claude-fable-5-1)
- [Personal instructions](https://support.claude.com/en/articles/10185728-understanding-claude-s-personalization-features)
- [Skills in Claude](https://support.claude.com/en/articles/12512180-use-skills-in-claude)

API-only features such as thinking-block display and conversation-history
transport are owned by Claude Desktop, not configurable through this text.
