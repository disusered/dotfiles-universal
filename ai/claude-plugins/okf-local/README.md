# Local OKF Claude plugin

This plugin packages the `okf-knowledge-ops` skill: how to read, validate, and
safely change a governed OKF bundle held as local Markdown.

It no longer configures an MCP server. It used to launch one, a Python process
from the `okf-mcp` project, and that project is archived. Servers are configured
per repository now, because each corpus gets its own and a plugin installs once.

## Reaching a bundle

A harness with file tools does not need a server. Read the Markdown and use the
repository's documented OKF validation commands.

A surface with no filesystem, Claude Desktop above all, reaches the same bundle
through `@disusered/okf-mcp`, a stdio server that serves exactly one bundle from
one repository. Each repository declares its own in a checked-in `.mcp.json`, so
a clone arrives configured. Claude Desktop has no project scope, so its two local
servers live in `~/.config/Claude/claude_desktop_config.json`. Codex reads a
project-local `.codex/config.toml`, which it merges over the global one.

Same files, same profile, same validation rules, whichever door.

## Remote surfaces

Web Chat cannot reach this machine's local process. Cowork uses only files and
tools explicitly available in its environment. Iteramind's hosted shared Bundle
uses the separate `okf-shared-bundle` skill and connector; nothing here serves it.

OpenViking is a separate memory provider. Its contextual recall never overrides
authored OKF.
