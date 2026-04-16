use std::collections::HashMap;
use std::collections::HashSet;
use std::path::PathBuf;
use std::process::Command;
use std::time::{Duration, Instant};
use serde::Deserialize;

use crate::config::Config;
use crate::palette::Palette;
use crate::render::{build_context, render_to_file};

pub const DEFAULT_RELOAD_TIMEOUT: Duration = Duration::from_secs(5);

#[derive(Deserialize, Debug, Clone)]
#[allow(dead_code)]
pub struct TemplateConfig {
    pub path: String,
    pub reload: Option<String>,
    /// Rotz module to re-link after rendering (e.g., "/arch/wlogout")
    pub link: Option<String>,
    /// Fire-and-forget: spawn and return immediately without waiting
    #[serde(default)]
    pub background: bool,
}

#[derive(Deserialize, Debug)]
pub struct TemplatesFile {
    pub templates: HashMap<String, TemplateConfig>,
}

/// A coalesced reload group: command, template names, and whether to background.
pub struct ReloadGroup<'a> {
    pub cmd: &'a str,
    pub names: Vec<&'a str>,
    pub background: bool,
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

/// Group rendered template names by their reload command, preserving first-seen order.
/// Templates without a reload command or not found in the registry are skipped.
/// If any template in a group has `background = true`, the whole group is backgrounded.
pub fn coalesce_reloads<'a>(
    rendered: &'a [String],
    templates: &'a TemplatesFile,
) -> Vec<ReloadGroup<'a>> {
    let mut groups: Vec<ReloadGroup<'a>> = Vec::new();

    for name in rendered {
        let Some(tpl) = templates.get(name) else { continue };
        let Some(cmd) = tpl.reload.as_deref() else { continue };

        if let Some(group) = groups.iter_mut().find(|g| g.cmd == cmd) {
            group.names.push(name.as_str());
            if tpl.background {
                group.background = true;
            }
        } else {
            groups.push(ReloadGroup {
                cmd,
                names: vec![name.as_str()],
                background: tpl.background,
            });
        }
    }

    groups
}

/// Reload an application using its reload command, with a timeout.
/// On timeout, the child process is killed.
pub fn reload_app(cmd: &str, timeout: Duration) -> Result<(), String> {
    let mut child = Command::new("sh")
        .arg("-c")
        .arg(cmd)
        .spawn()
        .map_err(|e| format!("Failed to spawn: {}", e))?;

    let start = Instant::now();
    loop {
        match child.try_wait() {
            Ok(Some(status)) => {
                return if status.success() {
                    Ok(())
                } else {
                    Err(format!("exit code: {:?}", status.code()))
                };
            }
            Ok(None) => {
                if start.elapsed() >= timeout {
                    let _ = child.kill();
                    let _ = child.wait();
                    return Err(format!("timed out after {}s", timeout.as_secs()));
                }
                std::thread::sleep(Duration::from_millis(50));
            }
            Err(e) => return Err(format!("wait error: {}", e)),
        }
    }
}

/// Spawn a reload command in the background (fire-and-forget).
/// Returns immediately without waiting for completion.
pub fn reload_app_background(cmd: &str) -> Result<(), String> {
    Command::new("sh")
        .arg("-c")
        .arg(cmd)
        .spawn()
        .map_err(|e| format!("Failed to spawn: {}", e))?;
    Ok(())
}

/// Run rotz link for a specific module (with -f to force overwrite)
pub fn rotz_link(module: &str) -> Result<(), String> {
    let home = std::env::var("HOME").map_err(|_| "HOME not set")?;
    let rotz_bin = format!("{}/.rotz/bin/rotz", home);

    let status = Command::new(&rotz_bin)
        .arg("link")
        .arg("-f")
        .arg(module)
        .status()
        .map_err(|e| format!("Failed to execute rotz link: {}", e))?;

    if status.success() {
        Ok(())
    } else {
        Err(format!("rotz link failed with exit code: {:?}", status.code()))
    }
}

/// Result of rendering a single template.
pub struct RenderResult {
    pub name: String,
    pub output: Result<PathBuf, String>,
}

/// Result of running a reload group.
pub struct ReloadResult {
    pub names: Vec<String>,
    pub result: Result<(), String>,
}

/// Full result of an update operation (render + link + reload).
pub struct UpdateResult {
    pub rendered: Vec<RenderResult>,
    pub reloaded: Vec<ReloadResult>,
}

/// Run a full update: render templates, symlink, and reload apps.
/// Returns structured results instead of printing to stdout.
pub fn run_update(cfg_dir: &str, dotfiles_dir: &str, names: &[String]) -> Result<UpdateResult, String> {
    let config = Config::load(&format!("{}/config.toml", cfg_dir)).unwrap_or_default();
    let palette_path = format!("{}/palettes/{}.toml", cfg_dir, config.flavor);
    let palette = Palette::load(&palette_path)
        .map_err(|e| format!("Error loading palette: {}", e))?;

    let context = build_context(&config, &palette);

    let templates_path = format!("{}/templates.toml", cfg_dir);
    let templates = TemplatesFile::load(&templates_path)?;

    let targets: Vec<&String> = if names.is_empty() {
        templates.names()
    } else {
        for name in names {
            if templates.get(name).is_none() {
                return Err(format!("Unknown template: {}", name));
            }
        }
        names.iter().collect()
    };

    let mut rendered_names: Vec<String> = Vec::new();
    let mut render_results: Vec<RenderResult> = Vec::new();
    let mut linked: HashSet<String> = HashSet::new();

    for name in &targets {
        let tpl_config = templates.get(name).unwrap();
        let template_path = PathBuf::from(format!("{}/{}", dotfiles_dir, tpl_config.path));

        if !template_path.exists() {
            render_results.push(RenderResult {
                name: (*name).clone(),
                output: Err(format!("template not found: {}", template_path.display())),
            });
            continue;
        }

        match render_to_file(&template_path, &context, false) {
            Ok(output) => {
                rendered_names.push((*name).clone());

                if let Some(link_module) = &tpl_config.link {
                    if !linked.contains(link_module) {
                        let _ = rotz_link(link_module);
                        linked.insert(link_module.clone());
                    }
                }

                render_results.push(RenderResult {
                    name: (*name).clone(),
                    output: Ok(output),
                });
            }
            Err(e) => {
                render_results.push(RenderResult {
                    name: (*name).clone(),
                    output: Err(e),
                });
            }
        }
    }

    let mut reload_results: Vec<ReloadResult> = Vec::new();
    if !rendered_names.is_empty() {
        for group in coalesce_reloads(&rendered_names, &templates) {
            let result = if group.background {
                reload_app_background(group.cmd)
            } else {
                reload_app(group.cmd, DEFAULT_RELOAD_TIMEOUT)
            };
            reload_results.push(ReloadResult {
                names: group.names.iter().map(|s| s.to_string()).collect(),
                result,
            });
        }
    }

    Ok(UpdateResult {
        rendered: render_results,
        reloaded: reload_results,
    })
}

#[cfg(test)]
mod tests {
    use super::*;

    fn make_templates(entries: Vec<(&str, Option<&str>, bool)>) -> TemplatesFile {
        let mut templates = HashMap::new();
        for (name, reload, background) in entries {
            templates.insert(name.to_string(), TemplateConfig {
                path: format!("test/{}.tera", name),
                reload: reload.map(|s| s.to_string()),
                link: None,
                background,
            });
        }
        TemplatesFile { templates }
    }

    // =========================================================================
    // coalesce_reloads
    // =========================================================================

    #[test]
    fn coalesce_deduplicates_same_command() {
        let tpl = make_templates(vec![
            ("a", Some("hyprctl reload"), false),
            ("b", Some("hyprctl reload"), false),
            ("c", Some("hyprctl reload"), false),
        ]);
        let rendered: Vec<String> = vec!["a", "b", "c"].into_iter().map(String::from).collect();

        let groups = coalesce_reloads(&rendered, &tpl);
        assert_eq!(groups.len(), 1);
        assert_eq!(groups[0].cmd, "hyprctl reload");
        assert_eq!(groups[0].names, vec!["a", "b", "c"]);
        assert!(!groups[0].background);
    }

    #[test]
    fn coalesce_preserves_order() {
        let tpl = make_templates(vec![
            ("x", Some("cmd-x"), false),
            ("y", Some("cmd-y"), false),
            ("z", Some("cmd-x"), false),
        ]);
        let rendered: Vec<String> = vec!["x", "y", "z"].into_iter().map(String::from).collect();

        let groups = coalesce_reloads(&rendered, &tpl);
        assert_eq!(groups.len(), 2);
        assert_eq!(groups[0].cmd, "cmd-x");
        assert_eq!(groups[0].names, vec!["x", "z"]);
        assert_eq!(groups[1].cmd, "cmd-y");
        assert_eq!(groups[1].names, vec!["y"]);
    }

    #[test]
    fn coalesce_skips_no_reload() {
        let tpl = make_templates(vec![
            ("a", Some("reload-a"), false),
            ("b", None, false),
            ("c", Some("reload-a"), false),
        ]);
        let rendered: Vec<String> = vec!["a", "b", "c"].into_iter().map(String::from).collect();

        let groups = coalesce_reloads(&rendered, &tpl);
        assert_eq!(groups.len(), 1);
        assert_eq!(groups[0].names, vec!["a", "c"]);
    }

    #[test]
    fn coalesce_skips_unknown_template() {
        let tpl = make_templates(vec![
            ("a", Some("reload-a"), false),
        ]);
        let rendered: Vec<String> = vec!["a", "unknown"].into_iter().map(String::from).collect();

        let groups = coalesce_reloads(&rendered, &tpl);
        assert_eq!(groups.len(), 1);
        assert_eq!(groups[0].names, vec!["a"]);
    }

    #[test]
    fn coalesce_mixed() {
        let tpl = make_templates(vec![
            ("hyprland", Some("hyprctl reload"), false),
            ("hyprbars", Some("hyprctl reload"), false),
            ("mako", Some("makoctl reload"), false),
            ("kitty", Some("pkill -USR1 kitty"), false),
            ("btop", None, false),
        ]);
        let rendered: Vec<String> = vec!["hyprland", "hyprbars", "mako", "kitty", "btop"]
            .into_iter().map(String::from).collect();

        let groups = coalesce_reloads(&rendered, &tpl);
        assert_eq!(groups.len(), 3);
        assert_eq!(groups[0].cmd, "hyprctl reload");
        assert_eq!(groups[0].names, vec!["hyprland", "hyprbars"]);
        assert_eq!(groups[1].cmd, "makoctl reload");
        assert_eq!(groups[2].cmd, "pkill -USR1 kitty");
    }

    #[test]
    fn coalesce_background_propagates() {
        let tpl = make_templates(vec![
            ("a", Some("firefox url"), true),
            ("b", Some("firefox url"), false),
        ]);
        let rendered: Vec<String> = vec!["a", "b"].into_iter().map(String::from).collect();

        let groups = coalesce_reloads(&rendered, &tpl);
        assert_eq!(groups.len(), 1);
        assert!(groups[0].background);
    }

    #[test]
    fn coalesce_empty_rendered() {
        let tpl = make_templates(vec![("a", Some("cmd"), false)]);
        let rendered: Vec<String> = vec![];
        let groups = coalesce_reloads(&rendered, &tpl);
        assert!(groups.is_empty());
    }

    // =========================================================================
    // reload_app (timeout)
    // =========================================================================

    #[test]
    fn reload_success() {
        assert!(reload_app("true", Duration::from_secs(5)).is_ok());
    }

    #[test]
    fn reload_failure() {
        let err = reload_app("false", Duration::from_secs(5)).unwrap_err();
        assert!(err.contains("exit code"));
    }

    #[test]
    fn reload_timeout_kills() {
        let start = Instant::now();
        let err = reload_app("sleep 60", Duration::from_millis(200)).unwrap_err();
        let elapsed = start.elapsed();

        assert!(err.contains("timed out"));
        assert!(elapsed < Duration::from_secs(1), "should return quickly after timeout");
    }

    // =========================================================================
    // reload_app_background
    // =========================================================================

    #[test]
    fn background_returns_immediately() {
        let start = Instant::now();
        assert!(reload_app_background("sleep 60").is_ok());
        assert!(start.elapsed() < Duration::from_millis(100));
    }
}
