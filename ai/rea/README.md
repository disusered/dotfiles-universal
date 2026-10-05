# REA

Arch Linux setup for [REA](https://github.com/morluto/rea) (`rea-agents@3.2.1`),
an MCP server and CLI for reverse engineering applications and binaries, using
Ghidra 12.1.4 as its read-only native analysis provider.

```sh
~/.rotz/bin/rotz install /ai/rea
```

REA accepts only the official Ghidra 12.1.4 release with a full JDK 21. Arch's
`ghidra` package is a different version, so the module downloads the release,
checks its published SHA-256, and extracts it to `~/.local/opt`. The JDK comes
from `/languages/java/21` through sdkman and does not change the default JDK.

REA needs Node `^22.19.0 || >=24.11.0`. The mise default is older, so the server
runs under the system Node with `PATH=/usr/bin:/bin`. Use the same environment
for the CLI:

```sh
PATH=/usr/bin:/bin GHIDRA_INSTALL_DIR=~/.local/opt/ghidra_12.1.4_PUBLIC \
  JAVA_HOME=~/.sdkman/candidates/java/21.0.12+1.1-tem \
  npx -y rea-agents@3.2.1 doctor --json
```

The module registers Claude Code's user server if it is absent, and installs
the bundled `reverse-engineer-anything` skill from the same npm package into
`~/.agents/skills`, with a link from `~/.claude/skills`. Codex's server lives in
`ai/codex/config.toml`. Do not run `rea setup` for agent integration: it would
rewrite the linked Codex config. When upgrading, update the version pins here,
in `dot.yaml`, and in the Codex config, and update the skill version check.
