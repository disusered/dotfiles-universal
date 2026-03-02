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

<!-- BEGIN BEADS INTEGRATION -->
## Issue Tracking with bd (beads)

**IMPORTANT**: This project uses **bd (beads)** for ALL issue tracking. Do NOT use markdown TODOs, task lists, or other tracking methods.

### Why bd?

- Dependency-aware: Track blockers and relationships between issues
- Git-friendly: Dolt-powered version control with native sync
- Agent-optimized: JSON output, ready work detection, discovered-from links
- Prevents duplicate tracking systems and confusion

### Quick Start

**Check for ready work:**

```bash
bd ready --json
```

**Create new issues:**

```bash
bd create "Issue title" --description="Detailed context" -t bug|feature|task -p 0-4 --json
bd create "Issue title" --description="What this issue is about" -p 1 --deps discovered-from:bd-123 --json
```

**Claim and update:**

```bash
bd update <id> --claim --json
bd update bd-42 --priority 1 --json
```

**Complete work:**

```bash
bd close bd-42 --reason "Completed" --json
```

### Issue Types

- `bug` - Something broken
- `feature` - New functionality
- `task` - Work item (tests, docs, refactoring)
- `epic` - Large feature with subtasks
- `chore` - Maintenance (dependencies, tooling)

### Priorities

- `0` - Critical (security, data loss, broken builds)
- `1` - High (major features, important bugs)
- `2` - Medium (default, nice-to-have)
- `3` - Low (polish, optimization)
- `4` - Backlog (future ideas)

### Workflow for AI Agents

1. **Check ready work**: `bd ready` shows unblocked issues
2. **Claim your task atomically**: `bd update <id> --claim`
3. **Work on it**: Implement, test, document
4. **Discover new work?** Create linked issue:
   - `bd create "Found bug" --description="Details about what was found" -p 1 --deps discovered-from:<parent-id>`
5. **Complete**: `bd close <id> --reason "Done"`

### Auto-Sync

bd automatically syncs via Dolt:

- Each write auto-commits to Dolt history
- Use `bd dolt push`/`bd dolt pull` for remote sync
- No manual export/import needed!

### Important Rules

- ✅ Use bd for ALL task tracking
- ✅ Always use `--json` flag for programmatic use
- ✅ Link discovered work with `discovered-from` dependencies
- ✅ Check `bd ready` before asking "what should I work on?"
- ❌ Do NOT create markdown TODO lists
- ❌ Do NOT use external issue trackers
- ❌ Do NOT duplicate tracking systems

For more details, see README.md and docs/QUICKSTART.md.

<!-- END BEADS INTEGRATION -->
