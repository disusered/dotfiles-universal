# The Elder Scrolls V: Skyrim Special Edition

Rotz module for Skyrim SE (AppID `489830`) on Arch Linux with Hyprland/Wayland,
Proton and gamescope. **Vanilla — no mods.** See [Phase 2](#phase-2--mods) for the
mod path, which is documented but deliberately not installed.

## What this module does

- Forces **Proton Experimental** for AppID `489830`. Skyrim SE has no native Linux
  port, and an unset mapping means whatever Steam's global default happens to be.
- Sets Steam launch options to
  `scb -- ~/.local/bin/skyrim-skse-launch %command%`, wrapping the game in
  [ScopeBuddy](../../tools/scopebuddy)/gamescope and swapping the Bethesda
  launcher for SKSE.
- **Leaves the frame rate to SSE Display Tweaks.** Skyrim's Havok physics is
  stepped off the frame rate; above roughly 60 fps vanilla makes objects drift or
  launch themselves, carts and ladders break, and water flow at the wrong speed.
  Every monitor this repo serves runs faster than that, so phase 1 capped at 60
  twice over — `dxvk.maxFrameRate` and gamescope's `-r 60`. Display Tweaks
  decouples the physics step instead, which is the real fix, so both caps were
  removed once its log confirmed `[HAVOK] (DYNAMIC)`. Remove Display Tweaks and
  the caps have to go back.
- **Generates `Skyrim.ini` and `SkyrimPrefs.ini` on every launch**, sized for
  whichever monitor and GPU it finds — see below.
- Symlinks a Hyprland window rule (`skyrim.conf`) marking the gamescope surface
  fullscreen + immediate.
- Renames `Data/Video/BGS_Logo.bik` to `.bak` so the Bethesda logo does not play on
  every launch.

## Why the INIs are generated, not symlinked

Every other game module in this repo symlinks its config out of the dotfiles. That
does not work here, because this repo serves two machines that disagree:

| | Work | Home |
|---|---|---|
| GPU | Intel Iris Xe (integrated) | discrete |
| Display | 1920×1080 @ 75 Hz, dual | ultrawide @ 144 Hz |

A committed `SkyrimPrefs.ini` would be wrong on one of them by construction, and
every session on the other machine would show up as a diff that breaks the first.

So [`skyrim-configure-display.sh`](./skyrim-configure-display.sh) runs from
ScopeBuddy's `SCB_PRE_COMMAND` before each launch and renders both INIs into the
Proton prefix from the templates in this directory:

- **Resolution** comes from ScopeBuddy's `SCB_AUTO_RES`, which resolves the focused
  monitor.
- **Field of view** is derived from the aspect ratio — 80° at 16:9 (vanilla),
  widened Hor+ for anything wider so the extra width shows more world rather than a
  stretched one, clamped at 110°.
- **Quality tier** is chosen by scanning `lspci` for a discrete AMD or NVIDIA
  display controller: [`SkyrimPrefs.dgpu.ini`](./SkyrimPrefs.dgpu.ini) if found,
  otherwise [`SkyrimPrefs.igpu.ini`](./SkyrimPrefs.igpu.ini).

Two useful side effects: the Skyrim launcher's hardware detection can clobber the
files as much as it likes, and the Steam library holding the game is resolved at
runtime via [`steam-find-app-path.sh`](../lib/steam-find-app-path.sh), so the game
does not have to live on the same drive on both machines.

**Changing graphics settings in-game does nothing that survives.** They are
overwritten on the next launch. Change the templates in this directory instead.

### Why the generated INIs are read-only

Generating the files is not enough on its own. Two things overwrite them *after* the
pre-launch hook runs, and both were caught doing exactly that on the first real
launch:

1. **Steam's install script.** `installscript.vdf` carries a `Copy Folders` rule that
   copies `<gamedir>/Skyrim/SkyrimPrefs.ini` over the top of the My Games copy.
2. **`SkyrimSELauncher.exe`'s hardware detection.** Its "detecting video hardware"
   pass writes a quality preset — on the Intel machine it picked the full `Ultra.ini`
   preset, 4096 shadow maps and volumetric quality 2, which is an unplayable choice
   for an Iris Xe.

So the generator sets both files unwritable after writing them. Wine surfaces a
Unix-unwritable file as a read-only Windows file, both writes fail harmlessly, and
the settings chosen here are the ones the game actually loads. The generator clears
the bit again at the start of each run before rewriting.

A consequence worth knowing: the in-game settings menu and the launcher's Options
button will appear to work but cannot save anything. That is intended — the
templates in this directory are the only place settings live.

Steam Cloud is not involved. For this title it syncs only `Saves/*.ess`, so the INIs
are never uploaded, downloaded, or conflicted.

### The cost of the lock: SkyrimPrefs.ini is a replacement, not an overlay

Blocking rule 1 above has a consequence that cost the first evening of play
(2026-08-07). `<gamedir>/Skyrim/SkyrimPrefs.ini` is not junk — it is the **only**
file in the whole chain that carries `[Controls]` and `[Interface]`, including
`fMouseHeadingSensitivity` (camera look) and `fMouseCursorSpeed` (in-game menu
pointer). `Skyrim_Default.ini` has neither section, and there is no
`SkyrimPrefs_Default.ini` at all.

So locking the generated prefs does not merely pin the graphics settings — it
guarantees the generated file is the complete and final word. The first version of
these templates had no mouse section, and the result was a game with a dead mouse:
camera would not turn, in-game menus had no pointer, the keyboard worked fine, and
only the Bethesda launcher — which never reads these files — still had a cursor.
The obvious suspects (gamescope's `--force-grab-cursor`, the ultrawide, the
windowrules) were all innocent; Civilization VI shares every one of them and works.

**Rule for anyone editing these templates: a key that is not in
`SkyrimPrefs.*.ini` is not in the game.** When in doubt, diff against
`<gamedir>/Skyrim/SkyrimPrefs.ini` and check what you are dropping.

## The game version is pinned to 1.6.1170

**Do not let Steam update this game.** Every SKSE plugin is compiled against one
runtime, so a Bethesda patch silently disables the entire mod set. This is not
hypothetical — it happened on 2026-08-20 and cost an afternoon.

Properties → Updates → *Only update this game when I launch it* is necessary but
not sufficient: it defers the update to launch, it does not refuse it. Check for
a pending download before launching, and if one is queued, do not launch through
Steam.

### Recovering when it updates anyway

On 2026-08-20 a 2 GB patch moved the game to **1.7.99** (buildid 13189953 →
24604991) and deleted `skse64_2_2_6.dll` outright. Everything under `Data/`
survived; only the executable and the SKSE root files were affected.

Staying current was tried first and does not work. SKSE 2.3.0 loads against
1.7.99 and scans every plugin, but none initialise: they are built against a
CommonLibSSE-NG that parses Address Library **format 4**, and the v12 library
emits **format 5**. The failure is `REL/ID.h(166): Unsupported address library
format: 5`, and `skse64.log` stops at `preinit complete` with zero successful
loads. No combination works — v11 has no 1.7.99 database at all — so recovery
means going back, not forward.

Downgrade with the Steam client's own console. No third-party downgrade tool, no
credentials handed to anything, and the files come from Valve:

```sh
steam -console      # adds a Console tab to the client
```

```
download_depot 489830 489831 8442952117333549665
download_depot 489830 489832 8042843504692938467
download_depot 489830 489833 1914580699073641964
```

Those three manifest IDs are 1.6.1170. Depot 489833 is the 26 MB executable, the
only one that decides the version. Files land in
`~/.local/share/Steam/ubuntu12_32/steamapps/content/app_489830/` — note
`ubuntu12_32`, not the `steamapps/content` path you would guess. Nothing is
overwritten until you copy it yourself:

```sh
G="$(../lib/steam-find-app-path.sh 489830)/steamapps/common/Skyrim Special Edition"
C=~/.local/share/Steam/ubuntu12_32/steamapps/content/app_489830
for d in 489831 489832 489833; do cp -a "$C/depot_$d/." "$G/"; done
strings "$G/SkyrimSE.exe" | grep -m1 '^1\.6\.'      # expect 1.6.1170.0
```

`cp` does not delete, so no mod file is touched — verified by diffing the depot
file list against the per-archive lists in `~/.local/state/skyrim-mods/`. The
copy does restore `Data/Video/BGS_Logo.bik`, so re-disable the intro afterwards.

**Leave `appmanifest_489830.acf` alone.** It still reports buildid 24604991.
Steam decides whether to update by comparing that number, not by hashing files,
so a manifest claiming 1.7.99 over a 1.6.1170 install is what keeps Steam quiet.
Correcting it invites the update straight back.

Then restore SKSE 2.2.6. Silverlock has dropped it from the page — only the GOG
2.2.6 build for 1.6.1179 is linked now — but the file is still served:

```sh
curl -O https://skse.silverlock.org/beta/skse64_2_02_06.7z
```

Drop it in `~/Downloads/skyrim-mods/` and run `skyrim-install-mods`; the manifest
pins its hash, so a wrong or tampered file is refused. Address Library needs
nothing: v12 only *adds* `versionlib-1-7-99-0.bin`, and the 1.6.1170 databases
are still format 2. Delete that one file and `skse64_1_7_99.dll` if a v12 install
left them behind.

Moving to 1.7.99 becomes possible once every mod above ships a DLL rebuilt
against a CommonLib that reads format 5. That is a wait on other authors, not on
anything in this repo.

## Install

Skyrim SE must already be installed from Steam on this machine.

```sh
~/.rotz/bin/rotz install /games/skyrim-special-edition
~/.rotz/bin/rotz link    /games/skyrim-special-edition
```

Both are needed: `rotz install` (1.2.1) only runs the install commands, it does not
create the symlinks.

Close Steam first — it rewrites `config.vdf` and `localconfig.vdf` on shutdown, so
both VDF patchers refuse to run while it is up and only print what they would have
set.

## Tuning

### Mouse

`[Controls]` / `[Interface]` in both `SkyrimPrefs.*.ini` templates. Because the
INIs are locked, the in-game Settings slider cannot save anything — sensitivity
has to be changed here and the game relaunched.

- `fMouseHeadingSensitivity` — camera look speed. Stock `0.0125`.
- `fMouseCursorSpeed` — in-game menu pointer speed. Stock `1.0000`.
- `bInvertYValues` — `1` to invert vertical look.

Both templates currently hold stock values, so the feel is vanilla.

### Quality

Edit [`SkyrimPrefs.igpu.ini`](./SkyrimPrefs.igpu.ini) or
[`SkyrimPrefs.dgpu.ini`](./SkyrimPrefs.dgpu.ini). The game ships its own
`Low.ini` / `Medium.ini` / `High.ini` / `Ultra.ini` presets in its install
directory — those are the authoritative reference for what each preset changes.

- The **igpu** template is Medium with the two things an Iris Xe cannot afford cut:
  volumetric lighting (god rays) and screen space reflections. Shadow map resolution
  is Low's 1024. If it still cannot hold 60 outdoors, reach for FSR (below) before
  cutting more — dropping the internal resolution buys back more than shaving
  another effect will.
- The **dgpu** template is High, unmodified apart from the window keys. **It has
  never been run** — it was written on the Intel machine. Verify it at home; `Ultra.ini`
  is the next step up if there is headroom.

### FSR upscaling

The big lever on the integrated GPU. Uncomment **both** lines in
[`scopebuddy.conf`](./scopebuddy.conf):

```sh
SCB_GAMESCOPE_ARGS="$SCB_GAMESCOPE_ARGS -w 1600 -h 900 -F fsr"
SCB_PRE_COMMAND='"$HOME/.local/bin/skyrim-configure-display" 1600 900'
```

The game renders at 1600×900 and gamescope upscales to the panel with FSR. Costs the
game nothing — the compositor does the scaling.

The second line matters: these flags shrink gamescope's *nested* resolution, but the
pre-command would otherwise still size the game to the full panel, so the game would
keep rendering at native and the knob would buy nothing.

### Ultrawide

Vanilla Skyrim SE stretches its HUD, menus, map and dialogue at 21:9. The FOV is
handled automatically, but the UI is not, and the real fix is a mod (see below). The
mod-free workaround is to render 16:9 and let gamescope pillarbox it — uncomment
**both** lines in [`scopebuddy.conf`](./scopebuddy.conf):

```sh
SCB_GAMESCOPE_ARGS="$SCB_GAMESCOPE_ARGS -w 2560 -h 1440 -S fit"
SCB_PRE_COMMAND='"$HOME/.local/bin/skyrim-configure-display" 2560 1440'
```

Correct UI proportions, black bars either side. Passing 2560×1440 to the pre-command
also makes it derive the vanilla 80° FOV rather than the panel's widened one, which is
what a pillarboxed image wants.

### Overrides

`skyrim-configure-display` honours two env vars, useful for testing:

```sh
SKYRIM_FOV=90  SKYRIM_TIER=dgpu  skyrim-configure-display 3440 1440
```

### Restore the intro video

```sh
cd "$(~/.dotfiles/games/lib/steam-find-app-path.sh 489830)/steamapps/common/Skyrim Special Edition/Data/Video"
mv BGS_Logo.bik.bak BGS_Logo.bik
```

Steam's verify-integrity also puts it back.

## Phase 2 — mods

Installed and verified on 2026-08-08, game buildid 13189953. The scope is the
community baseline — script extender, bugfix patch, engine fixes, the standard
UI, and the frame-rate fix. Not an overhaul: no texture packs, no gameplay
rebalance.

| Mod | Version | Installs to |
|---|---|---|
| SKSE64 (AE build, runtime 1.6.1170) | 2.2.6 | game root |
| Address Library for SKSE Plugins | 11 | `Data/SKSE/Plugins/` |
| Unofficial Skyrim SE Patch (USSEP) | 4.3.8a | `Data/` |
| SSE Engine Fixes — Main (FOMOD: `Required` + `AE`) | 7.0.20 | `Data/SKSE/Plugins/` |
| SSE Engine Fixes — SKSE64 Preloader | 7 | game root |
| SkyUI | 6.11 | `Data/` |
| SSE Display Tweaks | 0.5.16 | `Data/SKSE/Plugins/` |

Proof it is actually running, from `My Games/Skyrim Special Edition/SKSE/`:

```
skse64.log        SKSE64 runtime: initialize (version = 2.2.6 …)
                  plugin EngineFixes.dll … loaded correctly (handle 1)
                  plugin SSEDisplayTweaks.dll … loaded correctly (handle 2)
EngineFixes.log   EngineFixes SKSE Load  /  time to main menu 8192
```

If `EngineFixes.log` stops after its PreLoad patch list and there is no
`skse64.log`, SKSE did not load: the preloader hijacks `d3dx9_42.dll` and runs
regardless, so its memory patches land in a process with no SKSE behind them and
the game crashes on Play. That is the signature of the launch wrapper not firing,
not of a bad mod install.

**Before anything else**, set Steam to *Properties → Updates → Only update this game
when I launch it*. Skyrim updates break SKSE, and an update that lands while you have
a modded save is how a playthrough dies.

### No mod manager

Neither Limo nor Mod Organizer 2 is used. Both keep their state outside this repo,
which is the one thing a dotfiles module cannot accept — the other machine could not
be reproduced from a checkout. Instead mods are **declared here and installed by
script**, the same way every other config in this repo works.

- [`mods/manifest.tsv`](./mods/manifest.tsv) — one row per archive: hash,
  destination, load-order position, source URL.
- [`skyrim-install-mods.sh`](./skyrim-install-mods.sh) — verifies each archive's
  sha256, unpacks it to the game root or `Data/`, and rewrites `Plugins.txt`.
  Refuses to install anything whose hash does not match.

There is no Nexus Premium on this account, so nothing downloads unattended. Fetch
the archives in a browser into `~/Downloads/skyrim-mods/`, then:

```sh
skyrim-install-mods --scan >> ~/.dotfiles/games/skyrim-special-edition/mods/manifest.tsv
# edit the generated rows: real name, real source_url, load order
skyrim-install-mods --dry-run
skyrim-install-mods
```

Hashes come from the files that were actually installed and played, not copied off a
mod page — which is the only claim this repo can honestly make about them.

### SKSE

Launched through [`skyrim-skse-launch.sh`](./skyrim-skse-launch.sh), which rewrites
the `SkyrimSE.exe` argument in Steam's command to `skse64_loader.exe`. It runs
*inside* ScopeBuddy rather than replacing it, so INI generation and resolution
detection survive; and it passes the command through untouched when the loader is
absent, so it is harmless before SKSE is installed.

Build **2.2.6** ("Anniversary Edition", game version **1.6.1170**) matches this
install — verified at <https://skse.silverlock.org/>. Re-check with
`strings SkyrimSE.exe | grep -m1 '^1\.6\.'` after any update.

### The Windows runtime the mod pages ask for

Both SSE Engine Fixes and SSE Display Tweaks list **Microsoft Visual C++
Redistributable 2022 (x64)** as an external requirement. On Windows it is usually
already present; under Proton it is not, and without it those SKSE plugins fail
to load and the game starts as though no mods were installed.

`rotz install` handles it — it installs `protontricks` if missing and runs
`vcrun2022` into this game's prefix, skipping the work when
`compatdata/489830/pfx/winetricks.log` already lists it. To check by hand:

```sh
grep -qx vcrun2022 ~/.local/share/Steam/steamapps/compatdata/489830/pfx/winetricks.log
```

Worth knowing because the failure is silent: nothing in the mod archives checks
for the runtime, and SKSE's log says only that the plugin failed to load — it
never mentions the missing runtime.

### Still open after this phase

- A **widescreen UI mod** for the stretched 21:9 HUD and menus, replacing the
  pillarbox workaround.
- **Version-control `SSEDisplayTweaks.ini`.** The frame rate now lives in
  `Data/SKSE/Plugins/SSEDisplayTweaks.ini`, which the mod ships and the installer
  overwrites on every run — so tuning it does not survive a reinstall yet.
- The stray uppercase `Skyrim.INI` still sitting beside the generated
  `Skyrim.ini` in the prefix.

## Files

| File | Links to |
|---|---|
| [`skyrim-configure-display.sh`](./skyrim-configure-display.sh) | `~/.local/bin/skyrim-configure-display` |
| [`skyrim-skse-launch.sh`](./skyrim-skse-launch.sh) | `~/.local/bin/skyrim-skse-launch` |
| [`skyrim-install-mods.sh`](./skyrim-install-mods.sh) | `~/.local/bin/skyrim-install-mods` |
| [`scopebuddy.conf`](./scopebuddy.conf) | `~/.config/scopebuddy/AppID/489830.conf` |
| [`skyrim.conf`](./skyrim.conf) | `~/.config/hypr/conf.d/skyrim.conf` |
| [`mods/manifest.tsv`](./mods/manifest.tsv) | manifest — read by the install script, not linked |
| [`Skyrim.ini`](./Skyrim.ini) | template — read by the script, not linked |
| [`SkyrimPrefs.igpu.ini`](./SkyrimPrefs.igpu.ini) | template — read by the script, not linked |
| [`SkyrimPrefs.dgpu.ini`](./SkyrimPrefs.dgpu.ini) | template — read by the script, not linked |
