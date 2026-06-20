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

This bank is intentionally scoped to `/home/carlos/Development/ME/herding-cats`
for Codex recall. It is not the general Codex fallback.

The XBOL profile uses a separate memory:

- `OPENVIKING_ACCOUNT=xbol`
- `OPENVIKING_USER=carlos`
- `OPENVIKING_AGENT=xbol`
- `OPENVIKING_AGENT_ID=xbol`

OpenCode is configured with the same default identity through
`openviking-config.json`.

## Codex Memory

Codex uses a local copy of OpenViking's Codex memory plugin. The checked-in
plugin is rendered into a local Codex marketplace/cache entry by:

```bash
openviking-codex-plugin-install
```

The shell wrapper in `openviking-codex.zsh` reads `~/.openviking/ovcli.conf`
before launching `codex`, exports the resolved OpenViking URL and identity for
the MCP endpoint, and keeps Codex's cached `.mcp.json` pointed at the local
`/mcp` endpoint. Lifecycle hooks select their read/write identity from
`codex-memory-plugin/scope-map.json`.

Unmapped Codex work uses a separate general identity:

- `OPENVIKING_ACCOUNT=general`
- `OPENVIKING_USER=carlos`
- `OPENVIKING_AGENT_ID=general`

Project-specific memory is selected by `codex-memory-plugin/scope-map.json`.
The dotfiles repo maps `/home/carlos/.dotfiles` to its own isolated memory:

- `OPENVIKING_ACCOUNT=dotfiles`
- `OPENVIKING_USER=carlos`
- `OPENVIKING_AGENT_ID=dotfiles`
- `generalFallback=false`

The XBOL scope maps paths under `/home/carlos/Development/XBOL` to:

- `OPENVIKING_ACCOUNT=xbol`
- `OPENVIKING_USER=carlos`
- `OPENVIKING_AGENT_ID=xbol`
- `generalFallback=false`

The Herding Cats scope maps `/home/carlos/Development/ME/herding-cats` to the
legacy local development bank:

- `OPENVIKING_ACCOUNT=local-dev`
- `OPENVIKING_USER=carlos`
- `OPENVIKING_AGENT_ID=local-dev`
- `generalFallback=false`

Codex recall searches the active project scope first. Scopes can opt into
general memory fallback, but XBOL, dotfiles, and Herding Cats are intentionally
isolated so unrelated project memories do not cross workspaces. Codex capture
writes only to the active scope. This is OpenViking shared memory; it is not a
sync layer for Codex's native memory feature.
