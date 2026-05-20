use std::process::Command;

use serde::Deserialize;

const FAKE_TARGET_PREFIX: &str = "cfg-hypr-";
const REAL_TMUX: &str = "/usr/bin/tmux";

#[derive(Debug, Deserialize)]
struct HyprClient {
    address: String,
    #[serde(default)]
    pid: u32,
    #[serde(default)]
    class: String,
    #[serde(default, rename = "initialClass")]
    initial_class: String,
    #[serde(default, rename = "initialTitle")]
    initial_title: String,
}

#[derive(Debug, Deserialize)]
struct KittyOsWindow {
    #[serde(default)]
    tabs: Vec<KittyTab>,
}

#[derive(Debug, Deserialize)]
struct KittyTab {
    #[serde(default)]
    windows: Vec<KittyWindow>,
}

#[derive(Debug, Deserialize)]
struct KittyWindow {
    id: u64,
    #[serde(default)]
    pid: u32,
}

#[derive(Debug)]
struct FakeTarget {
    address: String,
    kitty: Option<KittyTarget>,
}

#[derive(Debug)]
struct KittyTarget {
    kitty_pid: u32,
    window_id: u64,
}

pub fn run(args: &[String]) -> Result<(), String> {
    match args.first().map(String::as_str) {
        Some("list-panes") => list_panes(),
        Some("switch-client") | Some("select-window") if is_fake_target_call(args) => Ok(()),
        Some("select-pane") => select_pane(args),
        _ => delegate_to_real_tmux(args),
    }
}

fn list_panes() -> Result<(), String> {
    for line in fake_panes_from_clients_json(&clients_json()?)? {
        println!("{}", line);
    }
    Ok(())
}

fn select_pane(args: &[String]) -> Result<(), String> {
    let target = match target_arg(args) {
        Some(target) => target,
        None => return delegate_to_real_tmux(args),
    };
    let Some(address) = decode_fake_target(target) else {
        return delegate_to_real_tmux(args);
    };
    dispatch_focus_target(&address)
}

fn clients_json() -> Result<String, String> {
    if let Ok(json) = std::env::var("CFG_TMUX_BRIDGE_CLIENTS_JSON") {
        return Ok(json);
    }

    let output = Command::new("hyprctl")
        .args(["clients", "-j"])
        .output()
        .map_err(|e| format!("failed to run hyprctl clients -j: {}", e))?;
    if !output.status.success() {
        return Err(format!(
            "hyprctl clients -j failed with status {}: stderr={} stdout={}",
            output.status,
            String::from_utf8_lossy(&output.stderr).trim(),
            String::from_utf8_lossy(&output.stdout).trim()
        ));
    }
    String::from_utf8(output.stdout).map_err(|e| format!("invalid hyprctl UTF-8: {}", e))
}

fn fake_panes_from_clients_json(json: &str) -> Result<Vec<String>, String> {
    let clients = serde_json::from_str::<Vec<HyprClient>>(json)
        .map_err(|e| format!("failed to parse hyprctl clients JSON: {}", e))?;
    let mut lines = Vec::new();
    for client in clients
        .into_iter()
        .filter(|client| client.pid > 0 && !client.address.trim().is_empty())
    {
        if is_kitty_client(&client) {
            if let Ok(kitty_lines) = fake_panes_from_kitty_client(&client) {
                if !kitty_lines.is_empty() {
                    lines.extend(kitty_lines);
                    continue;
                }
            }
        }
        lines.push(format!(
            "{} {}",
            client.pid,
            encode_fake_target(&client.address)
        ));
    }
    lines.sort();
    Ok(lines)
}

fn encode_fake_target(address: &str) -> String {
    format!("{}{}:1.1", FAKE_TARGET_PREFIX, address)
}

fn encode_kitty_fake_target(address: &str, kitty_pid: u32, window_id: u64) -> String {
    format!(
        "{}{}-kitty-{}-window-{}:1.1",
        FAKE_TARGET_PREFIX, address, kitty_pid, window_id
    )
}

fn decode_fake_target(target: &str) -> Option<FakeTarget> {
    let session = target.split(':').next()?;
    let encoded = session.strip_prefix(FAKE_TARGET_PREFIX)?;
    let Some((address, kitty)) = encoded.split_once("-kitty-") else {
        return Some(FakeTarget {
            address: encoded.to_owned(),
            kitty: None,
        });
    };
    let (kitty_pid, window_id) = kitty.split_once("-window-")?;
    Some(FakeTarget {
        address: address.to_owned(),
        kitty: Some(KittyTarget {
            kitty_pid: kitty_pid.parse().ok()?,
            window_id: window_id.parse().ok()?,
        }),
    })
}

fn is_fake_target_call(args: &[String]) -> bool {
    target_arg(args).and_then(decode_fake_target).is_some()
}

fn target_arg(args: &[String]) -> Option<&str> {
    for pair in args.windows(2) {
        if pair[0] == "-t" {
            return Some(&pair[1]);
        }
    }
    args.iter()
        .find_map(|arg| arg.strip_prefix("-t=").filter(|target| !target.is_empty()))
}

fn is_kitty_client(client: &HyprClient) -> bool {
    client.class == "kitty" || client.initial_class == "kitty" || client.initial_title == "kitty"
}

fn fake_panes_from_kitty_client(client: &HyprClient) -> Result<Vec<String>, String> {
    let os_windows = serde_json::from_str::<Vec<KittyOsWindow>>(&kitty_json(client.pid)?)
        .map_err(|e| format!("failed to parse kitty window JSON: {}", e))?;
    let mut lines = Vec::new();
    for window in os_windows
        .into_iter()
        .flat_map(|os_window| os_window.tabs)
        .flat_map(|tab| tab.windows)
        .filter(|window| window.pid > 0)
    {
        lines.push(format!(
            "{} {}",
            window.pid,
            encode_kitty_fake_target(&client.address, client.pid, window.id)
        ));
    }
    Ok(lines)
}

fn kitty_json(kitty_pid: u32) -> Result<String, String> {
    let pid_var = format!("CFG_TMUX_BRIDGE_KITTY_JSON_{}", kitty_pid);
    if let Ok(json) = std::env::var(pid_var) {
        return Ok(json);
    }
    if let Ok(json) = std::env::var("CFG_TMUX_BRIDGE_KITTY_JSON") {
        return Ok(json);
    }

    let socket = format!("unix:@mykitty-{}", kitty_pid);
    let output = Command::new("kitty")
        .args(["@", "--to", &socket, "ls"])
        .output()
        .map_err(|e| format!("failed to run kitty @ --to {} ls: {}", socket, e))?;
    if !output.status.success() {
        return Err(format!(
            "kitty @ --to {} ls failed with status {}: stderr={} stdout={}",
            socket,
            output.status,
            String::from_utf8_lossy(&output.stderr).trim(),
            String::from_utf8_lossy(&output.stdout).trim()
        ));
    }
    String::from_utf8(output.stdout).map_err(|e| format!("invalid kitty UTF-8: {}", e))
}

fn dispatch_focus_target(target: &FakeTarget) -> Result<(), String> {
    dispatch_focus_window(&target.address)?;
    if let Some(kitty) = &target.kitty {
        dispatch_focus_kitty_window(kitty)?;
    }
    Ok(())
}

fn dispatch_focus_window(address: &str) -> Result<(), String> {
    let command = format!("hyprctl dispatch focuswindow address:{}", address);
    if std::env::var_os("CFG_TMUX_BRIDGE_DRY_RUN").is_some() {
        println!("{}", command);
        return Ok(());
    }

    let target = format!("address:{}", address);
    let status = Command::new("hyprctl")
        .args(["dispatch", "focuswindow", &target])
        .status()
        .map_err(|e| format!("failed to run {}: {}", command, e))?;
    if status.success() {
        Ok(())
    } else {
        Err(format!("{} failed", command))
    }
}

fn dispatch_focus_kitty_window(target: &KittyTarget) -> Result<(), String> {
    let socket = format!("unix:@mykitty-{}", target.kitty_pid);
    let match_arg = format!("id:{}", target.window_id);
    let command = format!("kitty @ --to {} focus-window --match {}", socket, match_arg);
    if std::env::var_os("CFG_TMUX_BRIDGE_DRY_RUN").is_some() {
        println!("{}", command);
        return Ok(());
    }

    let status = Command::new("kitty")
        .args(["@", "--to", &socket, "focus-window", "--match", &match_arg])
        .status()
        .map_err(|e| format!("failed to run {}: {}", command, e))?;
    if status.success() {
        Ok(())
    } else {
        Err(format!("{} failed", command))
    }
}

fn delegate_to_real_tmux(args: &[String]) -> Result<(), String> {
    let status = Command::new(REAL_TMUX)
        .args(args)
        .status()
        .map_err(|e| format!("failed to run {}: {}", REAL_TMUX, e))?;
    match status.code() {
        Some(code) => std::process::exit(code),
        None => Err(format!("{} terminated by signal", REAL_TMUX)),
    }
}
