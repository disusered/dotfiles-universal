# CLIProxyAPI

This Arch Linux module runs [CLIProxyAPI](https://github.com/router-for-me/CLIProxyAPI) as a local, authenticated bridge for OAuth-backed models. It adds a separate `claudex` command for Claude Code with GPT-5.6 Sol while leaving the normal `claude` command and its existing OpenViking wrapper unchanged.

## Install

```bash
~/.rotz/bin/rotz install /ai/cliproxyapi
```

The module installs or updates the `cli-proxy-api-bin` AUR package, force-links its configuration assets, renders the machine-local configuration, and enables and restarts the package-provided `cli-proxy-api.service` user unit. The service reads `~/.cli-proxy-api/config.yaml` and listens on `127.0.0.1:8317`.

Open a new Zsh session after installation, then enroll Codex once:

```bash
cliproxyapi-login-codex
```

The Codex callback uses local port `1455`. The helper forwards additional CLIProxyAPI arguments, including `--no-browser` for a manual browser flow:

```bash
cliproxyapi-login-codex --no-browser
```

Claude OAuth is not required for the Codex-backed `claudex` command. If it is wanted later for other proxy clients, enroll it separately with `cliproxyapi-login-claude`; its callback uses local port `54545`.

OAuth enrollment is intentionally interactive and is not run during the Rotz install.

## Use `claudex`

Run Claude Code through CLIProxyAPI with:

```bash
claudex
claudex -p "Reply with OK"
claudex --effort medium
```

For each invocation, `claudex` reads the current local client token and launches `claude` with:

- `ANTHROPIC_BASE_URL=http://127.0.0.1:8317`
- `ANTHROPIC_AUTH_TOKEN` set to the generated client token
- GPT-5.6 Sol as the main and subagent model
- gateway model discovery enabled for the `/model` picker
- effort enabled, tool-use concurrency limited to `3`, and tool search disabled

Arguments are forwarded unchanged after `--model gpt-5.6-sol`. Continue using `claude` when the proxy-specific model and settings are not wanted.

Run `/model` inside `claudex` to select any model advertised by CLIProxyAPI, including GPT-5.6 Luna, Sol, and Terra. The list is discovered from the local gateway at startup, so newly available models appear without maintaining aliases in this module. Press `s` on a picker row to use it for only the current `claudex` session; pressing Enter saves the choice to the shared Claude user settings.

The picker also exposes effort for supported models: use Left and Right while a row is highlighted. For a launch-time session override, pass Claude Code's `--effort low|medium|high|xhigh|max` option to `claudex`; arguments continue to be forwarded unchanged.

Claude Code treats model discovery as nonessential startup traffic. For `claudex` only, the wrapper allows that authenticated localhost request while retaining the equivalent individual opt-outs for automatic updates, feedback, error reporting, and telemetry. The normal `claude` command keeps the shared `CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC=1` setting unchanged.

## Security and generated state

The tracked `config.yaml.tpl` contains a token placeholder, never a usable secret. `cliproxyapi-render-config` generates a 32-byte random token on first use, reuses it on later renders, and writes the live configuration without printing the token.

Machine-local state is kept outside this repository:

- Client token: `${XDG_STATE_HOME:-$HOME/.local/state}/cliproxyapi/client-token`
- Rendered configuration: `~/.cli-proxy-api/config.yaml`
- OAuth credentials: `~/.cli-proxy-api/`

The proxy binds only to loopback, authenticates normal and WebSocket clients, and disables remote management, its control panel, debug output, file logging, and usage aggregation. The renderer sets the generated token and configuration to mode `0600` and their containing state and authentication directories to `0700`. Neither the generated client token nor OAuth credentials are tracked by Git.

## Service operations

```bash
systemctl --user status cli-proxy-api.service
systemctl --user restart cli-proxy-api.service
journalctl --user -u cli-proxy-api.service -f
```

The unit is supplied by the AUR package at `/usr/lib/systemd/user/cli-proxy-api.service`; this module does not install a replacement unit.

## Rotate the client token

Existing `claudex` invocations keep their current environment, so stop or finish them before rotating the token. Then remove the per-host token, render a replacement, and restart the proxy:

```bash
token_file="${XDG_STATE_HOME:-$HOME/.local/state}/cliproxyapi/client-token"
rm -f -- "$token_file"
cliproxyapi-render-config
systemctl --user restart cli-proxy-api.service
```

New `claudex` invocations read the replacement token automatically. OAuth credentials are independent and do not need to be enrolled again.

## Update

Re-run the module installation to let `yay` apply an available AUR update, relink the tracked assets, rerender the configuration with the existing token, and restart the service:

```bash
~/.rotz/bin/rotz install /ai/cliproxyapi
```

Provider setup follows CLIProxyAPI's [Claude Code](https://help.router-for.me/configuration/provider/claude-code) and [Codex](https://help.router-for.me/configuration/provider/codex) OAuth documentation.
