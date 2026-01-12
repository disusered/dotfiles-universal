# Prince of Persia: The Sands of Time - Archival Gaming Configuration

Modern fixes for running Prince of Persia: The Sands of Time (2003) on Arch Linux with Proton.

## What This Fixes

The original Steam release has several issues on modern systems:
- **Launcher popup**: Annoying launcher window before the game starts
- **Resolution limits**: No support for ultrawide or high resolutions
- **HUD positioning**: UI elements misaligned on non-4:3 aspect ratios
- **Input issues**: High-frequency mouse problems
- **Modern GPU compatibility**: D3D9 issues with newer drivers
- **No 3D audio**: DirectSound3D/EAX disabled on modern Windows
- **Fog bug**: Extreme fog on some systems

## Implemented Features

### Phase 1: Core Fixes
| Feature | Component | Description |
|---------|-----------|-------------|
| D3D9 Wrapper | dxwrapper.dll | DirectX 9 compatibility layer |
| Launcher Bypass | WriteMemory patch | Skips Ubisoft launcher popup |
| LAA Patching | Mini-Launcher | Large Address Aware for >2GB RAM |
| Widescreen Fix | pop1w.dll | 21:9 aspect ratio support (3440x1440) |
| HUD Repositioning | pop.ini | Correct HUD placement for ultrawide |
| High-Freq Mouse Fix | dxwrapper.ini | Fixes erratic mouse on high polling rates |
| Anisotropic Filtering | dxwrapper.ini | 16x texture filtering |
| Frame Limiter | dxwrapper.ini | 60 FPS cap (required for stability) |
| Borderless Windowed | dxwrapper.ini | EnableWindowMode + no border |
| Gamma Shader | dxwrapper.ini | WindowModeGammaShader=2 |
| Fog Fix | Hardware.ini | ForceVSFog=1, InvertFogRange=0 |

### Phase 2: Audio & QoL (Implemented)
| Feature | Component | Description |
|---------|-----------|-------------|
| 3D Positional Audio | DSOAL (dsound.dll) | DirectSound3D/EAX restoration |
| HRTF Headphones | alsoft.ini | Binaural 3D audio for headphones |
| Skip Intro Videos | Install script | Renames intro videos for faster startup |

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

### DSOAL
**Source**: [kcat/dsoal](https://github.com/kcat/dsoal)

DirectSound3D to OpenAL wrapper:
- Restores EAX environmental audio
- Enables 3D positional sound
- HRTF for headphone surround sound

### Hardware.ini
Pre-configured GPU capabilities for AMD Radeon RX 6700 XT with all common resolutions and fog fixes.

## Installation

```bash
# Install the game from Steam first (App ID: 13600)
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
LimitPerFrameFPS = 60          ; 0 = unlimited (not recommended)
EnableWindowMode = 1           ; 0 = fullscreen, 1 = windowed
WindowModeBorder = 0           ; 0 = borderless
```

### Audio Settings

Edit `alsoft.ini`:
```ini
[general]
channels=stereo
stereo-mode=headphones
stereo-encoding=hrtf           ; Enable binaural 3D audio
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

### Extreme fog
Already fixed in Hardware.ini with `ForceVSFog=1` and `InvertFogRange=0`.

### No 3D audio
Ensure dsound.dll override is set to `native,builtin` in launcher.json.

### Restore intro videos
Rename the `.bak` files in `Video/` back to `.int`:
```bash
cd ~/.local/share/Steam/steamapps/common/Prince\ of\ Persia\ The\ Sands\ of\ Time/Video
for f in *.bak; do mv "$f" "${f%.bak}"; done
```

## Available Improvements (Not Yet Implemented)

### Controller Improvements
| Feature | Component | Description |
|---------|-----------|-------------|
| Xidi input remapping | Xidi.32.dll + Xidi.ini | Gamepad-to-DirectInput translation |
| XInput diagonal fix | XInput Plus | Fixes running diagonally with XInput |
| Dual trigger support | XInput Plus | Enables Power of Haste (both triggers) |
| Xbox button prompts | POPData.bf | Replace generic prompts with Xbox icons |

### Video/Graphics Enhancements
| Feature | Component | Description |
|---------|-----------|-------------|
| Skip loading screens | blank.bik | Replace Loading.int with blank video |
| Water effects fix | 3D Vision fix | Fix water not rendering on Intel GPUs |
| Disable bloom/blur | Peixoto's patch | Remove post-processing effects |
| ReShade integration | ReShade 5.9.2 | Cartoon, DPX, Bloom, TAA shaders |
| Remastered textures | vargatomi mod | Higher resolution textures |

### Resolution/Display
| Feature | Component | Description |
|---------|-----------|-------------|
| Dynamic resolution | res.lua | Auto-detect monitor resolution |
| Missing interface fix | Hardware.ini | CanStretchRect=0 |
| Hybrid GPU support | dxwrapper.ini | GraphicsHybridAdapter=1 |

## Sources

- [PCGamingWiki](https://www.pcgamingwiki.com/wiki/Prince_of_Persia:_The_Sands_of_Time)
- [Fix Compilation (ModDB)](https://www.moddb.com/games/prince-of-persia-the-sands-of-time/downloads/sands-of-time-fix-compilation)
- [Steam Guide](https://steamcommunity.com/sharedfiles/filedetails/?id=2227779540)
- [Widescreen Fix](http://ps2wide.net/pc.html#popst)
- [DSOAL](https://github.com/kcat/dsoal)
