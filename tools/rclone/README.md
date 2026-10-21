# rclone

This module installs rclone and manages the user-scoped iCloud Drive mount.

Credentials, OAuth sessions, and Apple's iCloud trust token stay in
`~/.config/rclone/rclone.conf`. They are not part of this repository.

Create or reconnect the `iCloud` remote interactively before enabling the
service:

```sh
rclone config
systemctl --user enable --now rclone-icloud.service
```

`rclone-icloud.service` mounts iCloud read/write at `~/iCloud Drive` and
restarts it after a failure. The `iclouddrive` backend is experimental, so an
expired Apple session may require `rclone config reconnect iCloud:`.
