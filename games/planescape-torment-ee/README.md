# Planescape: Torment — Enhanced Edition

Rotz module that codifies a working PST:EE setup on Arch Linux with
Hyprland/Wayland and gamescope.

## What this module does

- Installs [`openssl-1.0`](../../lib/openssl-1.0) from AUR so the legacy
  `libssl.so.1.0.0` / `libcrypto.so.1.0.0` dependency baked into the Beamdog
  EE binaries resolves. Verify with:
  ```sh
  ldd "$HOME/.local/share/Steam/steamapps/common/Project P/Torment64" \
    | grep -E 'libssl|libcrypto'
  ```
- Patches Steam launch options for AppID `466300` to route the game through
  `~/.local/bin/pst-ee-launch`.
- Symlinks a gamescope wrapper that:
  - Forces the 64-bit native binary (`Torment64`) when Steam passes the
    32-bit default.
  - Exports `LD_LIBRARY_PATH` to cover the libssl shim.
  - Detects the focused monitor via `hyprctl` and runs gamescope with
    integer scaling from 1920×1080 internal to native output.
- Symlinks a Hyprland window rule (`planescape.conf`) that marks the
  gamescope surface fullscreen + immediate.
- Symlinks `baldur.lua` into
  `~/.local/share/Beamdog/Planescape Torment Enhanced Edition/` with:
  - 60 FPS cap
  - Instant tooltip delay
  - Intro movie (`OPENING`) marked as seen

## Install

```sh
~/.rotz/bin/rotz install /games/planescape-torment-ee
```

Close Steam first so the launch-options patch can edit `localconfig.vdf`.
Disabling Steam Overlay for this title is also recommended.

## Tuning

- **Scaling / internal resolution / FPS cap**: edit
  [`pst-ee-launch.sh`](./pst-ee-launch.sh). The `GAME_W`, `GAME_H`, `GAME_FPS`
  vars and the `-S integer` flag are the knobs.
- **Game settings**: prefer editing [`baldur.lua`](./baldur.lua) in the
  dotfiles. Changing settings in-game works too, but the game rewrites
  `baldur.lua` on clean shutdown — those changes will appear as diffs in
  this repo and need to be committed (or reverted) deliberately.
