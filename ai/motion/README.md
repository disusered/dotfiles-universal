# Motion AI Kit

Free Motion AI Kit setup for Codex and Claude Code. The upstream `motion` skill
lives in `~/.agents/skills/motion`; Codex discovers it there, and Claude Code
uses a symlink from `~/.claude/skills/motion`.

The skill comes from `motiondivision/ai-kit`, directory
`plugins/motion/skills/motion`, pinned to commit
`b7e2c68fb3b159b6c849d4d2c5c7a17b408689fc` (the source tree for motion-ai 14.2.0).
Keep its contents unchanged.

## Install

Run the Codex skill-installer helper with Python 3:

```sh
python3 "$HOME/.codex/skills/.system/skill-installer/scripts/install-skill-from-github.py" --repo motiondivision/ai-kit --path plugins/motion/skills/motion --ref b7e2c68fb3b159b6c849d4d2c5c7a17b408689fc --dest "$HOME/.agents/skills" --method download
```

Create the Claude link using an absolute target. Claude's skills directory is
itself a symlink into this repository, so a relative target would resolve from
the repository directory.

```sh
ln -s "$HOME/.agents/skills/motion" "$HOME/.claude/skills/motion"
claude mcp add --scope user --transport http motion https://mcp.motion.dev
```

Codex's `motion` MCP entry is maintained in `ai/codex/config.toml`, linked to
`~/.codex/config.toml` by the existing Codex Rotz module. Claude stores its
registration in `~/.claude.json`. The skill and Claude registration are local
installations; `rotz link` alone does not recreate them.

The commands above assume Motion is not installed. Before reinstalling, check
the existing skill, link, and server registration instead of replacing them
blindly. The skill-installer refuses an existing destination.

## Use and verify

The skill is available on the next turn after discovery refresh; start fresh
Codex and Claude Code sessions to load the MCP server as well. Ask `/motion`
about an API or request animation guidance.

```sh
codex mcp get motion --json
claude mcp get motion
```

The public server requires no account. During setup on 2026-10-17, its tool
catalog exposed `search-motion-docs`; use it to search, then read the returned
documentation resources. The skill also includes local animation best practices.

MotionScore audits, premium source, and other Motion+ capabilities are not
enabled. The unchanged upstream skill includes their instructions, but this
setup does not register `motion-plus` or perform authentication.

## Update

Review a new upstream commit and record its full SHA here. Move the current
`~/.agents/skills/motion` directory to a backup outside the skills directories,
then repeat the installer command with the new SHA. Keep the Claude symlink and
MCP registrations. Verify skill discovery and a documentation search before
removing the backup. To roll back, restore the backed-up directory.

Avoid the all-in-one `npx motion-ai` installer for this free-only setup: it
registers both hosted servers and writes skills into each selected agent's
directory.

Sources:

```text
- https://motion.dev/docs/ai-kit-install
- https://github.com/motiondivision/ai-kit/tree/b7e2c68fb3b159b6c849d4d2c5c7a17b408689fc
```
