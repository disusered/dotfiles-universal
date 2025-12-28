use serde::{Deserialize, Serialize};
use std::fs;
use std::path::Path;

#[derive(Deserialize, Serialize, Debug, Clone)]
pub struct Config {
    pub flavor: String,
    pub accent: String,
    #[serde(default = "default_secondary")]
    pub secondary: String,
    #[serde(default = "default_icon_theme")]
    pub icon_theme: String,
    #[serde(default = "default_gtk_theme")]
    pub gtk_theme: String,
    #[serde(default = "default_qt_style")]
    pub qt_style: String,
    #[serde(default = "default_shader")]
    pub shader: String,
    #[serde(default)]
    pub fonts: FontConfig,
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

fn default_shader() -> String {
    "off".to_string()
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
            "accent" => Some(self.accent.clone()),
            "secondary" => Some(self.secondary.clone()),
            "icon_theme" => Some(self.icon_theme.clone()),
            "gtk_theme" => Some(self.gtk_theme.clone()),
            "qt_style" => Some(self.qt_style.clone()),
            "shader" => Some(self.shader.clone()),
            "fonts.mono" => Some(self.fonts.mono.clone()),
            "fonts.mono_size" => Some(self.fonts.mono_size.to_string()),
            "fonts.sans" => Some(self.fonts.sans.clone()),
            "fonts.sans_size" => Some(self.fonts.sans_size.to_string()),
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
            "accent" => {
                self.accent = value.to_string();
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
            "shader" => {
                self.shader = value.to_string();
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
            _ => Err(format!("Unknown config key: {}", key)),
        }
    }
}

impl Default for Config {
    fn default() -> Self {
        Config {
            flavor: "mocha".to_string(),
            accent: "blue".to_string(),
            secondary: "mauve".to_string(),
            icon_theme: "Papirus-Dark".to_string(),
            gtk_theme: "Adwaita".to_string(),
            qt_style: "Darkly".to_string(),
            shader: "off".to_string(),
            fonts: FontConfig::default(),
        }
    }
}
