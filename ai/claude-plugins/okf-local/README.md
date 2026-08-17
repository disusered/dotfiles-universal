# Local OKF Claude plugin

This plugin packages the shared `okf-knowledge-ops` skill and configures one
local stdio MCP process for Claude Code. The process loads exactly the
configured repository's `.agents/okf.yaml`; it does not infer a knowledge
directory.

The default configuration points to Iteramind, its independent `okf-mcp` child
project, and `/usr/bin/uv`. Change the configured paths to reuse the same server
with a different root-local adapter or on another operating system. Run one
plugin/server instance per adapter.

In the current Claude Desktop build, uploading this plugin through Customize
installs the skill but does not launch its `.mcp.json` process. Desktop therefore
uses the companion MCPB built by the `okf-mcp` project for the eight local
`okf_*` tools. The skill can also be used in web Chat and Cowork, but remote
surfaces cannot reach the local process; they need a separately hosted remote
MCP connector for tool parity.

OpenViking remains a separate memory provider. Its contextual recall never
overrides authored OKF.
