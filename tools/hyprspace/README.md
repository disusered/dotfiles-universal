# hyprspace

Config-driven Hyprland special workspace manager. Replaces per-workspace bash scripts with a single binary that reads workspace definitions from TOML config.

## Installation

Managed by [Rotz](https://github.com/volllly/rotz):

```bash
~/.rotz/bin/rotz install /tools/hyprspace
```

This builds the binary and symlinks it to `~/.local/bin/hyprspace`, and the config to `~/.config/hyprspace/config.toml`.

## CLI

```
hyprspace toggle <workspace>    # Context-aware show/hide
hyprspace spawn <workspace>     # Spawn new instance (multi-instance only)
hyprspace raw <workspace>       # Bare togglespecialworkspace
hyprspace dismiss-scratchpads   # Dismiss pyprland scratchpads
```

## Config format

```toml
[scratchpads]
names = ["btop", "fastfetch"]

[workspaces.ai]
window_class = "claude_modal"       # Required: window class to match
title_prefix = "claude: "           # Optional: prefix for context titles
context_type = "cwd"                # none | cwd | git_root (default: none)
multi_instance = true               # Allow multiple instances (default: false)
dismiss_scratchpads = true          # Hide scratchpads on toggle (default: true)
extra_classes = ["chrome-gemini.google.com__-Default"]  # Additional classes to match
spawn_command = ["kitty", "--class", "claude_modal", "--title", "{title}", "--directory", "{context}", "--hold", "claude"]
```

Placeholders in `spawn_command`:
- `{title}` — resolved context title (e.g. `claude: /home/user/project`)
- `{context}` — raw context path

## Keybinding pattern

Three-tier binding per workspace:

| Modifier | Command | Behavior |
|----------|---------|----------|
| `SUPER` | `toggle` | Context-aware show/hide with window matching |
| `SUPER SHIFT` | `spawn` | Force new instance (multi-instance workspaces) |
| `SUPER CTRL` | `raw` | Bare `togglespecialworkspace`, no logic |

## Adding a new workspace

1. Add a `[workspaces.<name>]` section to `config.toml`
2. Add a Hyprland `windowrule` block in a `.conf` file assigning the class to `special:<name>`
3. Add keybindings calling `hyprspace toggle/spawn/raw <name>`
4. If the workspace module has a `dot.yaml`, add `/tools/hyprspace` to its `depends`
