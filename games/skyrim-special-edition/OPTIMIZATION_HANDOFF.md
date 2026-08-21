# Skyrim optimization handoff

Last verified: 2026-08-21

## Current outcome

The desktop-wide cursor stalls are fixed in the saved configuration. The user
completed an extended play session after the live fix and described Skyrim as
smooth and looking good.

No benchmark is armed (`skyrim-benchmark status` reported
`STATE=NO_ACTIVE_RUN`). The current goal for any later pass is FPS improvement
without disturbing this known-good mouse/presentation behavior.

## This computer and its displays

- One computer and one GPU: Intel Core i9-13900HK with integrated Intel Iris Xe
  (`i915`). There is no RX 6700 XT and no discrete-GPU configuration to target.
- The machine moves between display layouts. At handoff, two Samsung LS24D31x
  displays were active at 1920x1080@75 on `HDMI-A-1` and `HDMI-A-2`. Serial-
  specific rules select 75 Hz without affecting the DP-1 ultrawide.
- The successful large-monitor session used `DP-1` at
  3440x1440@143.975. Do not project a resolution or aspect ratio from one layout
  onto the other.
- ScopeBuddy detects the focused output. `skyrim-configure-display` regenerates
  the INIs at that output's native resolution on every normal launch.
- Hyprland is 0.55.2 with Aquamarine 0.11.0. Installed Gamescope is 3.16.23.

## Proven cursor-stall bug and saved fix

Four nominally per-game Hyprland rules matched only `class=gamescope`. They
therefore applied to every Gamescope surface, not just their named game. Each
rule set `immediate=true`, while Hyprland globally allowed tearing. That put the
nested Gamescope surface and output onto Hyprland's experimental immediate /
tearing presentation path.

The decisive live A/B changed only the active Gamescope client from
`immediate=true` to `immediate=false`:

- before: `activelyTearing=true`; 78 Gamescope Wayland
  release-without-acquire errors in two minutes; hard cursor stalls;
- after: `activelyTearing=false`; zero of those errors in the next two minutes;
  hardware cursors became active; the user immediately reported that it was
  "super smooth".

The exact internal Hyprland/Aquamarine failure is not proven, but the faulty
configuration path and successful removal are observed facts. It was a
compositor/presentation stall, not ordinary low FPS: the pointer hard-froze for
seconds and remained broken on the desktop after Alt-Tab.

The fix has two parts:

- `general:allow_tearing=false` in the tracked and generated Hyprland configs;
- one shared Steam Gamescope rule with `immediate=false` and fullscreen gaming
  decorations disabled;
- a global ScopeBuddy warning forbidding generic `class=gamescope`
  `immediate=true` rules in future game modules.

The former per-game copies were deleted along with their Rotz links. Do not
recreate title-named files whose only selector is the generic Gamescope class.

Do not re-enable either side as a casual latency optimization.

## Known-good runtime configuration

- Hyprland VFR remains enabled. It reduced compositor CPU use but did not fix
  the cursor stall by itself.
- ScopeBuddy uses Gamescope's Wayland backend with fullscreen, keyboard grab,
  focused-output preference, and automatic native output sizing.
- Skyrim adds `--force-windows-fullscreen`. Do not restore
  `--force-grab-cursor`; Gamescope 3.16.x previously froze while panning with
  that option.
- ScopeBuddy's nested preload handling keeps Steam's overlay out of Gamescope
  while preserving it in Skyrim. This already implements the substance of the
  known upstream long-session overlay-stutter workaround.
- Normal play has no MangoHud benchmark HUD or recording.
- SSE Display Tweaks owns presentation and physics: VSync on, tearing off,
  dynamic Havok timing, `LockCursor=true`, and a 240 FPS ceiling.
- The Intel template is authoritative: 1024 shadow maps and
  `iNumFocusShadow=1`. The unused dGPU template is not evidence of another GPU.
- Skyrim runs borderless at the focused monitor's native resolution. No FSR or
  forced internal 1600x900 profile is active during normal play.
- Both subtitle flags are pinned to `1` in both templates and in the generated
  live `SkyrimPrefs.ini`. Generated INIs are read-only so Steam and the launcher
  cannot reset them.

## Historical evidence

`T1` through `T5` are local test-run IDs from
[`benchmark/matrix.tsv`](./benchmark/matrix.tsv); `D0` and `D1` are diagnostic
run IDs from the FPS and presentation ledgers. They are experiment labels, not
Skyrim, mod, or software versions. The older runs are useful only as history:

- T1: controlled indoor native 1920x1080 run, 121.8 seconds, 49.9 average FPS,
  27.17 1% low, 19.67 0.1% low; cursor good after shader warm-up.
- T2: second qualitatively good native run, but no confirmed recording. Do not
  attach the separate 52.3 FPS CSV to T2; it has no run metadata.
- T3: FSR 1600x900 to 1920x1080, stopped after 18.9 seconds when cursor jank
  returned. Its FPS is not duration-comparable.
- T4: exact FSR repeat also had cursor jank and was rejected at the time.
- D1: VFR reduced Hyprland CPU but cursor jank returned, falsifying VFR as the
  cursor fix.
- D0: the immediate-off live diagnostic above was positive and led to the
  persistent fix.
- T5 was never run. It is invalid now because `iNumFocusShadow=1` is already in
  the saved Intel preset and its T1 baseline predates the compositor fix.

T3/T4 predate the compositor fix, so they do not prove that FSR itself is
broken. They do prove that changing render profile while presentation state was
unstable produced unusable runs. Do not resurrect that profile automatically.

The post-fix FPS baseline has not been formally recorded. Earlier testing was
indoors—an ideal condition—and the user noted that outdoor FPS will be worse.

## Classical optimization pass

The user redirected this pass away from bespoke first-principles experiments
and toward mature Skyrim SE/Bethesda optimizations. The first target is native
1920x1080 with TAA and the current visual character preserved; Hyprland,
Gamescope, kernel, and machine-wide tuning remain out of scope.

Three changes were selected on 2026-08-21:

- [Cleaned Skyrim SE Textures](https://www.nexusmods.com/skyrimspecialedition/mods/38775)
  `Kart_CSSET_POST_1.6.1130` v1.2.3.4. This is the package explicitly covering
  runtime 1.6.1170. It replaces `Skyrim - Textures0.bsa` through
  `Skyrim - Textures8.bsa` with cleaned BC7 assets while retaining the vanilla
  look. Install priority is base game/DLC, USSEP, CSSET, then every other mod.
- SSE Display Tweaks' dynamic Havok range is changed from `60..240` to
  `50..auto`. The plugin documentation and the
  [STEP display guide](https://stepmodifications.org/wiki/Guide%3ASkyrim_SE_Display_Settings)
  recommend these values when the game struggles below 60 FPS and the plugin's
  limiter or VSync is active. That matches the historical ~50 FPS result and
  the machine's movement between 60 Hz and 144 Hz outputs.
- `bBackgroundLoadVMData=1` is added to `Skyrim.ini`, matching
  [BethINI's Recommended Tweaks](https://www.nexusmods.com/skyrimspecialedition/mods/4875)
  for background Papyrus VM-data loading without changing image quality.

The nine original texture BSAs were copied to
`~/.local/state/skyrim-mods/baseline-textures-1.6.1170/` before CSSET and all
nine copies were verified against
[`mods/baseline-textures-1.6.1170.sha256`](./mods/baseline-textures-1.6.1170.sha256).
This avoids Steam verification if the direct-overwrite texture replacement
needs to be reversed.

Common recommendations already present are not being duplicated: USSEP
provides `uMaxSizeForCachedSound=4096`; Engine Fixes enables its TBB allocator,
form caching, tree-LOD reference caching, and maximum file handles; Display
Tweaks already owns VSync, frame pacing, and Havok; god rays and SSR are already
off. BethINI is a reference only because the repo-generated, display-aware INIs
remain authoritative.

Deferred until this pass has been played: FSR/internal scaling, static visual
cuts beyond the current preset, Proton or DXVK replacement, Shadow Boost, SSE
FPS Stabilizer, Lightened Skyrim/BOS, eFPS, and other cell/worldspace edits.
These either trade away the requested native image, add experimental behavior,
or affect the current playthrough for less certain first-pass value.

## Separate issues; do not conflate them

- Vulkan shader replay can run `fossilize_replay` near a full CPU core after a
  shader-cache rebuild and temporarily jank the entire desktop. It normally
  settles after roughly 60 seconds. This is separate from the hours-later
  immediate/tearing stall. Repeated rebuilds every launch would be a cache
  invalidation problem worth investigating.
- A malformed Remmina Hyprland regex caused a separate high-rate compositor log
  flood and was fixed. Do not revert that rule.
- Gamescope duplicate-buffer warnings may recur after a game restart. Upstream
  treats at least one such path as normal warning noise; warning counts alone
  are not proof of a performance regression.
- Shader warm-up, ordinary low FPS, and compositor cursor stalls have distinct
  symptoms. Diagnose them separately.

## Host and compositor optimization pass

Ranked by expected return:

1. **PipeWire debug override — fixed.** A local systemd override exported
   `PIPEWIRE_DEBUG=4`, producing roughly 34,000 journal entries per hour. The
   tracked drop-in now unsets it. PipeWire, PipeWire Pulse, and WirePlumber were
   restarted; the audio graph, microphone source, and Bluetooth device remained
   present.
2. **Co-located development workloads — opt-in gaming profile.** The running
   allowlist accounted for about 2.0 GB in user-service cgroups. The active
   Podman sample was about 1.6 GB and 7.2% CPU, with some containers already
   represented by their owning units. `gaming-session arm co-located` makes the
   next normal Skyrim launch stop only the named active workloads (including
   Watchman's activation socket) and restore
   exactly those workloads on exit. `gaming-session run --profile co-located --
   COMMAND` provides an explicit one-shot route. Unknown high-CPU processes are
   reported, never killed.
3. **Samsung refresh selection — fixed.** Hyprland's preferred-mode selection
   left both capable displays at 60 Hz. EDID-specific rules now select 75 Hz and
   keep their left/right placement. The ultrawide remains automatic.
4. **Hyprland render scheduling and direct scanout — leave at defaults.** These
   are experimental presentation paths, not observed misconfigurations.
   Direct scanout is blocked in the normal dual-monitor desktop and overlaps
   the presentation area that caused the cursor-stall regression. They are not
   persisted as optimizations.
5. **Vulkan shader replay — investigate only if recurring.** A one-time
   `fossilize_replay` burst is expected after cache changes. Repeated full replay
   on unchanged launches would indicate cache invalidation and is the next
   medium-ROI target.
6. **Waybar and ordinary journal noise — low ROI.** Keep watching for a new
   sustained flood, but do not trade desktop behavior for isolated warnings.

The gaming profile is deliberately opt-in because this computer also hosts the
development services. It does not disable or mask them persistently.

## Rules for the next optimization pass

1. Preserve `allow_tearing=false`, the shared generic rule's `immediate=false`, VFR,
   native focused-output sizing, and the current ScopeBuddy preload behavior.
2. Record the exact connector, output resolution, refresh rate, route, and
   warm-up before a baseline. Never compare the dual-1080 layout with the
   3440x1440 layout as if only one graphics setting changed.
3. Wait at least 60 seconds for shader replay and asset loading to settle.
4. Record a post-fix native baseline before changing anything.
5. Change one graphics variable at a time, repeat it on the same route/display,
   then decide. Start with GPU-cost settings such as shadow distance/count or
   volumetrics; do not mix them with backend, Gamescope version, overlay,
   resolution, or compositor changes.
6. Include an outdoor route before claiming a general FPS win.
7. Test cursor behavior both inside Skyrim and on the desktop. Desktop-wide
   failure points back to Gamescope/Hyprland rather than a Skyrim FPS setting.
8. Prefer the user's observed playability over counters or log theories.
9. Preserve the current playthrough and modded features. Do not remove mods or
   introduce risky worldspace, navmesh, or save-affecting changes as a casual
   performance experiment.

Useful regression checks:

```bash
hyprctl -j getoption general:allow_tearing
hyprctl -j monitors all | jq '.[] | {name,width,height,refreshRate,activelyTearing}'
hyprctl -j clients | jq '.[] | select(.class == "gamescope") | {address,pid,immediate}'
skyrim-benchmark status
```

Expected during play: global tearing `0`, the Gamescope client
`immediate=false`, and its output `activelyTearing=false`.

## Benchmark-harness status

The experimental benchmark controller and its matrices are separate from this
host-misconfiguration pass. No benchmark is armed. Do not treat pending matrix
rows as work required by this handoff.

The worktree also contains unrelated user changes. Never reset, restore, stash,
or commit the whole tree as an optimization cleanup.

## Authoritative files

- Hyprland policy: `arch/hyprland/hyprland.conf.tera`
- Display policy: `arch/hyprland/display-modes.conf`
- Shared Gamescope policy: `tools/scopebuddy/scb.conf`
- Shared Gamescope window rule: `arch/steam/steam.conf`
- Gaming-session transaction: `arch/steam/gaming-session.sh`
- Gaming-session allowlist: `arch/steam/gaming-session-co-located.tsv`
- PipeWire log policy: `lib/pipewire/pipewire.service.d/override.conf`
- Skyrim launch policy: `games/skyrim-special-edition/scopebuddy.conf`
- Display generator: `games/skyrim-special-edition/skyrim-configure-display.sh`
- Intel settings: `games/skyrim-special-edition/SkyrimPrefs.igpu.ini`
- Display Tweaks: `mods/config/data/SKSE/Plugins/SSEDisplayTweaks.ini`
- Historical FPS ledger: `benchmark/matrix.tsv`
- Historical presentation ledger: `benchmark/presentation-matrix.tsv`
