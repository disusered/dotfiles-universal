use serde::Deserialize;
use std::process::Command;

#[derive(Deserialize, Debug)]
pub struct ActiveWindow {
    pub class: String,
    pub pid: i64,
    #[serde(rename = "initialTitle")]
    pub initial_title: String,
}

#[derive(Deserialize, Debug)]
pub struct Client {
    pub address: String,
    pub class: String,
    #[serde(rename = "initialTitle")]
    pub initial_title: String,
    #[allow(dead_code)]
    pub workspace: WorkspaceRef,
}

#[derive(Deserialize, Debug)]
#[allow(dead_code)]
pub struct WorkspaceRef {
    pub name: String,
}

#[derive(Deserialize, Debug)]
pub struct Monitor {
    pub focused: bool,
    #[serde(rename = "specialWorkspace")]
    pub special_workspace: SpecialWorkspace,
}

#[derive(Deserialize, Debug)]
pub struct SpecialWorkspace {
    pub name: String,
}

fn run_hyprctl(args: &[&str]) -> Result<String, String> {
    let output = Command::new("hyprctl")
        .args(args)
        .output()
        .map_err(|e| format!("Failed to run hyprctl: {}", e))?;
    if !output.status.success() {
        let stderr = String::from_utf8_lossy(&output.stderr);
        return Err(format!("hyprctl failed: {}", stderr));
    }
    String::from_utf8(output.stdout).map_err(|e| format!("Invalid UTF-8 from hyprctl: {}", e))
}

pub fn get_active_window() -> Result<ActiveWindow, String> {
    let json = run_hyprctl(&["activewindow", "-j"])?;
    serde_json::from_str(&json).map_err(|e| format!("Failed to parse activewindow: {}", e))
}

pub fn get_clients() -> Result<Vec<Client>, String> {
    let json = run_hyprctl(&["clients", "-j"])?;
    serde_json::from_str(&json).map_err(|e| format!("Failed to parse clients: {}", e))
}

pub fn get_monitors() -> Result<Vec<Monitor>, String> {
    let json = run_hyprctl(&["monitors", "-j"])?;
    serde_json::from_str(&json).map_err(|e| format!("Failed to parse monitors: {}", e))
}

pub fn dispatch_toggle_special(workspace: &str) -> Result<(), String> {
    run_hyprctl(&["dispatch", "togglespecialworkspace", workspace])?;
    Ok(())
}

pub fn dispatch_focus_window(address: &str) -> Result<(), String> {
    let target = format!("address:{}", address);
    run_hyprctl(&["dispatch", "focuswindow", &target])?;
    Ok(())
}

pub fn get_focused_special_workspace(monitors: &[Monitor]) -> Option<String> {
    monitors
        .iter()
        .find(|m| m.focused)
        .and_then(|m| {
            let name = &m.special_workspace.name;
            if name.is_empty() {
                None
            } else {
                Some(name.strip_prefix("special:").unwrap_or(name).to_string())
            }
        })
}

pub fn find_window_by_class_and_title<'a>(
    clients: &'a [Client],
    class: &str,
    title: &str,
) -> Option<&'a Client> {
    clients
        .iter()
        .find(|c| c.class == class && c.initial_title == title)
}

pub fn find_windows_by_class<'a>(clients: &'a [Client], class: &str) -> Vec<&'a Client> {
    clients.iter().filter(|c| c.class == class).collect()
}

#[cfg(test)]
mod tests {
    use super::*;

    fn make_monitor(focused: bool, special_name: &str) -> Monitor {
        Monitor {
            focused,
            special_workspace: SpecialWorkspace {
                name: special_name.to_string(),
            },
        }
    }

    fn make_client(address: &str, class: &str, title: &str, workspace: &str) -> Client {
        Client {
            address: address.to_string(),
            class: class.to_string(),
            initial_title: title.to_string(),
            workspace: WorkspaceRef {
                name: workspace.to_string(),
            },
        }
    }

    #[test]
    fn focused_special_workspace_empty_name() {
        let monitors = vec![make_monitor(true, "")];
        assert!(get_focused_special_workspace(&monitors).is_none());
    }

    #[test]
    fn focused_special_workspace_strips_prefix() {
        let monitors = vec![
            make_monitor(false, ""),
            make_monitor(true, "special:term"),
        ];
        assert_eq!(
            get_focused_special_workspace(&monitors),
            Some("term".to_string())
        );
    }

    #[test]
    fn find_window_by_class_and_title_match() {
        let clients = vec![
            make_client("0x1", "kitty", "zsh", "1"),
            make_client("0x2", "code", "editor", "2"),
        ];
        let found = find_window_by_class_and_title(&clients, "code", "editor");
        assert!(found.is_some());
        assert_eq!(found.unwrap().address, "0x2");
    }

    #[test]
    fn find_window_by_class_and_title_no_match() {
        let clients = vec![make_client("0x1", "kitty", "zsh", "1")];
        assert!(find_window_by_class_and_title(&clients, "code", "editor").is_none());
    }

    #[test]
    fn find_windows_by_class_multiple() {
        let clients = vec![
            make_client("0x1", "kitty", "zsh", "1"),
            make_client("0x2", "kitty", "htop", "2"),
            make_client("0x3", "code", "editor", "3"),
        ];
        let found = find_windows_by_class(&clients, "kitty");
        assert_eq!(found.len(), 2);
    }

    #[test]
    fn find_windows_by_class_no_match() {
        let clients = vec![make_client("0x1", "kitty", "zsh", "1")];
        assert!(find_windows_by_class(&clients, "firefox").is_empty());
    }
}
