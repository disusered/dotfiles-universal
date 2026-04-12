pub mod analysis;
pub mod hyprpaper;
pub mod monitors;
pub mod processing;
pub mod tags;

use crate::config::WallpaperConfig;

/// Expand a leading `~` or `~/` to `$HOME` in `s`.
/// Returns `s` unchanged if HOME is unset or the path doesn't start with `~`.
fn expand_tilde(s: &str) -> String {
    if s == "~" {
        if let Ok(home) = std::env::var("HOME") {
            return home;
        }
        return s.to_string();
    }
    if let Some(rest) = s.strip_prefix("~/") {
        if let Ok(home) = std::env::var("HOME") {
            return format!("{}/{}", home, rest);
        }
    }
    s.to_string()
}

/// Resolve `cfg.cache_dir` with tilde expansion; fall back to the default
/// `$HOME/.cache/wallpapers` when it's empty.
fn resolve_cache_dir(cfg: &WallpaperConfig) -> String {
    let raw = expand_tilde(&cfg.cache_dir);
    if !raw.is_empty() {
        return raw;
    }
    match std::env::var("HOME") {
        Ok(home) => format!("{}/.cache/wallpapers", home),
        Err(_) => ".cache/wallpapers".to_string(),
    }
}

/// Apply the wallpaper described by `cfg` across all detected monitors.
///
/// Pipeline:
/// 1. Resolve + validate source path and cache dir.
/// 2. Detect monitors via `hyprctl monitors -j`.
/// 3. Process image: single-monitor → resize/crop to exact dimensions;
///    multi-monitor → build spanning canvas, extract per-monitor slice.
/// 4. `set_wallpaper` each processed image via the hyprpaper IPC. The new
///    hyprpaper API (>= 0.8) auto-loads images and exposes no preload/unload
///    commands, so we just hand off the final file and let hyprpaper manage
///    its own memory.
pub fn apply(cfg: &WallpaperConfig) -> Result<(), String> {
    // 1. Source path
    let source = expand_tilde(&cfg.path);
    if source.is_empty() {
        return Err(
            "wallpaper path not set — run: cfg wallpaper --set path=<file>".to_string(),
        );
    }
    let meta = std::fs::metadata(&source).map_err(|_| {
        format!("wallpaper path does not exist or is not a file: {}", source)
    })?;
    if !meta.is_file() {
        return Err(format!(
            "wallpaper path does not exist or is not a file: {}",
            source
        ));
    }

    // 2. Cache dir
    let cache_dir = resolve_cache_dir(cfg);

    // 3. Monitors
    let layout = monitors::MonitorLayout::detect()?;

    // 4. Process + collect per-monitor entries
    let mut entries = Vec::new();

    if layout.is_single() {
        let m = &layout.monitors[0];
        let img = processing::resize_and_crop(
            &source,
            m.width,
            m.height,
            &cfg.gravity,
            &cache_dir,
        )?;
        entries.push(hyprpaper::WallpaperEntry {
            monitor: m.name.clone(),
            path: img,
        });
    } else {
        let spanning = processing::create_spanning_image(
            &source,
            layout.total_width(),
            layout.max_height(),
            &cfg.gravity,
            &cache_dir,
        )?;
        let min_x = layout.min_x();
        for m in &layout.monitors {
            let x_offset = m.x - min_x;
            let slice = processing::extract_slice(
                &spanning,
                m.width,
                m.height,
                x_offset,
                &cache_dir,
            )?;
            entries.push(hyprpaper::WallpaperEntry {
                monitor: m.name.clone(),
                path: slice,
            });
        }
    }

    // 5. Write config + restart hyprpaper
    hyprpaper::apply_config(&entries)?;

    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn expand_tilde_with_home_set() {
        std::env::set_var("HOME", "/home/test");
        assert_eq!(expand_tilde("~/Pictures/x.png"), "/home/test/Pictures/x.png");
        assert_eq!(expand_tilde("~"), "/home/test");
        assert_eq!(expand_tilde("/absolute/path"), "/absolute/path");
        assert_eq!(expand_tilde(""), "");
        // "~other" should not be expanded (it's a username-style ref)
        assert_eq!(expand_tilde("~other/path"), "~other/path");
    }

    #[test]
    fn resolve_cache_dir_empty_falls_back_to_default() {
        std::env::set_var("HOME", "/home/test");
        let cfg = WallpaperConfig {
            path: String::new(),
            gravity: "Center".to_string(),
            cache_dir: String::new(),
        };
        assert_eq!(resolve_cache_dir(&cfg), "/home/test/.cache/wallpapers");
    }

    #[test]
    fn resolve_cache_dir_expands_tilde() {
        std::env::set_var("HOME", "/home/test");
        let cfg = WallpaperConfig {
            path: String::new(),
            gravity: "Center".to_string(),
            cache_dir: "~/scratch".to_string(),
        };
        assert_eq!(resolve_cache_dir(&cfg), "/home/test/scratch");
    }

    #[test]
    fn apply_empty_path_errors() {
        let cfg = WallpaperConfig {
            path: String::new(),
            gravity: "Center".to_string(),
            cache_dir: "/tmp".to_string(),
        };
        let err = apply(&cfg).unwrap_err();
        assert!(err.contains("wallpaper path not set"), "err = {}", err);
    }

    #[test]
    fn apply_missing_file_errors() {
        let cfg = WallpaperConfig {
            path: "/nonexistent/definitely/not/here.png".to_string(),
            gravity: "Center".to_string(),
            cache_dir: "/tmp".to_string(),
        };
        let err = apply(&cfg).unwrap_err();
        assert!(
            err.contains("does not exist or is not a file"),
            "err = {}",
            err
        );
    }
}
