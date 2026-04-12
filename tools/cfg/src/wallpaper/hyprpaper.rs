use std::process::Command;

/// Set the wallpaper for a specific monitor via hyprpaper IPC.
///
/// Uses the hyprpaper >= 0.8 API: `hyprctl hyprpaper wallpaper <mon>,<path>`.
/// The daemon auto-loads the image — there is no longer a separate
/// `preload`/`unload`/`listloaded` command set. Callers are expected to pass
/// an already-processed file from `processing::resize_and_crop` (single
/// monitor) or `processing::extract_slice` (multi-monitor).
pub fn set_wallpaper(monitor: &str, path: &str) -> Result<(), String> {
    let arg = format!("{},{}", monitor, path);
    let output = Command::new("hyprctl")
        .args(["hyprpaper", "wallpaper", &arg])
        .output()
        .map_err(|e| format!("Failed to run hyprctl: {}", e))?;

    if output.status.success() {
        Ok(())
    } else {
        let stderr = String::from_utf8_lossy(&output.stderr);
        Err(format!("hyprpaper set wallpaper failed: {}", stderr))
    }
}

#[cfg(test)]
mod tests {
    #[test]
    fn test_wallpaper_arg_format() {
        // Verify the monitor,path format used in set_wallpaper (comma, not colon).
        let monitor = "DP-1";
        let path = "/home/user/.cache/wallpapers/wall.png";
        let arg = format!("{},{}", monitor, path);
        assert_eq!(arg, "DP-1,/home/user/.cache/wallpapers/wall.png");
    }
}
