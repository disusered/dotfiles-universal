# Universal Dotfiles

## Linux/Mac

```sh
# Install dependencies for Rotz
sudo dnf update -y && sudo dnf install -y git

# Install Rotz
curl -fsSL volllly.github.io/rotz/install.sh | sh

# Clone the dotfiles repository
~/.rotz/bin/rotz clone https://github.com/disusered/dotfiles-universal.git

# Install dotfiles
~/.rotz/bin/rotz install
```

## Windows

```powershell
irm volllly.github.io/rotz/install.ps1 | iex
```

## Rotz

Source: <https://github.com/pho3nixf1re/dotfiles/tree/main>

### Install

- [ ] Replace installation script with `rotz install`
  - [ ] Install
    - [ ] 7zip.7zip
    - [ ] Docker.DockerDesktop
    - [ ] SourceFoundry.HackFonts
    - [ ] Zoom.Zoom
    - [ ] Logitech.GHub
    - [ ] Google.Chrome
    - [ ] Google.GoogleDrive
    - [ ] RevoUninstaller.RevoUninstaller
    - [ ] wez.wezterm
    - [ ] AgileBits.1Password
    - [ ] AgileBits.1Password.CLI
    - [ ] Microsoft.Teams
    - [ ] Meld.Meld
  - Scoop
    - [x] Fonts
      - [x] FiraCode
      - [x] CascadiaCode-NF-Mono
      - [x] Hasklig
      - [x] hack-font
    - [x] Apps
      - [x] dotnet
      - [x] fd.exe
      - [x] git.exe
      - [x] neovim.exe
      - [x] nuget.exe
      - [x] starship
      - [x] mise
      - [x] nodejs
      - [x] eza
      - [x] rg
      - [x] fzf
      - [x] lazygit
      - [x] curl
      - [x] zig (required for compiling TS on Windows)
      - [x] zoxide
      - [x] bat
      - [x] rust
      - [x] ruby
      - [x] python
      - [x] golang
      - [x] node
      - [x] win32yank.exe
- [ ] WinUtil <https://github.com/ChrisTitusTech/winutil>

## Etc

- [x] Launch PowerShell 7 in Wezterm in new tab
- [x] Zoxide <https://github.com/ajeetdsouza/zoxide>
- [x] %LOCALAPPDATA% for windows links
- [x] Neotest in Windows
- [x] Param completion
- [x] Git log interactive
- [x] Git allowed signers file for Windows
- [x] Delta for git pager
- [x] Bat theme for Git
- [x] Wezterm hyperlinks <https://wezterm.org/recipes/hyperlinks.html#requirements>
  - [x] xdgopen -> wslview or wsl-open <https://github.com/4U6U57/wsl-open>
  - [x] Eza
  - [x] Delta
  - [x] Ripgrep
  - [x] Explorer
  - [x] Neovim
- [x] Starship show sudo status
- [ ] Neovim wrap sidebar icon like screenshot
- [ ] Neovim show selection stats (lines, words, characters) in statusline for Markdown
- [x] WSL config <https://learn.microsoft.com/en-us/windows/wsl/wsl-config>
- [x] Claude
  - [x] Claude Code
  - [x] Claude MCP <https://www.reddit.com/r/ClaudeAI/comments/1jf4hnt/setting_up_mcp_servers_in_claude_code_a_tech/>
  - [x] Claude Neovim
- [x] Kulala
  - [x] Plugin
  - [x] LSP
  - [x] Formatter
  - [x] Dependencies <https://neovim.getkulala.net/docs/getting-started/requirements>
- [x] Rancher Desktop WSL integration <https://docs.rancherdesktop.io/getting-started/wsl-integration/>
- [x] SSH (eval agent in wsl, 1Password agent in Windows)
  - [x] WSL config with ssh agent
  - [x] Windows config with IdentityAgent and 1Password

## WSL

- [x] Docker
- [x] Languages
  - [x] Ruby
  - [x] Node
  - [x] Csharp
    - [x] nuget
    - [x] csharpier
  - [x] Rust
  - [x] Latex
    - [x] tectonic
    - [x] latexmk
  - [x] Mermaid
    - [x] mmdc
- [x] Neovim
  - [x] Install
  - [x] Lazyvim dependencies
- [x] ZSH
  - [x] .zshenv
  - [x] Zinit replacement (Antidote)
  - [x] Wezterm escape sequences
  - [x] Clipcopy
  - [x] Vi-mode
    - [x] Plugin
    - [x] Keybindings
      - [x] History substring search
      - [x] Paste with p
  - [x] Completions
  - [x] Starship
  - [x] History options
  - [x] WSL
    - [x] win32yank (pbcopy/pbpaste)
    - [x] xdgopen -> wslview shim
  - [x] Custom aliases
    - [x] Eza
  - [x] Httpie
    - [x] Install
  - [x] Ripgrep
    - [x] Install
    - [x] ZSH functions
    - [x] Default options
  - [x] Fzf
    - [x] Install
    - [x] Default options
    - [x] Shell intergration
  - [x] Bat
    - [x] Install
    - [x] ZSH alias
    - [x] Catpuccin
  - [x] Git
    - [x] Git config
    - [x] Git ignore
    - [x] Git allowed signers
    - [x] Git Delta
    - [x] Git alias
    - [x] Git completion
    - [x] Git functions
    - [x] Default options
  - [x] Lazygit
    - [x] Install
    - [x] Config
  - [x] Delta
    - [x] Install
    - [x] Git
    - [x] Bat
  - [x] Zoxide
    - [x] Install
    - [x] Init
    - [x] Alias

## Arch

- [x] Terminal
  - [x] Kitty
    - [x] Pane management
    - [x] Theme
- [ ] Hyprland
  - [ ] Login manager (SDDM)
  - [ ] Must-have <https://wiki.hypr.land/Useful-Utilities/Must-have/>
    - [ ] Notification daemon (mako)
    - [ ] OSD (swayosd)
    - [ ] Pipewire
    - [ ] XDG Desktop Portal
    - [x] Authentication Agent (hyprpolkitagent, 1Password compatible)
    - [ ] Qt Wayland Support
    - [x] Fonts
  - [ ] Utilities
    - [ ] Clipboard manager (cliphist)
    - [ ] File manager (dolphin)
    - [ ] Audio widget (investigate next iteration or if swayosd is enough)
      - [x] Install
      - [ ] Theme
    - [ ] Network (iwd + nm-applet for WiFi)
  - [ ] Monitor management
    - [ ] Profile: Single monitor (current)
    - [ ] Profile: Dual monitor (other location)
  - [ ] Future: Evaluate walker (app launcher) + elephant + uwsm
- [ ] Firefox
  - [ ] Default browser
- [ ] Chrome (not Chromium)
- [ ] Wezterm Replacement
  - [ ] Lazygit Neovim integration
