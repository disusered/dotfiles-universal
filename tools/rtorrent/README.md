# rTorrent

The active instance stores its payloads and session on the data volume:

- Payloads: `/data/archive/rtorrent/download`
- Session: `/data/archive/rtorrent/.session`
- Watch: `/data/archive/rtorrent/watch`
- Legacy path: `~/Downloads/rtorrent` (symlink to the data-volume root)

## Add a torrent

In the rTorrent interface, press `Backspace`, paste the magnet link, and press
`Enter`. rTorrent resolves the metadata and starts the transfer. Press `Ctrl+S`
on the selected torrent if it remains stopped.

If the header says `View: main (filtered)`, press `Shift+F` and then `Enter` with
an empty filter to show the full torrent list.

Completed payloads stay untouched in the download directory so rTorrent keeps
seeding. The finished-download hook publishes them into the service libraries:

| Content | Destination |
| --- | --- |
| Movies | `/data/media/Movies` |
| TV (`S01E02` or `Season 1` naming) | `/data/media/TV` |
| Music | `/data/media/Music` |
| ROMs | `/data/media/ROMs/<platform>` |

The archive and media paths are separate Btrfs subvolumes, so the helper uses
copy-on-write reflinks between them. Within a filesystem it uses hardlinks.
Neither method moves the seeding source or makes a second physical copy at
import time.

The hook runs immediately on completion. A five-minute reconciliation over
rTorrent's `complete` view also catches completed items loaded from an old
session, so a missed event does not require manual intervention.

## Manual routing and backfill

Ambiguous containers such as `.iso` and `.zip` are left for explicit routing:

```sh
rtorrent-media-link --label movies "/data/archive/rtorrent/download/Movie.iso"
rtorrent-media-link --label roms:switch "/data/archive/rtorrent/download/Game.zip"
```

Import all existing completed payloads:

```sh
rtorrent-media-link --all
```

Preview without creating links:

```sh
rtorrent-media-link --all --dry-run
```

Unexpected conflicts are logged and left untouched. Import activity is appended
to `~/.local/state/rtorrent-media-link.log`.
