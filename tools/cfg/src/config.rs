use serde::{Deserialize, Serialize};
use std::fs;
use std::path::Path;

#[derive(Deserialize, Serialize, Debug, Clone)]
pub struct Config {
    pub flavor: String,
    pub primary: String,
    #[serde(default = "default_secondary")]
    pub secondary: String,
    #[serde(default = "default_icon_theme")]
    pub icon_theme: String,
    #[serde(default = "default_gtk_theme")]
    pub gtk_theme: String,
    #[serde(default = "default_qt_style")]
    pub qt_style: String,
    #[serde(default)]
    pub fonts: FontConfig,
    #[serde(default)]
    pub wallpaper: WallpaperConfig,
}

#[derive(Deserialize, Serialize, Debug, Clone, Default)]
pub struct FontConfig {
    #[serde(default = "default_mono")]
    pub mono: String,
    #[serde(default = "default_mono_size")]
    pub mono_size: u32,
    #[serde(default = "default_sans")]
    pub sans: String,
    #[serde(default = "default_sans_size")]
    pub sans_size: u32,
}

#[derive(Deserialize, Serialize, Debug, Clone)]
pub struct WallpaperConfig {
    #[serde(default = "default_wallpaper_path")]
    pub path: String,
    #[serde(default = "default_wallpaper_gravity")]
    pub gravity: String,
    #[serde(default = "default_wallpaper_cache_dir")]
    pub cache_dir: String,
    #[serde(default = "default_wallpaper_source_dir")]
    pub source_dir: String,
}

fn default_wallpaper_path() -> String {
    String::new()
}

fn default_wallpaper_gravity() -> String {
    "Center".to_string()
}

fn default_wallpaper_cache_dir() -> String {
    let home = std::env::var("HOME").unwrap_or_default();
    format!("{}/.cache/wallpapers", home)
}

fn default_wallpaper_source_dir() -> String {
    String::new()
}

impl Default for WallpaperConfig {
    fn default() -> Self {
        WallpaperConfig {
            path: default_wallpaper_path(),
            gravity: default_wallpaper_gravity(),
            cache_dir: default_wallpaper_cache_dir(),
            source_dir: default_wallpaper_source_dir(),
        }
    }
}

fn default_secondary() -> String {
    "mauve".to_string()
}

fn default_mono() -> String {
    "JetBrainsMono Nerd Font".to_string()
}

fn default_mono_size() -> u32 {
    10
}

fn default_sans() -> String {
    "Noto Sans".to_string()
}

fn default_sans_size() -> u32 {
    11
}

fn default_icon_theme() -> String {
    "Papirus-Dark".to_string()
}

fn default_gtk_theme() -> String {
    "Adwaita".to_string()
}

fn default_qt_style() -> String {
    "Darkly".to_string()
}

impl Config {
    /// Load config from a TOML file
    pub fn load(path: &str) -> Result<Self, String> {
        let content = fs::read_to_string(path)
            .map_err(|e| format!("Failed to read config file '{}': {}", path, e))?;
        toml::from_str(&content)
            .map_err(|e| format!("Failed to parse config file '{}': {}", path, e))
    }

    /// Save config to a TOML file
    pub fn save(&self, path: &str) -> Result<(), String> {
        let content = toml::to_string_pretty(self)
            .map_err(|e| format!("Failed to serialize config: {}", e))?;

        // Ensure parent directory exists
        if let Some(parent) = Path::new(path).parent() {
            fs::create_dir_all(parent).map_err(|e| format!("Failed to create directory: {}", e))?;
        }

        fs::write(path, content)
            .map_err(|e| format!("Failed to write config file '{}': {}", path, e))
    }

    /// Get a config value by key
    pub fn get(&self, key: &str) -> Option<String> {
        match key {
            "flavor" => Some(self.flavor.clone()),
            "primary" => Some(self.primary.clone()),
            "secondary" => Some(self.secondary.clone()),
            "icon_theme" => Some(self.icon_theme.clone()),
            "gtk_theme" => Some(self.gtk_theme.clone()),
            "qt_style" => Some(self.qt_style.clone()),
            "fonts.mono" => Some(self.fonts.mono.clone()),
            "fonts.mono_size" => Some(self.fonts.mono_size.to_string()),
            "fonts.sans" => Some(self.fonts.sans.clone()),
            "fonts.sans_size" => Some(self.fonts.sans_size.to_string()),
            "wallpaper.path" => Some(self.wallpaper.path.clone()),
            "wallpaper.gravity" => Some(self.wallpaper.gravity.clone()),
            "wallpaper.cache_dir" => Some(self.wallpaper.cache_dir.clone()),
            "wallpaper.source_dir" => Some(self.wallpaper.source_dir.clone()),
            _ => None,
        }
    }

    /// Set a config value by key
    pub fn set(&mut self, key: &str, value: &str) -> Result<(), String> {
        match key {
            "flavor" => {
                let valid = ["mocha", "macchiato", "frappe", "latte"];
                if valid.contains(&value) {
                    self.flavor = value.to_string();
                    Ok(())
                } else {
                    Err(format!("Invalid flavor '{}'. Valid: {:?}", value, valid))
                }
            }
            "primary" => {
                self.primary = value.to_string();
                Ok(())
            }
            "secondary" => {
                self.secondary = value.to_string();
                Ok(())
            }
            "icon_theme" => {
                self.icon_theme = value.to_string();
                Ok(())
            }
            "gtk_theme" => {
                self.gtk_theme = value.to_string();
                Ok(())
            }
            "qt_style" => {
                self.qt_style = value.to_string();
                Ok(())
            }
            "fonts.mono" => {
                self.fonts.mono = value.to_string();
                Ok(())
            }
            "fonts.mono_size" => {
                self.fonts.mono_size = value
                    .parse()
                    .map_err(|_| format!("Invalid number: {}", value))?;
                Ok(())
            }
            "fonts.sans" => {
                self.fonts.sans = value.to_string();
                Ok(())
            }
            "fonts.sans_size" => {
                self.fonts.sans_size = value
                    .parse()
                    .map_err(|_| format!("Invalid number: {}", value))?;
                Ok(())
            }
            "wallpaper.path" => {
                self.wallpaper.path = value.to_string();
                Ok(())
            }
            "wallpaper.gravity" => {
                const VALID_GRAVITY: &[&str] = &[
                    "NorthWest", "North", "NorthEast",
                    "West", "Center", "East",
                    "SouthWest", "South", "SouthEast",
                ];
                if VALID_GRAVITY.contains(&value) {
                    self.wallpaper.gravity = value.to_string();
                    Ok(())
                } else {
                    Err(format!("Invalid gravity '{}'. Valid: {:?}", value, VALID_GRAVITY))
                }
            }
            "wallpaper.cache_dir" => {
                self.wallpaper.cache_dir = value.to_string();
                Ok(())
            }
            "wallpaper.source_dir" => {
                self.wallpaper.source_dir = value.to_string();
                Ok(())
            }
            _ => Err(format!("Unknown config key: {}", key)),
        }
    }
}

impl Default for Config {
    fn default() -> Self {
        Config {
            flavor: "mocha".to_string(),
            primary: "blue".to_string(),
            secondary: "mauve".to_string(),
            icon_theme: "Papirus-Dark".to_string(),
            gtk_theme: "Adwaita".to_string(),
            qt_style: "Darkly".to_string(),
            fonts: FontConfig::default(),
            wallpaper: WallpaperConfig::default(),
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_wallpaper_gravity_valid() {
        let mut config = Config::default();
        assert!(config.set("wallpaper.gravity", "Center").is_ok());
        assert!(config.set("wallpaper.gravity", "NorthWest").is_ok());
        assert!(config.set("wallpaper.gravity", "SouthEast").is_ok());
    }

    #[test]
    fn test_wallpaper_gravity_invalid() {
        let mut config = Config::default();
        assert!(config.set("wallpaper.gravity", "middle").is_err());
        assert!(config.set("wallpaper.gravity", "center").is_err()); // case-sensitive
    }

    #[test]
    fn test_wallpaper_path_roundtrip() {
        let mut config = Config::default();
        config.set("wallpaper.path", "~/Pictures/Wallpaper").unwrap();
        assert_eq!(config.get("wallpaper.path").unwrap(), "~/Pictures/Wallpaper");
    }

    #[test]
    fn test_wallpaper_cache_dir_default() {
        let config = Config::default();
        let cache = config.get("wallpaper.cache_dir").unwrap();
        assert!(cache.ends_with("/.cache/wallpapers"));
    }

    #[test]
    fn wallpaper_source_dir_default_empty() {
        let config = Config::default();
        assert_eq!(config.get("wallpaper.source_dir").unwrap(), "");
    }

    #[test]
    fn wallpaper_source_dir_roundtrip() {
        let mut config = Config::default();
        config
            .set("wallpaper.source_dir", "~/Pictures/Wallpapers/catppuccin-mocha")
            .unwrap();
        assert_eq!(
            config.get("wallpaper.source_dir").unwrap(),
            "~/Pictures/Wallpapers/catppuccin-mocha"
        );
    }
}
