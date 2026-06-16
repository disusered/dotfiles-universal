# RomM

Rotz-managed local RomM stack.

## Shape

- App: `romm.service`, container `romm`, image `docker.io/rommapp/romm:latest`
- Database: `romm-db.service`, container `romm-db`, image `docker.io/library/mariadb:latest`
- Local URL: `http://127.0.0.1:47224`
- Tailnet URL: `http://romm.disusered.com`
- 1Password item: `op://Personal/RomM Local`

The app is exposed only on localhost. Caddy publishes the tailnet route.

## Storage

RomM library storage lives under `~/Games/romm`:

- `~/Games/romm/library/roms`
- `~/Games/romm/library/bios`
- `~/Games/romm/assets`
- `~/Games/romm/config`

The library directory follows RomM's recommended top-level `roms/` and `bios/`
layout.

MariaDB data, RomM resources, and RomM cache data are stored in Podman named
volumes: `romm-mysql-data`, `romm-resources`, and `romm-redis-data`.

## Secrets

Run `romm-init` to converge the `Personal / RomM Local` 1Password item and
render `~/.config/romm/romm.env` from `~/.config/romm/env.tpl`.

Required fields are generated if missing:

- `db_root_password`
- `db_password`
- `auth_secret_key`

Metadata provider credentials are referenced from their own 1Password items:

- `op://Personal/Twitch/IGDB App/Client ID`
- `op://Personal/Twitch/IGDB App/Client Secret`
- `op://Personal/RetroAchievements/add more/API Key`

Provider toggles that do not require private credentials are enabled in
`env.tpl`: Hasheous, PlayMatch, LaunchBox, Flashpoint, and HowLongToBeat.
PlayMatch can submit match suggestion data when manually matching ROMs.

Do not commit `~/.config/romm/romm.env` or any generated secrets.

## Install

```bash
~/.rotz/bin/rotz install /games/romm
```

Then check:

```bash
romm-smoke
```

On first boot, open `http://romm.disusered.com` and complete RomM's setup
wizard. The first user becomes the admin user.
