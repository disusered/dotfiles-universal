# Dotfiles for Windows

```powershell
# Run installation script for all dependencies
.\setup.ps1
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
      - [ ] win32yank.exe
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
- [ ] WinUtil <https://github.com/ChrisTitusTech/winutil>

## TODO

- [x] Launch PowerShell 7 in Wezterm in new tab
- [x] Zoxide <https://github.com/ajeetdsouza/zoxide>
- [ ] Unix shell completion in PS <https://github.com/PowerShell/Modules/tree/master/Modules/Microsoft.PowerShell.UnixCompleters>
- [ ] LazyVim with PowerShell
  - [x] OmniSharp
  - [ ] Neotest
  - [ ] DAP
- [ ] Dev drive <https://learn.microsoft.com/en-us/windows/dev-drive/>
- [ ] SSH (eval agent in wsl, 1Password agent in Windows)
  - [x] WSL config with IdentityFile
  - [ ] Windows config with IdentityAgent and 1Password
- [ ] Neotest in Windows
- [x] Param completion
- [x] Git log interactive
- [x] Git allowed signers file for Windows
- [x] Delta for git pager
- [x] Bat theme for Git
