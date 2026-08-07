# OpenViking

This module installs OpenViking as a native user service and links the shared
CLI config.

The service runs natively (not containerized) so it has direct access to host
SSH keys, git credentials, and the `gh` CLI for private repository indexing.

The service is intentionally local-only:

- server bind: `127.0.0.1:1933`
- auth: no root API key and no client API key by default
- vikingbot: disabled
- storage: `~/.local/share/openviking`

Private repos are indexed using the GitHub ZIP archive API with `GITHUB_TOKEN`
from `gh auth token`, falling back to `git clone` with host SSH keys.

## First Run

1. Install and link the module:

   ```bash
   ~/.rotz/bin/rotz install /ai/openviking
   ```

2. Render the config with secrets from 1Password:

   ```bash
   openviking-render-config
   ```

3. Start the service:

   ```bash
   systemctl --user daemon-reload
   systemctl --user enable --now openviking.service
   ov health
   ```

## Hermes Memory

Hermes uses its built-in OpenViking memory provider. The default Hermes env is
the legacy Herding Cats/Hermes memory:

- `OPENVIKING_ACCOUNT=local-dev`
- `OPENVIKING_USER=carlos`
- `OPENVIKING_AGENT=local-dev`
- `OPENVIKING_AGENT_ID=local-dev`

This bank is the legacy Herding Cats/Hermes memory and remains the fallback for
paths without a dedicated profile. It is not authoritative for those paths.

The XBOL profile uses a separate memory:

- `OPENVIKING_ACCOUNT=xbol`
- `OPENVIKING_USER=carlos`
- `OPENVIKING_AGENT=xbol`
- `OPENVIKING_AGENT_ID=xbol`

The Iteramind profile uses a separate trusted-development memory:

- `OPENVIKING_ACCOUNT=iteramind-dev`
- `OPENVIKING_USER=carlos`
- `OPENVIKING_AGENT=iteramind-dev`
- `OPENVIKING_AGENT_ID=iteramind-dev`

It applies to `~/Development/ITERAMIND` and descendants. Existing `local-dev`
memory is not migrated into this account.

OpenCode's global configuration uses the default identity. Its shell wrapper
overrides the identity for XBOL and Iteramind based on the launch directory.

## Codex Memory

Codex uses the upstream canonical OpenViking Codex memory plugin, installed
from `~/.openviking/openviking-repo/examples/codex-memory-plugin` via the
upstream installer (`setup-helper/install.sh`). The installer handles
marketplace registration, cache rendering, MCP wiring, and shell wrapper.

Codex native `memories` is disabled (`config.toml`: `memories = false`).
OpenViking is the sole memory system — recall on `UserPromptSubmit`, capture
on `Stop`, commit on `PreCompact`, and sweep on `SessionStart`.

Codex uses `local-dev` by default. Sessions launched from
`~/Development/XBOL` use `ovcli-xbol.conf`; sessions launched from
`~/Development/ITERAMIND` use `ovcli-iteramind.conf`. Start a fresh session
after changing directories because an already-running MCP connection does not
switch accounts.

## Claude Memory

Claude Code uses the upstream OpenViking Claude plugin,
`claude-code-memory-plugin@openviking-plugins-local`, published by the
marketplace at `~/.openviking/openviking-repo/examples`. The plugin supplies
both the lifecycle hooks and the `openviking` MCP server:

- recall: `UserPromptSubmit`
- capture: `Stop`
- commit: `PreCompact`, `SessionEnd`
- resume/subagents: `SessionStart`, `SubagentStart`, `SubagentStop`

`dot.yaml` registers the marketplace and installs the plugin; `settings.json`
enables it. The upstream `setup-helper/install.sh` is deliberately not used —
it is interactive, appends a `claude()` function to `~/.zshrc` that would
compete with the wrapper below, and offers to replace `statusLine`.

Before this, Claude ran the hook scripts hand-wired into `settings.json` with no
MCP server. That was half of the installer's legacy path: recall and capture
worked, but Claude could not open the `viking://` URIs its own recall block
cited.

Read-only MCP tools (`health`, `find`, `search`, `read`, `list`, `grep`, `glob`,
`code_outline`, `code_search`, `code_expand`) are allowed in `settings.json`.
The mutating ones prompt: `remember`, `add_resource`, `cancel_watch`, and
`forget` — `forget` is irreversible and must never be allowlisted.

The shell wrapper linked to `~/.config/zsh/5004_openviking_claude.zsh` selects
the same OpenViking profiles as Codex: `local-dev` by default, `xbol` under
`~/Development/XBOL`, and `iteramind-dev` under `~/Development/ITERAMIND`.

The wrapper also exports the selected profile's `OPENVIKING_ACCOUNT`,
`OPENVIKING_USER`, and `OPENVIKING_URL` into the `claude` process. The hooks
read the config file directly, but the MCP server does not — the plugin's
`.mcp.json` interpolates those variables into request headers. Without the
export, hooks and MCP silently resolve different accounts. Empty fields are
omitted rather than exported empty.

Start a fresh session after changing directories, because an already-running
MCP connection does not switch accounts.

Claude launched without the wrapper (desktop launcher, IDE extension, a bare
`command claude`) sends empty account headers. That degrades safely rather than
silently: the MCP server resolves an empty account, so reads return "nothing
found" instead of another account's memory. The hooks are unaffected — they read
`ovcli.conf` directly. Treat an unexpectedly empty recall as a signal that the
wrapper was bypassed.

Hooks execute from the plugin cache under `~/.claude/plugins/cache`, not from
the repo checkout. `dot.yaml` pulls the repo and then runs
`claude plugin marketplace update` + `claude plugin update`; if those soft-fail,
the checkout looks current while the hooks still run the cached older version.
Check `claude plugin list` for the installed version when behavior disagrees
with the source.
