use serde::Deserialize;
use std::process::Command;

#[derive(Debug, Clone, Deserialize)]
pub struct Monitor {
    pub name: String,
    pub width: u32,
    pub height: u32,
    pub x: i32,
    pub y: i32,
    pub scale: f64,
}

#[derive(Debug)]
pub struct MonitorLayout {
    pub monitors: Vec<Monitor>,
}

// Raw JSON shape from hyprctl monitors -j
#[derive(Deserialize)]
struct HyprMonitor {
    name: String,
    width: u32,
    height: u32,
    x: i32,
    y: i32,
    scale: f64,
}

impl MonitorLayout {
    /// Detect monitors by running `hyprctl monitors -j`
    pub fn detect() -> Result<Self, String> {
        let output = Command::new("hyprctl")
            .args(["monitors", "-j"])
            .output()
            .map_err(|e| format!("Failed to run hyprctl: {}", e))?;

        if !output.status.success() {
            return Err(format!(
                "hyprctl exited with status {}",
                output.status
            ));
        }

        let json = String::from_utf8(output.stdout)
            .map_err(|e| format!("hyprctl output is not valid UTF-8: {}", e))?;

        Self::from_json(&json)
    }

    /// Parse monitor JSON (testable without hyprctl)
    pub fn from_json(json: &str) -> Result<Self, String> {
        let raw: Vec<HyprMonitor> = serde_json::from_str(json)
            .map_err(|e| format!("Failed to parse monitor JSON: {}", e))?;

        if raw.is_empty() {
            return Err("No monitors found".to_string());
        }

        let mut monitors: Vec<Monitor> = raw
            .into_iter()
            .map(|m| Monitor {
                name: m.name,
                width: m.width,
                height: m.height,
                x: m.x,
                y: m.y,
                scale: m.scale,
            })
            .collect();

        // Sort by x position ascending (left to right)
        monitors.sort_by_key(|m| m.x);

        Ok(MonitorLayout { monitors })
    }

    /// Total combined width of all monitors
    pub fn total_width(&self) -> u32 {
        self.monitors
            .iter()
            .map(|m| (m.x + m.width as i32).max(0) as u32)
            .max()
            .unwrap_or(0)
    }

    /// Maximum height across all monitors
    pub fn max_height(&self) -> u32 {
        self.monitors.iter().map(|m| m.height).max().unwrap_or(0)
    }

    /// True if there is exactly one monitor
    pub fn is_single(&self) -> bool {
        self.monitors.len() == 1
    }

    /// Leftmost x position (may be non-zero in multi-head setups)
    pub fn min_x(&self) -> i32 {
        self.monitors.iter().map(|m| m.x).min().unwrap_or(0)
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn dual_json() -> &'static str {
        r#"[
            {"name":"DP-1","width":1920,"height":1080,"x":0,"y":0,"scale":1.0},
            {"name":"DP-2","width":1920,"height":1080,"x":1920,"y":0,"scale":1.0}
        ]"#
    }

    #[test]
    fn test_dual_1920x1080_layout() {
        let layout = MonitorLayout::from_json(dual_json()).unwrap();
        assert_eq!(layout.monitors.len(), 2);
        assert_eq!(layout.total_width(), 3840);
        assert_eq!(layout.max_height(), 1080);
        assert!(!layout.is_single());
        // Sorted by x: DP-1 first
        assert_eq!(layout.monitors[0].name, "DP-1");
        assert_eq!(layout.monitors[1].name, "DP-2");
    }

    #[test]
    fn test_single_ultrawide() {
        let json = r#"[{"name":"DP-1","width":3440,"height":1440,"x":0,"y":0,"scale":1.0}]"#;
        let layout = MonitorLayout::from_json(json).unwrap();
        assert!(layout.is_single());
        assert_eq!(layout.total_width(), 3440);
        assert_eq!(layout.max_height(), 1440);
    }

    #[test]
    fn test_non_zero_x_offset() {
        let json = r#"[
            {"name":"DP-2","width":1920,"height":1080,"x":1920,"y":0,"scale":1.0},
            {"name":"DP-1","width":1920,"height":1080,"x":0,"y":0,"scale":1.0}
        ]"#;
        let layout = MonitorLayout::from_json(json).unwrap();
        assert_eq!(layout.min_x(), 0);
        // Sorted: DP-1 (x=0) before DP-2 (x=1920)
        assert_eq!(layout.monitors[0].name, "DP-1");
        assert_eq!(layout.monitors[1].name, "DP-2");
    }

    #[test]
    fn test_empty_array_error() {
        let result = MonitorLayout::from_json("[]");
        assert!(result.is_err());
        assert!(result.unwrap_err().contains("No monitors"));
    }

    #[test]
    fn test_malformed_json_error() {
        let result = MonitorLayout::from_json("{not valid}");
        assert!(result.is_err());
    }
}
