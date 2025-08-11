# Dotfiles for Windows

```powershell
# Run installation script for all dependencies
.\setup.ps1
```

## Rotz

Source: <https://github.com/pho3nixf1re/dotfiles/tree/main>

FIX PYTHON IN VIM: <https://github.com/mason-org/mason.nvim/issues/1753>

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
      - [x] fd.exe
      - [x] git.exe
      - [x] neovim.exe
      - [ ] nuget.exe
      - [ ] win32yank.exe
      - [x] starship
      - [x] volta
      - [x] nodejs
      - [x] eza
      - [x] rg
      - [x] fzf
      - [x] lazygit
      - [x] curl
      - [x] zig (required for compiling TS on Windows)
      - [x] zoxide
- [ ] WinUtil <https://github.com/ChrisTitusTech/winutil>

### Link

- [x] Starship <https://github.com/starship/starship>
- [x] Catpuccin <https://github.com/catppuccin/powershell>
- [ ] Neovim with LazyVim <https://www.lazyvim.org/installation>
  - [ ] Windows-specific configuration
    - [x] Required dependencies
    - [ ] LazyHealth issues
    - [ ] Clipboard support
- [x] Git
- [x] LazyGit

## TODO

- [x] Launch PowerShell 7 in Wezterm in new tab
- [x] Zoxide <https://github.com/ajeetdsouza/zoxide>
- [ ] Unix shell completion in PS <https://github.com/PowerShell/Modules/tree/master/Modules/Microsoft.PowerShell.UnixCompleters>
- [ ] LazyVim with PowerShell
  - [ ] OmniSharp
  - [ ] Neotest
  - [ ] DAP
- [ ] Dev drive <https://learn.microsoft.com/en-us/windows/dev-drive/>
- [ ] SSH (eval agent in wsl, 1Password agent in Windows)
  - [ ] WSL config with IdentityFile
  - [ ] Windows config with IdentityAgent and 1Password
- [ ] Neotest in Windows
- [x] Param completion
- [x] Git log interactive
- [x] Delta for git pager
- [ ] Bat theme for Git
