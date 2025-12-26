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

All commands follow the same pattern:
- No args = show current state
- `--list` = show available options
- `--set X=Y --apply` = change + apply

```bash
# Update (render + symlink + reload)
cfg update              # Update all
cfg update --list       # List available templates
cfg update mako kitty   # Update specific templates
cfg update --dry-run    # Preview without writing

# Theme
cfg theme               # Show current (flavor, accent, secondary)
cfg theme --list        # Show palette colors
cfg theme --get accent  # Get specific value
cfg theme --set accent=green              # Set value only
cfg theme --set accent=green --apply      # Set + update all
cfg theme --set accent=green --apply mako # Set + update specific

# Font
cfg font                # Show current (mono, sans, sizes)
cfg font --list         # List available fonts (stub)
cfg font --get mono     # Get specific value
cfg font --set mono=X --apply  # Set + update (stub)
```

## Pipeline

On a new machine:

```bash
cfg render          # Generate configs + symlink
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
