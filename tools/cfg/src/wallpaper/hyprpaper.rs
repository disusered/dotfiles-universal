use std::process::Command;
use std::thread;
use std::time::{Duration, Instant};

/// Wait until hyprpaper is ready (polls `hyprctl hyprpaper listloaded`).
/// Times out after 30 seconds.
pub fn wait_for_ready() -> Result<(), String> {
    let deadline = Instant::now() + Duration::from_secs(30);
    loop {
        let output = Command::new("hyprctl")
            .args(["hyprpaper", "listloaded"])
            .output();

        match output {
            Ok(o) if o.status.success() => return Ok(()),
            _ => {}
        }

        if Instant::now() >= deadline {
            return Err("hyprpaper did not become ready within 30 seconds".to_string());
        }

        thread::sleep(Duration::from_millis(200));
    }
}

/// Preload a wallpaper image into hyprpaper.
pub fn preload(path: &str) -> Result<(), String> {
    let output = Command::new("hyprctl")
        .args(["hyprpaper", "preload", path])
        .output()
        .map_err(|e| format!("Failed to run hyprctl: {}", e))?;

    if output.status.success() {
        Ok(())
    } else {
        let stderr = String::from_utf8_lossy(&output.stderr);
        Err(format!("hyprpaper preload failed: {}", stderr))
    }
}

/// Set the wallpaper for a specific monitor.
pub fn set_wallpaper(monitor: &str, path: &str) -> Result<(), String> {
    let arg = format!("{}:{}", monitor, path);
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

/// Unload wallpapers that are no longer in use.
pub fn unload_unused() -> Result<(), String> {
    let output = Command::new("hyprctl")
        .args(["hyprpaper", "unload", "unused"])
        .output()
        .map_err(|e| format!("Failed to run hyprctl: {}", e))?;

    if output.status.success() {
        Ok(())
    } else {
        let stderr = String::from_utf8_lossy(&output.stderr);
        Err(format!("hyprpaper unload failed: {}", stderr))
    }
}

#[cfg(test)]
mod tests {
    #[test]
    fn test_wallpaper_arg_format() {
        // Verify the monitor:path format used in set_wallpaper
        let monitor = "DP-1";
        let path = "/home/user/.cache/wallpapers/wall.png";
        let arg = format!("{}:{}", monitor, path);
        assert_eq!(arg, "DP-1:/home/user/.cache/wallpapers/wall.png");
    }
}
