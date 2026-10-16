# restic

Daily incremental backup of `$HOME` and the stateful parts of `/data` into a
restic repository at `/data/backups/restic-home`. The repository is on the same
NVMe disk as `/home`, so it protects against mistakes and bad upgrades, not
against the disk failing.

## /data layout

`/data` is the former Windows partition (`nvme0n1p3`, label `Data`), formatted
as btrfs and mounted with `compress=zstd:1,user_subvol_rm_allowed` (the backup script deletes its own snapshots). These entries live in `/etc/fstab`
(not tracked here):

| Subvolume | Mounted at | Backed up |
|---|---|---|
| top level (`subvolid=5`) | `/data` | — |
| `@steam` | `~/.local/share/Steam` | no, re-downloadable |
| `@containers` (`chattr +C`) | `~/.local/share/containers` | `storage/volumes` only |
| `@karakeep` | `~/.local/share/karakeep` | `data` only |
| `archive` | symlinked from `Documents/CBZ Downloads`, `Documents/CRI/backups`, `Downloads/rtorrent` | no |
| `backups` | — | holds the repository |

Every subvolume mount uses `nofail`. The empty mount-point directories on
`/home` are `chattr +i`, so if `/data` fails to mount, writes into those paths
fail instead of quietly filling `/home` with a fresh empty Podman store or
Karakeep library. To change one, unmount it first, then run `chattr -i`.

## What runs

`restic-home.timer` runs `scripts/backup` daily at 03:30. The script:

1. Takes btrfs snapshots of `@containers` and `@karakeep` under
   `/data/backups/.snap`. Databases are captured crash-consistently while
   their services keep running.
2. Runs `restic backup` inside `podman unshare`, so files owned by container
   sub-UIDs are readable. `--one-file-system` keeps the `/data` mounts out of
   the `$HOME` walk, and `excludes` drops regenerable caches.
3. Applies retention: 7 daily, 4 weekly, 6 monthly.

The password is in `~/.config/restic/home.password` (0600) and in 1Password as
"restic home backup (/data/backups/restic-home)".

## Restore

```bash
export RESTIC_REPOSITORY=/data/backups/restic-home
export RESTIC_PASSWORD_FILE=~/.config/restic/home.password
podman unshare restic snapshots
podman unshare restic restore latest --target /tmp/restore --include /home/carlos/Documents/some-file
```

Restore container volumes inside `podman unshare` so their sub-UID ownership
comes back intact.
