use serde::Deserialize;
use std::process::{Command, Output};

#[derive(Deserialize, Debug)]
pub struct ActiveWindow {
    pub class: String,
    pub pid: i64,
    #[serde(rename = "initialTitle")]
    pub initial_title: String,
    #[serde(default)]
    pub address: String,
    #[serde(default)]
    pub workspace: WorkspaceRef,
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

#[derive(Deserialize, Debug, Default)]
pub struct WorkspaceRef {
    pub name: String,
}

#[derive(Deserialize, Debug)]
pub struct Monitor {
    pub focused: bool,
    #[serde(rename = "specialWorkspace")]
    pub special_workspace: SpecialWorkspace,
    #[serde(rename = "activeWorkspace")]
    pub active_workspace: ActiveWorkspace,
}

#[derive(Deserialize, Debug)]
pub struct SpecialWorkspace {
    pub name: String,
}

#[derive(Deserialize, Debug)]
pub struct ActiveWorkspace {
    pub id: i64,
    #[allow(dead_code)]
    pub name: String,
}

fn run_hyprctl(args: &[&str]) -> Result<String, String> {
    let output = Command::new("hyprctl")
        .args(args)
        .output()
        .map_err(|e| format!("Failed to run hyprctl: {}", e))?;
    if !output.status.success() {
        return Err(hyprctl_error(&output));
    }
    String::from_utf8(output.stdout).map_err(|e| format!("Invalid UTF-8 from hyprctl: {}", e))
}

fn hyprctl_error(output: &Output) -> String {
    let stderr = String::from_utf8_lossy(&output.stderr);
    let stdout = String::from_utf8_lossy(&output.stdout);
    let details = [stderr.trim(), stdout.trim()]
        .into_iter()
        .filter(|s| !s.is_empty())
        .collect::<Vec<_>>()
        .join("; ");
    format!("hyprctl failed ({}): {}", output.status, details)
}

fn lua_string(value: &str) -> String {
    let mut quoted = String::from("\"");
    for ch in value.chars() {
        match ch {
            '\\' => quoted.push_str("\\\\"),
            '"' => quoted.push_str("\\\""),
            ch if ch.is_ascii_control() => quoted.push_str(&format!("\\{:03}", ch as u32)),
            ch => quoted.push(ch),
        }
    }
    quoted.push('"');
    quoted
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
    let code = toggle_special_code(workspace);
    run_hyprctl(&["eval", &code])?;
    Ok(())
}

pub fn dispatch_focus_window(address: &str) -> Result<(), String> {
    let code = focus_window_code(address);
    run_hyprctl(&["eval", &code])?;
    Ok(())
}

pub fn dispatch_show_and_focus(workspace: &str, address: &str) -> Result<(), String> {
    let code = show_and_focus_code(workspace, address);
    run_hyprctl(&["eval", &code])?;
    Ok(())
}

fn show_and_focus_code(workspace: &str, address: &str) -> String {
    format!("{}; {}", toggle_special_code(workspace), focus_window_code(address))
}

// Eject a stray window out of a special workspace while preserving the
// workspace's incumbent group. If the stray got auto-added to an existing
// group (e.g. claude_modal's `group = set` rule makes all openers join its
// tab group), a plain `movetoworkspacesilent` moves the ENTIRE group —
// yanking the incumbent along with the stray. Detach first via
// `moveoutofgroup` (which operates on the focused window) so the move
// targets only the stray. Runs as a single Lua hyprctl call to
// minimize the window where focus is stolen mid-eject.
pub fn dispatch_eject_to_workspace(workspace_id: i64, address: &str) -> Result<(), String> {
    let code = eject_to_workspace_code(workspace_id, address);
    run_hyprctl(&["eval", &code])?;
    Ok(())
}

fn toggle_special_code(workspace: &str) -> String {
    format!("hl.dispatch(hl.dsp.workspace.toggle_special({}))", lua_string(workspace))
}

fn focus_window_code(address: &str) -> String {
    let target = format!("address:{}", address);
    format!("hl.dispatch(hl.dsp.focus({{window = {}}}))", lua_string(&target))
}

fn eject_to_workspace_code(workspace_id: i64, address: &str) -> String {
    let target = lua_string(&format!("address:{}", address));
    format!(
        "hl.dispatch(hl.dsp.focus({{window = {target}}})); \
         hl.dispatch(hl.dsp.window.move({{out_of_group = true}})); \
         hl.dispatch(hl.dsp.window.move({{workspace = {workspace_id}, follow = false, window = {target}}}))"
    )
}

pub fn find_monitor_with_special<'a>(
    monitors: &'a [Monitor],
    special_name: &str,
) -> Option<&'a Monitor> {
    monitors.iter().find(|m| {
        let n = &m.special_workspace.name;
        // Hyprland reports names prefixed with "special:" but be liberal.
        let stripped = n.strip_prefix("special:").unwrap_or(n);
        stripped == special_name
    })
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

    fn check_dispatchers(code: &str, assertions: &str) {
        // Dispatcher builders return opaque objects, not callable Lua functions.
        let stub = r#"
            local calls = {}
            local function dispatcher(kind, args)
                return {kind = kind, args = args}
            end
            hl = {
                dispatch = function(d) table.insert(calls, d) end,
                dsp = {
                    workspace = {toggle_special = function(name)
                        return dispatcher('toggle', name)
                    end},
                    focus = function(args) return dispatcher('focus', args) end,
                    window = {move = function(args) return dispatcher('move', args) end},
                },
            }
        "#;
        let output = Command::new("lua")
            .args(["-e", &format!("{stub}\n{code}\n{assertions}")])
            .output()
            .expect("Lua is required to check dispatcher IPC");
        assert!(output.status.success(), "{}", String::from_utf8_lossy(&output.stderr));
    }

    #[test]
    fn toggle_dispatches_workspace_object() {
        check_dispatchers(&toggle_special_code("lazygit"), r#"
            assert(#calls == 1)
            assert(calls[1].kind == 'toggle' and calls[1].args == 'lazygit')
        "#);
    }

    #[test]
    fn focus_dispatches_window_object() {
        check_dispatchers(&focus_window_code("0x123"), r#"
            assert(#calls == 1)
            assert(calls[1].kind == 'focus' and calls[1].args.window == 'address:0x123')
        "#);
    }

    #[test]
    fn show_and_focus_dispatches_in_order() {
        check_dispatchers(&show_and_focus_code("lazygit", "0x123"), r#"
            assert(#calls == 2)
            assert(calls[1].kind == 'toggle' and calls[1].args == 'lazygit')
            assert(calls[2].kind == 'focus' and calls[2].args.window == 'address:0x123')
        "#);
    }

    #[test]
    fn eject_dispatches_focus_detach_and_silent_move_in_order() {
        check_dispatchers(&eject_to_workspace_code(3, "0x123"), r#"
            assert(#calls == 3)
            assert(calls[1].kind == 'focus' and calls[1].args.window == 'address:0x123')
            assert(calls[2].kind == 'move' and calls[2].args.out_of_group == true)
            assert(calls[3].kind == 'move' and calls[3].args.workspace == 3)
            assert(calls[3].args.follow == false and calls[3].args.window == 'address:0x123')
        "#);
    }

    #[test]
    fn lua_string_round_trips_special_characters() {
        let value = "\n\r\t\0\u{7f}123\\\"é]]]=]; error('injected')";
        let output = Command::new("lua")
            .args(["-e", &format!("io.write({})", lua_string(value))])
            .output()
            .expect("Lua is required to check IPC string escaping");
        assert!(output.status.success(), "{:?}", output.stderr);
        assert_eq!(output.stdout, value.as_bytes());
    }

    #[test]
    fn hyprctl_error_includes_stdout_when_stderr_is_empty() {
        use std::os::unix::process::ExitStatusExt;
        let output = Output {
            status: std::process::ExitStatus::from_raw(7 << 8),
            stdout: b"Lua syntax error\n".to_vec(),
            stderr: Vec::new(),
        };
        let error = hyprctl_error(&output);
        assert!(error.contains("7"));
        assert!(error.contains("Lua syntax error"));
    }

    fn make_monitor(focused: bool, special_name: &str) -> Monitor {
        make_monitor_full(focused, special_name, 1, "1")
    }

    fn make_monitor_full(
        focused: bool,
        special_name: &str,
        active_id: i64,
        active_name: &str,
    ) -> Monitor {
        Monitor {
            focused,
            special_workspace: SpecialWorkspace {
                name: special_name.to_string(),
            },
            active_workspace: ActiveWorkspace {
                id: active_id,
                name: active_name.to_string(),
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

    #[test]
    fn find_monitor_with_special_matches_stripped_prefix() {
        let monitors = vec![
            make_monitor_full(false, "", 1, "1"),
            make_monitor_full(true, "special:ai", 2, "2"),
        ];
        let m = find_monitor_with_special(&monitors, "ai").expect("should find");
        assert_eq!(m.active_workspace.id, 2);
    }

    #[test]
    fn find_monitor_with_special_matches_bare_name() {
        // Liberal in what we accept: some Hyprland versions may report the
        // name without the "special:" prefix.
        let monitors = vec![make_monitor_full(true, "ai", 3, "3")];
        let m = find_monitor_with_special(&monitors, "ai").expect("should find");
        assert_eq!(m.active_workspace.id, 3);
    }

    #[test]
    fn find_monitor_with_special_returns_none_for_unmatched() {
        let monitors = vec![make_monitor_full(true, "special:clipboard", 1, "1")];
        assert!(find_monitor_with_special(&monitors, "ai").is_none());
    }
}
