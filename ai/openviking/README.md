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
the local development memory:

- `OPENVIKING_ACCOUNT=local-dev`
- `OPENVIKING_USER=carlos`
- `OPENVIKING_AGENT=local-dev`
- `OPENVIKING_AGENT_ID=local-dev`

The XBOL profile uses a separate memory:

- `OPENVIKING_ACCOUNT=xbol`
- `OPENVIKING_USER=carlos`
- `OPENVIKING_AGENT=xbol`
- `OPENVIKING_AGENT_ID=xbol`

Claude Code, Codex, and OpenCode are not wrapped by this module. If those tools
need OpenViking later, use their official OpenViking plugin setup and point them
at the same account/agent identity instead of creating tool-specific silos.
