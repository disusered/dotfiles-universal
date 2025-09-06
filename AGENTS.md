# AGENTS.md: Instructions for LLMs in Dotfiles Repo

This document guides LLMs (e.g., Gemini, Claude, OpenCode) when assisting with this universal dotfiles repository managed by Rotz. Base actions on repo structure, README.md, and tools. Repo automates dev environments across Linux/macOS/Windows/WSL using mise for versions, YAML configs, and cross-platform scripts (Zsh/PS). Focus on reproducibility for editors (Neovim/LazyVim), AI (Aider/CodeCompanion/Claude/Gemini), languages (.NET/Go/Python/Ruby/Rust/Zig/LaTeX/Lua/Node), tools (FZF/Starship/Zoxide/Bat/Delta/Ripgrep/Eza/Lazygit), packages (Scoop/Homebrew/Rancher), and integrations (WezTerm, WSL, Git, Docker).

## Repo Structure Overview
- **ai/**: AI tools (aider/, claude/, mcp-chrome/, opencode/) with YAML configs and settings (e.g., claude/settings.json for Claude Code).
- **editor/neovim/**: Lua-based Neovim setup (init.lua, plugins/ like codecompanion.lua, treesitter.lua, dadbod.lua for Rails/Docker). Uses LazyVim extras; supports vi-mode, LSP, DAP, GitSigns, Noice, WhichKey.
- **languages/**: Mise YAML for lang versions/tools (e.g., python/latest/, rust/rustup/, dotnet/csharpier/).
- **modules/**: PowerShell functions (functions.ps1).
- **packages/**: OS package managers (homebrew/, scoop/, rancher/).
- **tools/**: CLI utils with dot.yaml, scripts (e.g., bat/config with Catppuccin theme, starship.toml, zsh history.zsh).
- **Root**: config.yaml (mise global), setup.ps1, packages.psd1 (PS module), .gitignore, README.md (todo/install lists).

Key integrations: WSL shims (win32yank, wslview), Git (delta pager, allowed_signers), Starship (sudo status), WezTerm hyperlinks, Antidote (Zsh plugin mgr), CodeCompanion (Gemini MCP/CLI with keymaps).

## Basic Rotz Commands
Use these for setup/management. Assume Rotz is installed (via curl/irm scripts in README.md).

### rotz link
- Purpose: Symlinks dotfiles from repo to ~ (e.g., .zshrc, .config/nvim, .starship.toml).
- When to use: After `rotz clone <repo-url>`, to activate configs without copying.
- Example: `~/.rotz/bin/rotz link` (Linux/macOS) or via PS equivalent.
- LLM tip: Before editing, verify links with `ls -l ~` or read symlinked files via Read tool. Mimic existing styles (e.g., Lua for Neovim plugins).

### rotz install
- Purpose: Installs tools/languages/packages from YAML (via mise/Scoop/Homebrew). Handles deps like fonts (FiraCode), apps (Neovim, Git, Node), langs (Python/Ruby/Rust), utils (FZF/Ripgrep/Zoxide).
- When to use: After linking, for full reproducible setup. Includes WSL/Docker/Rancher integrations.
- Example: `~/.rotz/bin/rotz install` (runs mise install, scoop install, etc.; see README.md todos for specifics like 7zip, Chrome, 1Password).
- LLM tip: Post-install, run `mise doctor` or `scoop status` to verify. For changes, update dot.yaml files and re-run install. Avoid manual installs; use mise for versions.

## Guidelines for LLMs
- **Proactivity**: Use search tools (glob/grep) to explore (e.g., find Neovim plugins: `glob "editor/neovim/lua/plugins/*.lua"`). Batch reads (Read multiple files concurrently).
- **Editing**: Read files first (e.g., Read init.lua before Edit). Preserve conventions (Lua tables for Neovim, YAML for mise). No comments unless requested. Follow security (no secrets in git).
- **Verification**: After changes, suggest Bash runs like `nvim --headless -c 'checkhealth' -c 'q'` or `mise ls`. For commits/PRs, analyze with git status/diff/log per guidelines.
- **Platform Awareness**: Handle Windows (%LOCALAPPDATA%), WSL (shims), cross-shell (Zsh/PS). Check README.md todos for pending features (e.g., SSH agents, Navi).
- **AI-Specific**: For CodeCompanion/Claude/Gemini, reference plugins/ configs; enable MCP/CLI only if deps met (see todos).
- **Refusals**: Block malicious code; if unsure, ask user.
- **Todos from README.md**: Track [ ] items (e.g., WinUtil, Zed, SSH configs) for enhancements. Use todowrite for multi-step tasks.

When assisting, reference file:line (e.g., editor/neovim/init.lua:5). Prioritize conciseness; batch tools for efficiency.