use std::process::Command;

/// A monitor-to-wallpaper-path mapping.
pub struct WallpaperEntry {
    pub monitor: String,
    pub path: String,
}

/// Generate hyprpaper.conf content with hyprlang block syntax (>= 0.8.3).
///
/// hyprpaper 0.8.3 dropped IPC support and changed config format from flat
/// `wallpaper = mon,path` to block `wallpaper { monitor = ...; path = ... }`.
pub fn generate_config(entries: &[WallpaperEntry]) -> String {
    let mut out = String::from("splash = false\n");
    for entry in entries {
        out.push_str(&format!(
            "\nwallpaper {{\n    monitor = {}\n    path = {}\n}}\n",
            entry.monitor, entry.path
        ));
    }
    out
}

/// Write hyprpaper.conf and restart the hyprpaper service.
///
/// Uses atomic write (temp file + rename) to avoid truncated configs if
/// interrupted. Restarts hyprpaper via systemd to pick up the new config.
pub fn apply_config(entries: &[WallpaperEntry]) -> Result<(), String> {
    let home = std::env::var("HOME").map_err(|_| "HOME not set".to_string())?;
    let config_dir = format!("{}/.config/hypr", home);
    let config_path = format!("{}/hyprpaper.conf", config_dir);
    let tmp_path = format!("{}/hyprpaper.conf.tmp", config_dir);

    std::fs::create_dir_all(&config_dir)
        .map_err(|e| format!("failed to create {}: {}", config_dir, e))?;

    let content = generate_config(entries);
    std::fs::write(&tmp_path, &content)
        .map_err(|e| format!("failed to write {}: {}", tmp_path, e))?;
    std::fs::rename(&tmp_path, &config_path)
        .map_err(|e| format!("failed to rename to {}: {}", config_path, e))?;

    let output = Command::new("systemctl")
        .args(["--user", "restart", "hyprpaper.service"])
        .output()
        .map_err(|e| format!("failed to run systemctl: {}", e))?;

    if output.status.success() {
        Ok(())
    } else {
        let stderr = String::from_utf8_lossy(&output.stderr);
        Err(format!("hyprpaper restart failed: {}", stderr))
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn generate_config_single_monitor() {
        let entries = vec![WallpaperEntry {
            monitor: "DP-1".to_string(),
            path: "/home/user/.cache/wallpapers/abc.jpg".to_string(),
        }];
        let config = generate_config(&entries);
        assert_eq!(
            config,
            "splash = false\n\n\
             wallpaper {\n\
             \x20   monitor = DP-1\n\
             \x20   path = /home/user/.cache/wallpapers/abc.jpg\n\
             }\n"
        );
    }

    #[test]
    fn generate_config_multi_monitor() {
        let entries = vec![
            WallpaperEntry {
                monitor: "DP-1".to_string(),
                path: "/cache/a.jpg".to_string(),
            },
            WallpaperEntry {
                monitor: "HDMI-A-1".to_string(),
                path: "/cache/b.jpg".to_string(),
            },
        ];
        let config = generate_config(&entries);
        assert!(config.starts_with("splash = false\n"));
        assert!(config.contains("monitor = DP-1"));
        assert!(config.contains("path = /cache/a.jpg"));
        assert!(config.contains("monitor = HDMI-A-1"));
        assert!(config.contains("path = /cache/b.jpg"));
        // Two wallpaper blocks
        assert_eq!(config.matches("wallpaper {").count(), 2);
    }

    #[test]
    fn generate_config_empty() {
        let config = generate_config(&[]);
        assert_eq!(config, "splash = false\n");
    }

    #[test]
    fn generate_config_path_with_spaces() {
        let entries = vec![WallpaperEntry {
            monitor: "eDP-1".to_string(),
            path: "/home/user/My Pictures/wall paper.jpg".to_string(),
        }];
        let config = generate_config(&entries);
        assert!(config.contains("path = /home/user/My Pictures/wall paper.jpg"));
    }
}
