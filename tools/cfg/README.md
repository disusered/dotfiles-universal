# cfg - Linux Configuration Manager

A Unix-style CLI tool for managing Linux system configuration. Handles things Rotz can't: theming, fonts, locale, users/groups, and other tedious system administration.

## Installation

The compiled binary is committed to this repo. No Rust toolchain needed on new machines:

```bash
# Symlink binary to PATH (handled by Rotz)
ln -s ~/.dotfiles/tools/cfg/cfg ~/.local/bin/cfg
```

For development (requires Rust):

```bash
cd ~/.dotfiles/tools/cfg
cargo build --release
cp target/release/cfg ./cfg
```

## Usage

```bash
# Render all templates
cfg render --all

# Render a specific template
cfg render mako

# Dry-run (preview without writing)
cfg render --all --dry-run

# Theme commands
cfg theme config                     # Show flavor and accent
cfg theme config --get flavor        # Get specific value
cfg theme config --set accent=green  # Set value
cfg theme palette                    # List all palette colors
cfg theme palette base --format hex-hash   # Get specific color
cfg theme reload --all               # Reload all apps
cfg theme apply                      # Render + reload

# Font commands
cfg font list                        # List all fonts
cfg font list --mono                 # Monospace only
cfg font config                      # Show font settings
```

## Pipeline

On a new machine:

```bash
cfg render --all    # Generate configs from templates
rotz link           # Symlink to system locations
rotz install        # Run installation commands
```

## Color Formats

The `--format` option supports:

| Format | Example | Use Case |
|--------|---------|----------|
| `hex` | `89b4fa` | Default, raw hex |
| `hex-hash` | `#89b4fa` | CSS, most configs |
| `rgb` | `137 180 250` | Space-separated |
| `rgb-css` | `rgb(137, 180, 250)` | CSS |
| `hyprlang` | `rgb(89b4fa)` | Hyprland configs |
| `rgba` | `rgba(137, 180, 250, 0.9)` | CSS with alpha |
| `hyprlang-rgba` | `rgba(89b4fae6)` | Hyprland with alpha |

## Templates

Templates use Tera (Jinja2-compatible) syntax and live alongside their output:

```
tools/mako/
├── config.tera    # Template (committed)
├── config         # Generated (gitignored)
└── dot.yaml       # Rotz links config → ~/.config/mako/config
```

Use vim modeline for native syntax highlighting:

```dosini
# vi: ft=dosini
background-color={{ base_hex }}
text-color={{ text_hex }}
```

Available variables: `{{ blue }}`, `{{ base_hex }}`, `{{ accent_hyprlang }}`, `{{ font_mono }}`, etc.
