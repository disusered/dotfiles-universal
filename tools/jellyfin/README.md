# Jellyfin

Native Arch Jellyfin server managed by Rotz. Media lives on the `/data` partition.
The package supplies the service, application settings, database, and cache.

## Install

```sh
~/.rotz/bin/rotz install /tools/jellyfin
~/.rotz/bin/rotz install /tools/caddy
```

The installer requires `/data` to be mounted, installs the server, web client,
and Jellyfin FFmpeg, creates library directories, and enables `jellyfin.service`.
The service also waits for the media filesystem at boot. Reinstalling preserves
application settings, accounts, and media.

## First-time setup

Open `http://localhost:8096` on this machine and complete the setup wizard:

1. Create the administrator account.
2. Apply `libraries.json` with the command below, or add these libraries in the wizard:

   | Library | Content type | Folder |
   | ------- | ------------ | ------ |
   | Movies | Movies | `/data/media/Movies` |
   | TV | Shows | `/data/media/TV` |
   | Music | Music | `/data/media/Music` |

3. Allow remote connections for access through Tailscale.
4. In Dashboard → Networking, add `127.0.0.1` to Known Proxies for Caddy,
   leave Base URL empty, and restart Jellyfin after saving network settings.

The owner can add media to these directories. Jellyfin's group can read and
traverse them; the service cannot write media into the initial directories.
Setgid directories make newly created files inherit the `jellyfin` group. When
moving existing files, ensure they also have that group and group read permission;
directories need group traverse permission. Jellyfin stores downloaded metadata
in its application data by default.

## Declarative libraries

`libraries.json` declares the library names, content types, folders, and defaults
for new libraries. The `jellyfin-libraries` command applies it through the local
Jellyfin API. It adds missing libraries and folders, preserves existing settings,
and reports conflicts instead of duplicating libraries with another name or type.
Removing an entry from the file does not delete a library or media.

```sh
# Preview changes.
jellyfin-libraries
# Apply during the initial setup wizard.
jellyfin-libraries --apply
# After setup, authenticate using the administrator login saved in 1Password.
jellyfin-libraries --apply --op-item '<login item name or ID>' --op-vault Personal
```

Jellyfin's initial-setup API is available until the wizard is completed. After
that, the command requires an administrator login. Credentials and session tokens
stay in memory, and the temporary session is logged out after use.

New libraries use the server's default metadata providers, monitor their folders
for new media, and keep downloaded metadata, subtitles, lyrics, and trickplay
outside the read-only media folders. A library scan is queued after changes.

## Access

- This machine: `http://localhost:8096`
- Home network: `http://<this-machine-LAN-IP>:8096`
- Tailscale HTTPS: `https://jellyfin.disusered.com`

Caddy binds the HTTPS route to the existing Tailscale address and uses the
existing wildcard certificate. Its DNS record is managed by Cat Infra
(`disusered/tailscale-infra`) and applied through CI.

## Operations

```sh
systemctl status jellyfin.service
journalctl -u jellyfin.service -n 50 --no-pager
sudo systemctl restart jellyfin.service
curl --fail http://localhost:8096/health
```

To update, use normal Arch package maintenance. Running the Rotz module again
installs any newer versions already available in the local package database.
Restart Jellyfin after a package update if the package hook has not done so.
