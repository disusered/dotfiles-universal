use serde::Deserialize;
use std::collections::HashMap;
use std::fs;

#[derive(Deserialize, Debug)]
pub struct Config {
    pub scratchpads: ScratchpadConfig,
    #[serde(default)]
    pub workspaces: HashMap<String, WorkspaceConfig>,
}

#[derive(Deserialize, Debug)]
pub struct ScratchpadConfig {
    pub names: Vec<String>,
}

#[derive(Deserialize, Debug)]
pub struct WorkspaceConfig {
    pub window_class: String,
    #[allow(dead_code)]
    pub window_title: Option<String>,
    pub title_prefix: Option<String>,
    #[serde(default)]
    pub context_type: ContextType,
    #[serde(default)]
    pub multi_instance: bool,
    #[serde(default = "default_true")]
    pub dismiss_scratchpads: bool,
    pub spawn_command: Vec<String>,
    #[serde(default)]
    pub extra_classes: Vec<String>,
    #[serde(default)]
    #[allow(dead_code)]
    pub spawn_via_desktop: bool,
    // Controls whether `toggle` may spawn a new instance on miss. When false,
    // `toggle` only focuses existing windows; use `spawn` to create. Currently
    // only consulted by Cwd and None context paths; GitRoot still spawns on miss.
    #[serde(default = "default_true")]
    pub toggle_spawns: bool,
    // Exported as HYPRSPACE_MODAL=<tag> to the spawned child. Lets the child
    // call `hyprspace toggle <tag>` to dismiss itself without hardcoding the
    // workspace name.
    #[serde(default)]
    pub modal_tag: Option<String>,
    // When true, resolve a parent Neovim socket for the spawn context
    // (via ~/.cache/nvim-servers/ entries) and export NVIM=<socket> to the
    // spawned child. Silent no-op if no parent nvim is found.
    #[serde(default)]
    pub inject_parent_nvim: bool,
    // Whitelist of env keys to forward from hyprspace's own env into the
    // spawned child. Documents per-workspace env contracts (e.g. the ai
    // workspace expects CLAUDE_CODE_SSE_PORT when launched from nvim).
    #[serde(default)]
    pub pass_env: Vec<String>,
}

fn default_true() -> bool {
    true
}

#[derive(Deserialize, Debug, Default, PartialEq)]
#[serde(rename_all = "snake_case")]
pub enum ContextType {
    #[default]
    None,
    Cwd,
    GitRoot,
}

impl Config {
    pub fn load() -> Result<Self, String> {
        let path = std::env::var("HYPRSPACE_CONFIG").unwrap_or_else(|_| {
            let home = std::env::var("HOME").unwrap_or_default();
            format!("{}/.config/hyprspace/config.toml", home)
        });
        let content = fs::read_to_string(&path)
            .map_err(|e| format!("Failed to read config '{}': {}", path, e))?;
        toml::from_str(&content)
            .map_err(|e| format!("Failed to parse config '{}': {}", path, e))
    }

    pub fn get_workspace(&self, name: &str) -> Option<&WorkspaceConfig> {
        self.workspaces.get(name)
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn parse_config(toml_str: &str) -> Config {
        toml::from_str(toml_str).expect("Failed to parse test config")
    }

    #[test]
    fn context_type_deserialization() {
        let config = parse_config(
            r#"
            [scratchpads]
            names = ["term"]

            [workspaces.a]
            window_class = "a"
            context_type = "none"
            spawn_command = ["a"]

            [workspaces.b]
            window_class = "b"
            context_type = "cwd"
            spawn_command = ["b"]

            [workspaces.c]
            window_class = "c"
            context_type = "git_root"
            spawn_command = ["c"]
            "#,
        );
        assert_eq!(config.workspaces["a"].context_type, ContextType::None);
        assert_eq!(config.workspaces["b"].context_type, ContextType::Cwd);
        assert_eq!(config.workspaces["c"].context_type, ContextType::GitRoot);
    }

    #[test]
    fn missing_workspace_returns_none() {
        let config = parse_config(
            r#"
            [scratchpads]
            names = []
            "#,
        );
        assert!(config.get_workspace("nonexistent").is_none());
    }

    #[test]
    fn dismiss_scratchpads_defaults_to_true() {
        let config = parse_config(
            r#"
            [scratchpads]
            names = []

            [workspaces.test]
            window_class = "test"
            spawn_command = ["test"]
            "#,
        );
        assert!(config.workspaces["test"].dismiss_scratchpads);
    }

    #[test]
    fn spawn_command_preserved() {
        let config = parse_config(
            r#"
            [scratchpads]
            names = []

            [workspaces.editor]
            window_class = "code"
            spawn_command = ["code", "--new-window", "--wait"]
            "#,
        );
        assert_eq!(
            config.workspaces["editor"].spawn_command,
            vec!["code", "--new-window", "--wait"]
        );
    }

    #[test]
    fn toggle_spawns_defaults_to_true() {
        let config = parse_config(
            r#"
            [scratchpads]
            names = []

            [workspaces.test]
            window_class = "test"
            spawn_command = ["test"]
            "#,
        );
        assert!(config.workspaces["test"].toggle_spawns);
    }

    #[test]
    fn toggle_spawns_false_parses() {
        let config = parse_config(
            r#"
            [scratchpads]
            names = []

            [workspaces.test]
            window_class = "test"
            spawn_command = ["test"]
            toggle_spawns = false
            "#,
        );
        assert!(!config.workspaces["test"].toggle_spawns);
    }

    #[test]
    fn extra_classes_defaults_to_empty() {
        let config = parse_config(
            r#"
            [scratchpads]
            names = []

            [workspaces.test]
            window_class = "test"
            spawn_command = ["test"]
            "#,
        );
        assert!(config.workspaces["test"].extra_classes.is_empty());
    }
}
