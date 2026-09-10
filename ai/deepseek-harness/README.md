# DeepSeek Harness

DeepSeek Harness (`dsh`) runs as the Herding Cats operator: a systemd user
service booting the harness Web UI on `127.0.0.1:43120`, published to the
tailnet as `harness.disusered.com` through the Caddy module.

The harness home is `~/.dsh` and the pinned runtime is
`~/.local/share/deepseek-harness/runtime` (`@deepseek-ai/dsh@0.1.0-rc.6`). The
`dsh` launcher on `PATH` boots that pinned runtime and injects
CLIProxyAPI's local client token when it exists.

## Install

```bash
~/.rotz/bin/rotz install /ai/deepseek-harness
```

The install pins the runtime, links this module's files, and enables the
`deepseek-harness.service` user unit. New `.dsh` versions are adopted by
changing the version in `dot.yaml`, not by installing globally.

## Models

`profiles/web/cordis.patch.yml` is the deployment's routing layer. New sessions
default to DeepSeek V4.1 Flash over DeepSeek's own API
(`provider: deepseek-official`, `model: deepseek-flash`), and the model picker
advertises that model plus GPT-5.6 Sol through CLIProxyAPI. DeepSeek web search
runs on the same key and model.

`deepseek-flash` is DeepSeek V4.1 Flash. DeepSeek retired `deepseek-v4-flash`
and `deepseek-v4-pro`; the API still accepts both legacy names and serves
them with V4.1 Flash, so configuration should name the canonical id.

The patch is symlinked live into `~/.dsh/profiles/web/cordis.patch.yml`, and a
running harness watches that file and re-composes, so edits apply without a
restart. Restart the unit if a composed change does not appear:

```bash
systemctl --user restart deepseek-harness.service
```

## DeepSeek credential

The key is machine-local state, never repository content. Store it once in the
harness itself: open Settings → Models, enter the DeepSeek API key in the
DeepSeek card, and save. The harness writes it to `~/.dsh/.credentials.yaml`
(mode `0600`, owner-only directory) and keeps only a redacted reference in
settings, so the value is never echoed back to the page.

Use the same credential as the Codex module:
`op://Personal/Deepseek/credential`.

## Theme

The Web UI wears the machine's Catppuccin palette. DSH ships its palette as
two CSS layers of `--dsw-*` custom properties on `body` — a static literal
layer and a semantic alias layer defined purely as `var()` indirections. The
`cfg-theme` client plugin re-points the **static** layer at the cfg theme and
leaves the alias layer alone, so every semantic token keeps its designed
meaning and the whole interface re-tints at once.

| Piece | Path |
| --- | --- |
| Template (source of truth) | `plugins/cfg-theme/lib/client.js.tera` |
| Rendered bundle | `plugins/cfg-theme/lib/client.js` |
| Host half | `plugins/cfg-theme/lib/index.js` |
| Registry entry | `cfg/templates.toml` → `dsh-theme` |
| Installed plugin | `~/.dsh/plugins/cfg-theme` (symlink to this module) |
| Profile resolution | `~/.dsh/profiles/node_modules/cfg-theme` → the plugin |
| Activation row | `$DSH_HOME/cordis.patch.yml` (hand-written by the install step) |

Dark mode wears the active cfg flavor (`flavor` in `cfg/config.toml`, whose
palette also supplies the reminder, status, and accent hues). Light mode wears
Catppuccin Latte, the light counterpart of that flavor; `primary` supplies the
accent in both modes and `secondary` supplies the error ramp, so
`cfg theme --set primary=pink --apply` moves the harness with every other
themed surface.

Re-render after editing the template:

```bash
cfg update dsh-theme
```

The harness watches the bundle, so a re-rendered `client.js` reaches a live
browser within seconds. A brand-new plugin package or composition row only
reaches an already-running service when that service re-composes: restart the
unit, or run the profile patch path the harness watches.

## Verify a change

```bash
dsh --profile web --dump-config | grep -A8 'llm-deepseek'
dsh --profile web --dump-config | grep -A3 cfg-theme
dsh --profile headless --patch ~/.dsh/profiles/web/cordis.patch.yml "Reply with OK"
```

The dump shows the composed rows; the headless run performs one real request
through the deployment's composition. The Web UI's Models page shows the
stored credential (redacted) and the model picker groups the routes by
provider.
