use std::collections::HashMap;
use serde::Deserialize;
use crate::color::Color;

#[derive(Deserialize)]
struct PaletteFile {
    colors: HashMap<String, String>,
}

/// Catppuccin color palette
pub struct Palette {
    pub colors: HashMap<String, Color>,
}

impl Palette {
    /// Load a palette from a TOML file
    pub fn load(path: &str) -> Result<Self, String> {
        let content = std::fs::read_to_string(path)
            .map_err(|e| format!("Failed to read palette file '{}': {}", path, e))?;

        let file: PaletteFile = toml::from_str(&content)
            .map_err(|e| format!("Failed to parse palette file '{}': {}", path, e))?;

        let mut colors = HashMap::new();
        for (name, hex) in file.colors {
            colors.insert(name.clone(), Color::from_hex(&hex)?);
        }

        Ok(Palette { colors })
    }

    /// Get a color by name
    pub fn get(&self, name: &str) -> Option<&Color> {
        self.colors.get(name)
    }

}
