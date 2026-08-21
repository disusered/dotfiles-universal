# Betterbird

Rotz installs the production Betterbird package and starts it with the Hyprland
session. Account credentials and mailbox data remain in Betterbird's local
profile and are not managed by dotfiles.

After adding mail accounts, configure each account under **Synchronization &
Storage** to keep messages on this computer and include messages from
2025-01-01 onward. Do not enable either server-side age deletion option.

For the background workflow, set these preferences in Betterbird:

- `mail.biff.show_tray_icon = true`
- `mail.biff.show_tray_icon_always = true`
- `mail.minimizeToTray = true`
- `mail.startupMinimized = true`

Use Unified Folders, hide the Spaces toolbar, and leave Chat unconfigured for a
mail-only interface. Betterbird 140 supports minimize-to-tray on Hyprland when
using Betterbird's own window controls; closing the window still exits the
application.
