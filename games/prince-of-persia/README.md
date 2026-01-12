# Prince of Persia: The Sands of Time - Archival Gaming Configuration

Modern fixes for running Prince of Persia: The Sands of Time (2003) on Arch Linux with Proton.

## What This Fixes

The original Steam release has several issues on modern systems:
- **Launcher popup**: Annoying launcher window before the game starts
- **Resolution limits**: No support for ultrawide or high resolutions
- **HUD positioning**: UI elements misaligned on non-4:3 aspect ratios
- **Input issues**: High-frequency mouse problems
- **Modern GPU compatibility**: D3D9 issues with newer drivers

## Components

### DXWrapper
**Source**: [elishacloud/dxwrapper](https://github.com/elishacloud/dxwrapper)

DirectX wrapper that provides:
- 16x anisotropic filtering
- 60 FPS frame limiter
- Borderless windowed mode
- High-frequency mouse fix
- Launcher bypass (memory patch)

### Mini-Launcher
**Source**: [xan105/Mini-Launcher](https://github.com/xan105/Mini-Launcher)

Lightweight game launcher that:
- Applies Large Address Aware (LAA) patch
- Configures Wine/Proton DLL overrides
- Sets environment variables for Proton

### Widescreen Fix (pop1w)
**Source**: [ThirteenAG/WidescreenFixesPack](https://thirteenag.github.io/wfp#pop_sot)

Enables proper ultrawide support:
- Custom resolutions (3440x1440 configured)
- HUD repositioning for 21:9 aspect ratio
- FOV adjustments

### Hardware.ini
Pre-configured GPU capabilities for AMD Radeon RX 6700 XT with all common resolutions.

## Installation

```bash
# Install the game from Steam first
# Steam App ID: 13600

# Then apply the mods
~/.rotz/bin/rotz install /games/prince-of-persia
```

## Configuration

### Changing Resolution

Edit `pop.ini`:
```ini
[MAIN]
Width = 3440
Height = 1440

[HUD]
; HUD_posX values by aspect ratio:
; 21:9 = -0.347222
; 16:9 = -0.148958
; 16:10 = -0.082450
HUD_posX = -0.347222
```

### Adjusting DXWrapper

Edit `dxwrapper.ini`:
```ini
[d3d9]
AnisotropicFiltering = 16      ; 0-16, texture filtering quality
LimitPerFrameFPS = 60          ; 0 = unlimited
EnableWindowMode = 1           ; 0 = fullscreen, 1 = windowed
WindowModeBorder = 0           ; 0 = borderless
```

## Troubleshooting

### Game doesn't launch
1. Verify Steam has the game installed
2. Check that Proton is set for the game in Steam
3. Try Proton Experimental or GE-Proton

### Mouse issues
The `FixHighFrequencyMouse = 1` setting in dxwrapper.ini should resolve most mouse problems.

### Black screen or crashes
Try setting `D3d9to9Ex = 1` in dxwrapper.ini to use D3D9Ex.

## Phase 2 (Future)

The [Sands of Time Fix Compilation](https://www.moddb.com/games/prince-of-persia-the-sands-of-time/downloads/sands-of-time-fix-compilation) includes additional features:

- **DSOAL**: OpenAL Soft for 3D audio with HRTF (headphone surround)
- **Xidi**: Controller input remapping (gamepad emulation)
- **InputFusion**: Enhanced input handling
- **res.lua**: Dynamic resolution detection
- **ASI loader**: Alternative mod loading approach
