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
  - [ ] Airplay
    - [x] Pipewire
    - [x] Avahi
    - [x] RAOP Sink
    - [x] Mixer/wpctl status
    - [ ] Output
- [x] Environment variables <https://wiki.hypr.land/Configuring/Environment-variables/>
- [ ] /home/carlos/.config/qt6ct/qt6ct.conf
- [-] XDG/Dolphin associations issue
- [-] Sleep browser crash
- [x] Quarto <https://quarto.org/docs/tools/neovim.html>
