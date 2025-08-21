# Universal Dotfiles

**Linux/Mac**

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

**Windows**

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
    - [ ] Apps
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
      - [ ] win32yank.exe
- [ ] WinUtil <https://github.com/ChrisTitusTech/winutil>

## Windows

- [x] Launch PowerShell 7 in Wezterm in new tab
- [x] Zoxide <https://github.com/ajeetdsouza/zoxide>
- [ ] Unix shell completion in PS <https://github.com/PowerShell/Modules/tree/master/Modules/Microsoft.PowerShell.UnixCompleters>
- [ ] Dev drive <https://learn.microsoft.com/en-us/windows/dev-drive/>
- [ ] SSH (eval agent in wsl, 1Password agent in Windows)
  - [ ] WSL config with ssh agent
  - [ ] Windows config with IdentityAgent and 1Password
- [x] Neotest in Windows
- [x] Param completion
- [x] Git log interactive
- [x] Git allowed signers file for Windows
- [x] Delta for git pager
- [x] Bat theme for Git

## Port

- [ ] Starship indicate inside container
- [ ] Starship give Docker context
- [ ] Starship show sudo status
- [ ] Wezterm hyperlinks <https://wezterm.org/recipes/hyperlinks.html#requirements>
  - [ ] xdgopen -> wslview or wsl-open <https://github.com/4U6U57/wsl-open>
  - [ ] Eza
  - [ ] Delta
  - [ ] Yazi/Ranger
- [ ] Neovim wrap sidebar icon like screenshot
- [ ] Neovim show selection stats (lines, words, characters) in statusline
- [ ] WSL config <https://learn.microsoft.com/en-us/windows/wsl/wsl-config>
- [ ] Linux variant
- [ ] Languages
  - [ ] Mise
  - [ ] Ruby
  - [ ] Deno
  - [ ] Node
  - [ ] Csharp
  - [ ] Rust
  - [ ] Dotnet
    - [ ] Csharpier
    - [ ] Nuget
    - [ ] Zsh completions
- [ ] ZSH
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
  - [ ] Custom aliases
    - [x] Eza
    - [ ] WSL
  - [ ] Yazi
    - [ ] Install
    - [ ] Config
    - [ ] Catppuccin theme
    - [ ] ZSH alias
  - [ ] Httpie
    - [ ] Install
    - [ ] ZSH alias
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
  - [ ] New
    - [ ] Zfunc <https://github.com/mattmc3/zfunctions/tree/main>
    - [ ] ZSH Utils (belak/zsh-utils)
