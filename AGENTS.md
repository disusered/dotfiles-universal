# Agent Instructions

This project uses **bd** (beads) for issue tracking. Run `bd onboard` to get started.

## Quick Reference

```bash
bd ready              # Find available work
bd show <id>          # View issue details
bd update <id> --status in_progress  # Claim work
bd close <id>         # Complete work
bd sync               # Sync with git
```

## Landing the Plane (Session Completion)

**When ending a work session**, you MUST complete ALL steps below. Work is NOT complete until `git push` succeeds.

**MANDATORY WORKFLOW:**

1. **File issues for remaining work** - Create issues for anything that needs follow-up
2. **Run quality gates** (if code changed) - Tests, linters, builds
3. **Update issue status** - Close finished work, update in-progress items
4. **PUSH TO REMOTE** - This is MANDATORY:

   ```bash
   git pull --rebase
   bd sync
   git push
   git status  # MUST show "up to date with origin"
   ```

5. **Clean up** - Clear stashes, prune remote branches
6. **Verify** - All changes committed AND pushed
7. **Hand off** - Provide context for next session

**CRITICAL RULES:**

- Work is NOT complete until `git push` succeeds
- NEVER stop before pushing - that leaves work stranded locally
- NEVER say "ready to push when you are" - YOU must push
- If push fails, resolve and retry until it succeeds

## Repository Overview

This is a universal dotfiles repository managed by [Rotz](https://github.com/volllly/rotz), a cross-platform dotfile manager. It supports **Linux (Fedora & Arch)**, **macOS**, and **Windows** environments with platform-specific configurations.

## Core Commands

### Rotz Dotfile Management

```bash
# Install dotfiles (apply symlinks and run installation commands)
~/.rotz/bin/rotz install

# Install specific dotfile module
~/.rotz/bin/rotz install /tools/neovim

# Link dotfiles without running installation commands
~/.rotz/bin/rotz link

# Check status of dotfiles
~/.rotz/bin/rotz status
```

## Architecture

### Rotz Configuration System

Rotz uses `dot.yaml` files throughout the repository to define:

- **installs**: Commands to install packages/dependencies
- **links**: Symlink mappings from repo files to system locations
- **depends**: Dependency tree (modules that must be installed first)

Platform-specific configurations use conditional syntax:

- `linux[whoami.distro^="Arch"]` - Arch Linux
- `linux[whoami.distro^="Fedora"]` - Fedora Linux
- `windows` - Windows
- `linux|darwin` - Linux or macOS
- `global` - All platforms

### Directory Structure

- **`/tools`** - Application configurations (git, neovim, zsh, kitty, hyprland, etc.)
- **`/languages`** - Programming language toolchains (ruby, node, python, rust, go, dotnet, lua)
- **`/lib`** - System libraries and dependencies (pipewire, qt, avahi, uwsm, xdg)
- **`/arch`** - Arch Linux specific apps (keychron, emote, swappy, wlogout, wttrbar)
- **`/ai`** - AI tool configurations (claude, gemini, postgres-mcp, mcp-chrome)
- **`/packages`** - Package managers (scoop, homebrew, rancher)
- **`/modules`** - Shared PowerShell functions

## Configuration File Patterns

When adding new dotfile modules:

1. Create a directory under the appropriate category (`/tools`, `/languages`, etc.)
2. Add a `dot.yaml` with platform-specific configuration
3. Include any config files to be symlinked
4. Define dependencies in the `depends` section
5. Use templating for platform-specific paths: `{{ env.LOCALAPPDATA }}`

Example `dot.yaml` structure:

```yaml
linux[whoami.distro^="Arch"]:
  installs:
    cmd: yes | sudo pacman -S package-name
    depends:
      - /tools/dependency
  links:
    config.conf: ~/.config/app/config.conf
```
