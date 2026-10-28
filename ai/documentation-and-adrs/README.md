# Documentation and ADRs

Upstream `documentation-and-adrs` skill from Addy Osmani's
`addyosmani/agent-skills`, used to write ADRs, README files, comments and
changelogs. It lives in `~/.agents/skills/documentation-and-adrs`, where Codex
and Antigravity discover it; Claude Code uses the tracked link
`ai/claude/skills/documentation-and-adrs`.

The install is pinned to commit `aeac41d4d005999432bb7312f7ff06383a91d59d`
and checks the SHA-256 of `SKILL.md`. Keep the skill's contents unchanged.

```sh
~/.rotz/bin/rotz install /ai/documentation-and-adrs
```

## Update

Review the upstream diff for `skills/documentation-and-adrs`, then set `REF`
and `SHA256` in `dot.yaml` to the new commit and its `SKILL.md` hash, and rerun
the install. A hash mismatch reinstalls the skill.

Sources:

```text
- https://www.skills.sh/addyosmani/agent-skills/documentation-and-adrs
- https://github.com/addyosmani/agent-skills/tree/aeac41d4d005999432bb7312f7ff06383a91d59d/skills/documentation-and-adrs
```
