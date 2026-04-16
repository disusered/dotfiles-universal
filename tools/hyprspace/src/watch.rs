use std::env;
use std::io::{BufRead, BufReader, Write};
use std::os::unix::net::UnixStream;

use crate::config::{Config, WorkspaceConfig};
use crate::hyprctl::{dispatch_eject_to_workspace, find_monitor_with_special, get_monitors};

pub fn run(config: &Config) -> Result<(), String> {
    let path = event_socket_path()?;
    let stream = UnixStream::connect(&path)
        .map_err(|e| format!("Failed to connect to {}: {}", path, e))?;
    let reader = BufReader::new(stream);
    log_line(&format!("listening on {}", path));

    for line in reader.lines() {
        let line = match line {
            Ok(l) => l,
            Err(e) => {
                log_line(&format!("read error: {}", e));
                return Err(format!("socket read error: {}", e));
            }
        };
        if let Some(ev) = parse_open_window(&line) {
            log_line(&format!(
                "openwindow addr={} ws={} class={} title={}",
                ev.address, ev.workspace_name, ev.class, ev.title
            ));
            if let Err(e) = handle_open_window(&ev, config) {
                log_line(&format!("handler error for {:?}: {}", ev, e));
            }
        }
    }

    Err("socket stream ended".to_string())
}

fn log_line(msg: &str) {
    let mut stderr = std::io::stderr().lock();
    let _ = writeln!(stderr, "hyprspace watch: {}", msg);
    let _ = stderr.flush();
}

fn event_socket_path() -> Result<String, String> {
    let sig = env::var("HYPRLAND_INSTANCE_SIGNATURE")
        .map_err(|_| "HYPRLAND_INSTANCE_SIGNATURE not set".to_string())?;
    let runtime = env::var("XDG_RUNTIME_DIR")
        .map_err(|_| "XDG_RUNTIME_DIR not set".to_string())?;
    Ok(format!("{}/hypr/{}/.socket2.sock", runtime, sig))
}

#[derive(Debug, PartialEq, Eq)]
pub struct OpenWindowEvent {
    pub address: String,
    pub workspace_name: String,
    pub class: String,
    pub title: String,
}

// Hyprland event format: `EVENT>>DATA\n`. For openwindow, DATA is
// `ADDR,WSNAME,CLASS,TITLE`. TITLE can contain commas, so we only split
// on the first three.
pub fn parse_open_window(line: &str) -> Option<OpenWindowEvent> {
    let rest = line.strip_prefix("openwindow>>")?;
    let mut parts = rest.splitn(4, ',');
    let address = parts.next()?.to_string();
    let workspace_name = parts.next()?.to_string();
    let class = parts.next()?.to_string();
    let title = parts.next().unwrap_or("").to_string();
    if address.is_empty() {
        return None;
    }
    Some(OpenWindowEvent {
        address,
        workspace_name,
        class,
        title,
    })
}

// Decide whether an openwindow event should trigger an eject.
// Returns Some(hyprspace_workspace_name) if the window landed on a
// hyprspace-managed special workspace with a non-allowed class.
pub fn should_eject<'a>(
    ev: &OpenWindowEvent,
    config: &'a Config,
) -> Option<(&'a str, &'a WorkspaceConfig)> {
    let stripped = ev
        .workspace_name
        .strip_prefix("special:")
        .unwrap_or(&ev.workspace_name);
    // Bare workspace (no `special:` prefix) means a regular workspace — skip.
    if stripped == ev.workspace_name {
        return None;
    }
    let (name, ws) = config
        .workspaces
        .iter()
        .find(|(name, _)| name.as_str() == stripped)?;
    if class_is_allowed(&ev.class, ws) {
        return None;
    }
    Some((name.as_str(), ws))
}

fn class_is_allowed(class: &str, ws: &WorkspaceConfig) -> bool {
    if class == ws.window_class {
        return true;
    }
    ws.extra_classes.iter().any(|c| c == class)
}

fn handle_open_window(ev: &OpenWindowEvent, config: &Config) -> Result<(), String> {
    let Some((ws_name, _ws)) = should_eject(ev, config) else {
        return Ok(());
    };

    let monitors = get_monitors()?;
    // Prefer the monitor that currently shows this special workspace; fall
    // back to the focused monitor if no match (e.g. the workspace was
    // hidden mid-flight).
    let target_id = find_monitor_with_special(&monitors, ws_name)
        .or_else(|| monitors.iter().find(|m| m.focused))
        .map(|m| m.active_workspace.id)
        .ok_or_else(|| "no target monitor".to_string())?;

    let addr = format_address(&ev.address);
    dispatch_eject_to_workspace(target_id, &addr)?;
    log_line(&format!(
        "ejected class={} from special:{} -> ws={}",
        ev.class, ws_name, target_id
    ));
    Ok(())
}

// Hyprland's event socket emits addresses without an `0x` prefix;
// `hyprctl dispatch` selectors want `address:0x<hex>`.
fn format_address(raw: &str) -> String {
    if raw.starts_with("0x") {
        raw.to_string()
    } else {
        format!("0x{}", raw)
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::config::{ContextType, ScratchpadConfig, WorkspaceConfig};
    use std::collections::HashMap;

    fn mk_config(workspaces: Vec<(&str, WorkspaceConfig)>) -> Config {
        let mut map = HashMap::new();
        for (name, ws) in workspaces {
            map.insert(name.to_string(), ws);
        }
        Config {
            scratchpads: ScratchpadConfig { names: vec![] },
            workspaces: map,
        }
    }

    fn mk_workspace(window_class: &str, extras: &[&str]) -> WorkspaceConfig {
        WorkspaceConfig {
            window_class: window_class.to_string(),
            window_title: None,
            title_prefix: None,
            context_type: ContextType::None,
            multi_instance: false,
            dismiss_scratchpads: false,
            spawn_command: vec!["kitty".to_string()],
            extra_classes: extras.iter().map(|s| s.to_string()).collect(),
            spawn_via_desktop: false,
            toggle_spawns: true,
            modal_tag: None,
            inject_parent_nvim: false,
            pass_env: vec![],
        }
    }

    #[test]
    fn parse_open_window_basic() {
        let ev = parse_open_window("openwindow>>5e3ab9aa7fd0,special:ai,kitty,zsh")
            .expect("parse");
        assert_eq!(ev.address, "5e3ab9aa7fd0");
        assert_eq!(ev.workspace_name, "special:ai");
        assert_eq!(ev.class, "kitty");
        assert_eq!(ev.title, "zsh");
    }

    #[test]
    fn parse_open_window_title_with_commas() {
        let ev = parse_open_window("openwindow>>abc,1,firefox,Docs, foo, bar")
            .expect("parse");
        assert_eq!(ev.title, "Docs, foo, bar");
    }

    #[test]
    fn parse_open_window_empty_title() {
        let ev = parse_open_window("openwindow>>abc,1,kitty,").expect("parse");
        assert_eq!(ev.title, "");
    }

    #[test]
    fn parse_open_window_rejects_other_events() {
        assert!(parse_open_window("activewindow>>kitty,zsh").is_none());
        assert!(parse_open_window("closewindow>>abc").is_none());
    }

    #[test]
    fn parse_open_window_rejects_empty_address() {
        assert!(parse_open_window("openwindow>>,1,kitty,zsh").is_none());
    }

    #[test]
    fn should_eject_triggers_for_unknown_class_on_managed_special() {
        let cfg = mk_config(vec![("ai", mk_workspace("claude_modal", &[]))]);
        let ev = OpenWindowEvent {
            address: "abc".into(),
            workspace_name: "special:ai".into(),
            class: "kitty".into(),
            title: "".into(),
        };
        let (name, _) = should_eject(&ev, &cfg).expect("should eject");
        assert_eq!(name, "ai");
    }

    #[test]
    fn should_eject_skips_matching_primary_class() {
        let cfg = mk_config(vec![("ai", mk_workspace("claude_modal", &[]))]);
        let ev = OpenWindowEvent {
            address: "abc".into(),
            workspace_name: "special:ai".into(),
            class: "claude_modal".into(),
            title: "".into(),
        };
        assert!(should_eject(&ev, &cfg).is_none());
    }

    #[test]
    fn should_eject_skips_matching_extra_class() {
        let cfg = mk_config(vec![(
            "ai",
            mk_workspace("claude_modal", &["chrome-gemini.google.com__-Default"]),
        )]);
        let ev = OpenWindowEvent {
            address: "abc".into(),
            workspace_name: "special:ai".into(),
            class: "chrome-gemini.google.com__-Default".into(),
            title: "".into(),
        };
        assert!(should_eject(&ev, &cfg).is_none());
    }

    #[test]
    fn should_eject_skips_regular_workspace() {
        let cfg = mk_config(vec![("ai", mk_workspace("claude_modal", &[]))]);
        let ev = OpenWindowEvent {
            address: "abc".into(),
            workspace_name: "1".into(),
            class: "kitty".into(),
            title: "".into(),
        };
        assert!(should_eject(&ev, &cfg).is_none());
    }

    #[test]
    fn should_eject_skips_unmanaged_special_workspace() {
        // pypr creates special:scratchpad_btop — hyprspace doesn't own it
        // and must leave it alone.
        let cfg = mk_config(vec![("ai", mk_workspace("claude_modal", &[]))]);
        let ev = OpenWindowEvent {
            address: "abc".into(),
            workspace_name: "special:scratchpad_btop".into(),
            class: "btop_scratch".into(),
            title: "".into(),
        };
        assert!(should_eject(&ev, &cfg).is_none());
    }

    #[test]
    fn format_address_adds_prefix() {
        assert_eq!(format_address("5e3a"), "0x5e3a");
    }

    #[test]
    fn format_address_preserves_existing_prefix() {
        assert_eq!(format_address("0x5e3a"), "0x5e3a");
    }
}
