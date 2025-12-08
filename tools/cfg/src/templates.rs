use std::collections::HashMap;
use std::process::Command;
use serde::Deserialize;

#[derive(Deserialize, Debug, Clone)]
#[allow(dead_code)]
pub struct TemplateConfig {
    pub path: String,
    pub reload: Option<String>,
}

#[derive(Deserialize, Debug)]
pub struct TemplatesFile {
    pub templates: HashMap<String, TemplateConfig>,
}

impl TemplatesFile {
    /// Load templates registry from a TOML file
    pub fn load(path: &str) -> Result<Self, String> {
        let content = std::fs::read_to_string(path)
            .map_err(|e| format!("Failed to read templates file '{}': {}", path, e))?;
        toml::from_str(&content)
            .map_err(|e| format!("Failed to parse templates file '{}': {}", path, e))
    }

    /// Get template config by name
    pub fn get(&self, name: &str) -> Option<&TemplateConfig> {
        self.templates.get(name)
    }

    /// Get all template names
    pub fn names(&self) -> Vec<&String> {
        self.templates.keys().collect()
    }
}

/// Reload an application using its reload command
pub fn reload_app(cmd: &str) -> Result<(), String> {
    let status = Command::new("sh")
        .arg("-c")
        .arg(cmd)
        .status()
        .map_err(|e| format!("Failed to execute reload command: {}", e))?;

    if status.success() {
        Ok(())
    } else {
        Err(format!("Reload command failed with exit code: {:?}", status.code()))
    }
}
