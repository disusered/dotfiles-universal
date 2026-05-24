# OpenViking

This module installs OpenViking as a local user service through Podman Quadlet and
links the shared CLI config.

The service is intentionally local-only:

- server bind: `127.0.0.1:1933`
- auth: no root API key and no client API key by default
- vikingbot: disabled
- storage: `~/.local/share/openviking`

The Quadlet uses host networking so OpenViking can remain bound to localhost. If
you publish the container port on `0.0.0.0`, OpenViking requires a root API key.

## First Run

1. Install and link the module:

   ```bash
   ~/.rotz/bin/rotz install /ai/openviking
   ```

2. Run the official setup wizard:

   ```bash
   openviking-init
   ```

   This runs `openviking-server init` inside the same container mount that the
   Quadlet service uses, so the generated `~/.openviking/ov.conf` is ready for
   the service without path rewriting.

3. Start the service:

   ```bash
   systemctl --user daemon-reload
   systemctl --user enable --now openviking.service
   openviking-health
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
