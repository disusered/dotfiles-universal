# Betterbird

Rotz installs Betterbird and the English (US) and Spanish (Mexico) spelling
dictionaries. It also installs a system-wide Betterbird policy and starts the
client in the Hyprland background graphical slice.

The user invocation installs the package and links the Hyprland configuration.
Run Rotz as root against this repository to link the system policy:

```bash
sudo ~/.rotz/bin/rotz --dotfiles ~/.dotfiles link /arch/betterbird -f
```

The policy keeps Betterbird available in the system tray, starts it minimized,
and uses Betterbird 153's native close-to-tray behavior. It also keeps a rolling
365 days of every IMAP account available offline. These are editable defaults:
local UI choices can override them.

The policy manages these preferences:

- `mail.biff.show_tray_icon_always = true`
- `mail.closeToTray = true`
- `mail.minimizeToTray = true`
- `mail.minimizeToTray.supportedDesktops` includes `hyprland`
- `mail.startupMinimized = true`
- `mail.server.default.autosync_max_age_days = 365`
- `mail.server.default.autosync_offline_stores = true`
- `mail.server.default.offline_download = true`
- `spellchecker.dictionary = en-US,es-MX`

Betterbird 153 provides close-to-tray directly, so the full-access **Minimize on
Close** add-on is intentionally not installed. Account credentials, OAuth
state, calendars, address books, mailbox data, and generated profile files stay
in Betterbird's local profile and are not managed by dotfiles.
