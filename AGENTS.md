# Agent Instructions

## Infrastructure boundary

Do not run Terraform or OpenTofu locally, including wrappers that invoke them.
The cat-infra repository is at
`~/Development/ME/herding-cats/utilities/cat-infra` and uses its own
`.github/workflows/tofu.yml` for PR plans and applies after merges to main.
This does not authorize a commit, push, merge, or deployment as routine cleanup.
Other infrastructure repositories need their own verified authorized execution path.

## Git Remote Operations

Do not run `git pull`, `git pull --rebase`, or `git push` as a session-completion routine. Only run remote git operations when the user explicitly asks.

## Git Commit Signing

- **NEVER create unsigned commits.** Use the repository's configured signing backend.
- Use `git commit -S ...` for every commit. Do not rely only on ambient git config.
- **NEVER use `--no-gpg-sign`, `commit.gpgsign=false`, or any other signing bypass.**
- If the sandbox blocks the configured signer, retry the same authorized operation through
  supported escalation. Preserve the backend and identity; never request or export private
  keys or disable signing. Stop the affected operation on denial or persistent failure and
  report the exact error.
- After every agent-created commit, run `git verify-commit HEAD`. Treat verification failure as a failed commit task until the commit is replaced with a signed, verifiable commit.

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

## Agent setup and skill discovery

Shared behavior is maintained in `ai/agent-instructions/AGENTS.md`; Claude Code
and Codex read that same source through their global symlinks. Keep project
details here and model-specific tuning in the harness configuration.

Use the active harness's installed skill catalog and supported loading mechanism.
Read a skill when its workflow applies; do not load every skill or install a
missing package just to discover instructions. Canonical custom skills live in
`ai/agent-skills`; preserve installer-owned and vendored copies.

For instruction and configuration changes, validate syntax, imports, links, and
the affected packaging behavior. Application suites are needed only when their
behavior changes. Preserve existing worktree changes and permission settings.
