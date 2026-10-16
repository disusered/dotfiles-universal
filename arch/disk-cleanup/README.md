# Disk retention and package cache placement

The module keeps two installed package versions, removes uninstalled package
caches, and limits journal retention. Package archives live on the separate
`/home` filesystem at `/home/system-cache/pacman/pkg`, owned by root.

Run the bounded migration directly with:

```sh
sudo python3 ~/.dotfiles/arch/disk-cleanup/scripts/migrate-pacman-cache
```

It excludes package transactions with Pacman's database lock, pauses the cache
timer, copies and checksum-verifies archives, checks download-user access, then
updates Pacman. The cleanup service sees only the cache through its otherwise
hidden home filesystem. Dry runs test retention and sandbox access before the
verified original files are removed. An interrupted migration retains the copied
archives; rerun after resolving the reported failure. Never delete an existing
Pacman lock without checking its owner first.

The original Pacman configuration is saved as
`/etc/pacman.conf.before-cache-relocation`. To roll back, first ensure root has
enough room and no package or cleanup operation is active. Pause `paccache.timer`,
copy and checksum-verify archives back to `/var/cache/pacman/pkg`, then restore
only the original CacheDir setting (preserving any subsequent Pacman edits).
Remove `/etc/systemd/system/paccache.service.d/20-cache-location.conf`, reload
systemd, validate `pacman-conf CacheDir` and `paccache -dk2`, and restart the
timer. Remove the relocated copy only after verification.

## User file age limits

`tmpfiles/user-disk-cleanup.conf` is linked into `~/.config/user-tmpfiles.d/`
and applied daily by the user `systemd-tmpfiles-clean.timer`. Each rule deletes
files older than its age; the `m:` prefix ages by modification time, so reading
a file does not keep it.

| Path | Age |
|---|---|
| `~/.config/gcloud/logs` | 3 days |
| `~/.local/share/xbol-observability/log-spool/cloudlogging` | 14 days |
| `~/.codex/sessions` | 90 days |
| `~/.local/share/karakeep/backups` | 14 days (restic also keeps Karakeep data) |
| `~/.local/share/herding-cats/brain-portal/backups` | 30 days |

Preview with `systemd-tmpfiles --user --clean --dry-run`.
