use crate::config::Config;
use crate::hyprctl::{
    ActiveWindow, Monitor, dispatch_eject_to_workspace, find_monitor_with_special,
    get_active_window, get_monitors,
};

pub fn run(config: &Config) -> Result<(), String> {
    let win = get_active_window()?;
    let monitors = get_monitors()?;
    eject_window(&win, &monitors, config)
}

pub fn eject_window(
    win: &ActiveWindow,
    monitors: &[Monitor],
    config: &Config,
) -> Result<(), String> {
    let Some(ws_name) = hyprspace_special_name(&win.workspace.name, config) else {
        // Not on a hyprspace-managed special workspace — nothing to do.
        return Ok(());
    };

    let target_id = find_monitor_with_special(monitors, ws_name)
        .or_else(|| monitors.iter().find(|m| m.focused))
        .map(|m| m.active_workspace.id)
        .ok_or_else(|| "no target monitor".to_string())?;

    if win.address.is_empty() {
        return Err("active window has no address".to_string());
    }

    dispatch_eject_to_workspace(target_id, &win.address)?;
    Ok(())
}

fn hyprspace_special_name<'a>(ws_name: &'a str, config: &Config) -> Option<&'a str> {
    let stripped = ws_name.strip_prefix("special:")?;
    if config.workspaces.contains_key(stripped) {
        Some(stripped)
    } else {
        None
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::config::{ContextType, ScratchpadConfig, WorkspaceConfig};
    use std::collections::HashMap;

    fn mk_config(names: &[&str]) -> Config {
        let mut map = HashMap::new();
        for name in names {
            map.insert(
                name.to_string(),
                WorkspaceConfig {
                    window_class: "x".to_string(),
                    window_title: None,
                    title_prefix: None,
                    context_type: ContextType::None,
                    multi_instance: false,
                    dismiss_scratchpads: false,
                    spawn_command: vec!["x".to_string()],
                    extra_classes: vec![],
                    spawn_via_desktop: false,
                    toggle_spawns: true,
                    modal_tag: None,
                    inject_parent_nvim: false,
                    pass_env: vec![],
                },
            );
        }
        Config {
            scratchpads: ScratchpadConfig { names: vec![] },
            workspaces: map,
        }
    }

    #[test]
    fn hyprspace_special_name_recognized() {
        let cfg = mk_config(&["ai", "clipboard"]);
        assert_eq!(hyprspace_special_name("special:ai", &cfg), Some("ai"));
    }

    #[test]
    fn hyprspace_special_name_unmanaged() {
        let cfg = mk_config(&["ai"]);
        assert_eq!(
            hyprspace_special_name("special:scratchpad_btop", &cfg),
            None
        );
    }

    #[test]
    fn hyprspace_special_name_regular_workspace() {
        let cfg = mk_config(&["ai"]);
        assert_eq!(hyprspace_special_name("1", &cfg), None);
    }
}
