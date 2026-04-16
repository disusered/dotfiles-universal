use std::collections::HashSet;
use std::process::Command as ProcessCommand;
use std::thread;
use std::time::{Duration, Instant};

use crate::config::{Config, ContextType, WorkspaceConfig};
use crate::context;
use crate::hyprctl::{
    self, ActiveWindow, Client, dispatch_focus_window, dispatch_toggle_special,
    find_window_by_class_and_title, get_active_window, get_clients,
    get_focused_special_workspace, get_monitors,
};
use crate::lock::SpawnLock;
use crate::notify;
use crate::nvim_parent;
use crate::scratchpads;

pub fn raw(workspace_name: &str) -> Result<(), String> {
    dispatch_toggle_special(workspace_name)
}

pub fn spawn(workspace_name: &str, config: &Config) -> Result<(), String> {
    let ws = match config.get_workspace(workspace_name) {
        Some(ws) => ws,
        None => {
            notify::notify(
                notify::Urgency::Critical,
                "hyprspace",
                &format!("Unknown workspace: {}", workspace_name),
            );
            return Err(format!("Unknown workspace: {}", workspace_name));
        }
    };

    if !ws.multi_instance {
        notify::notify(
            notify::Urgency::Normal,
            "hyprspace",
            &format!("{} is single-instance", workspace_name),
        );
        return Ok(());
    }

    if ws.dismiss_scratchpads {
        scratchpads::dismiss_all(&config.scratchpads.names);
    }

    let active_window = get_active_window()?;
    match detect_context(ws, &active_window) {
        Some(ctx) => spawn_and_wait(ws, workspace_name, Some(&ctx)),
        None => {
            notify::notify(
                notify::Urgency::Normal,
                "hyprspace",
                &format!("No context for spawn in {}", workspace_name),
            );
            Ok(())
        }
    }
}

pub fn toggle(workspace_name: &str, config: &Config) -> Result<(), String> {
    dispatch_toggle(workspace_name, config, false)
}

/// `open` behaves like `toggle` but forces spawn-on-miss regardless of
/// `toggle_spawns`. Use for "ensure this workspace is usable" triggers
/// (e.g. <leader>ac from nvim) while keeping `toggle` strictly
/// focus-only when the workspace opts out via `toggle_spawns=false`.
pub fn open(workspace_name: &str, config: &Config) -> Result<(), String> {
    dispatch_toggle(workspace_name, config, true)
}

fn dispatch_toggle(
    workspace_name: &str,
    config: &Config,
    force_spawn_on_miss: bool,
) -> Result<(), String> {
    let ws = match config.get_workspace(workspace_name) {
        Some(ws) => ws,
        None => {
            notify::notify(
                notify::Urgency::Critical,
                "hyprspace",
                &format!("Unknown workspace: {}", workspace_name),
            );
            return Err(format!("Unknown workspace: {}", workspace_name));
        }
    };

    let spawn_on_miss = ws.toggle_spawns || force_spawn_on_miss;

    let monitors = get_monitors()?;
    let focused_special = get_focused_special_workspace(&monitors);

    // If our workspace is currently visible, hide it
    if focused_special.as_deref() == Some(workspace_name) {
        dispatch_toggle_special(workspace_name)?;
        return Ok(());
    }

    // If another special workspace is visible, show existing window if any, don't interfere
    if focused_special.is_some() {
        let clients = get_clients()?;
        if let Some(client) = find_any_window(&clients, ws) {
            focus_and_show(workspace_name, &client.address)?;
        }
        return Ok(());
    }

    // Dismiss scratchpads before showing our workspace
    if ws.dismiss_scratchpads {
        scratchpads::dismiss_all(&config.scratchpads.names);
    }

    let clients = get_clients()?;

    match ws.context_type {
        ContextType::None => toggle_global(ws, workspace_name, &clients, spawn_on_miss),
        ContextType::Cwd => {
            let active_window = get_active_window()?;
            toggle_with_cwd(ws, workspace_name, &clients, &active_window, spawn_on_miss)
        }
        ContextType::GitRoot => {
            let active_window = get_active_window()?;
            toggle_with_git_root(ws, workspace_name, &clients, &active_window)
        }
    }
}

#[derive(Debug, PartialEq, Eq)]
enum MissAction {
    Spawn,
    FocusAny,
    Noop,
}

// Decide what to do when `toggle` has no exact context match.
// `toggle_spawns=false` opts out of spawning entirely: the binding becomes
// a pure visibility/focus toggle, delegating creation to `spawn`.
fn miss_action(toggle_spawns: bool, has_cwd: bool, has_any_existing: bool) -> MissAction {
    match (toggle_spawns, has_cwd, has_any_existing) {
        (true, true, _) => MissAction::Spawn,
        (true, false, true) => MissAction::FocusAny,
        (true, false, false) => MissAction::Noop,
        (false, _, true) => MissAction::FocusAny,
        (false, _, false) => MissAction::Noop,
    }
}

fn toggle_global(
    ws: &WorkspaceConfig,
    workspace_name: &str,
    clients: &[Client],
    spawn_on_miss: bool,
) -> Result<(), String> {
    if let Some(client) = find_any_window(clients, ws) {
        focus_and_show(workspace_name, &client.address)
    } else if spawn_on_miss {
        spawn_and_wait(ws, workspace_name, None)
    } else {
        Ok(())
    }
}

fn toggle_with_cwd(
    ws: &WorkspaceConfig,
    workspace_name: &str,
    clients: &[Client],
    active_window: &ActiveWindow,
    spawn_on_miss: bool,
) -> Result<(), String> {
    let cwd = context::detect_cwd(active_window);

    if let Some(ref cwd_path) = cwd {
        let cwd_str = cwd_path.to_string_lossy();
        let title = build_context_title(ws.title_prefix.as_deref(), &cwd_str);

        if let Some(client) =
            find_window_by_class_and_title(clients, &ws.window_class, &title)
        {
            return focus_and_show(workspace_name, &client.address);
        }

        if spawn_on_miss {
            // Context-aware: no exact match means a new context — spawn.
            return spawn_and_wait(ws, workspace_name, Some(&cwd_str));
        }
    }

    // Miss with spawn_on_miss=false, or no CWD context: fall through to
    // focusing any existing window. Never spawn here.
    let has_any = find_any_window(clients, ws).is_some();
    match miss_action(spawn_on_miss, cwd.is_some(), has_any) {
        MissAction::FocusAny => {
            if let Some(client) = find_any_window(clients, ws) {
                focus_and_show(workspace_name, &client.address)?;
            }
            Ok(())
        }
        MissAction::Noop => Ok(()),
        MissAction::Spawn => unreachable!("spawn handled above when cwd is Some"),
    }
}

fn toggle_with_git_root(
    ws: &WorkspaceConfig,
    workspace_name: &str,
    clients: &[Client],
    active_window: &ActiveWindow,
) -> Result<(), String> {
    let cwd = match context::detect_cwd(active_window) {
        Some(cwd) => cwd,
        None => return Ok(()),
    };

    let git_root = match context::find_git_root(&cwd) {
        Some(root) => root,
        None => {
            notify::notify(notify::Urgency::Normal, "hyprspace", "Not a git repo");
            return Ok(());
        }
    };

    let root_str = git_root.to_string_lossy();
    let title = build_context_title(ws.title_prefix.as_deref(), &root_str);

    if let Some(client) =
        find_window_by_class_and_title(clients, &ws.window_class, &title)
    {
        return focus_and_show(workspace_name, &client.address);
    }

    // Context-aware: no exact match means a new git repo — always spawn.
    // Do NOT fall back to find_any_window: that reused a lazygit from an
    // unrelated repo (the "wrong/stale window" bug).
    spawn_and_wait(ws, workspace_name, Some(&root_str))
}

fn detect_context(ws: &WorkspaceConfig, active_window: &ActiveWindow) -> Option<String> {
    match ws.context_type {
        ContextType::None => Some(String::new()),
        ContextType::Cwd => {
            context::detect_cwd(active_window).map(|p| p.to_string_lossy().into_owned())
        }
        ContextType::GitRoot => {
            let cwd = context::detect_cwd(active_window)?;
            context::find_git_root(&cwd).map(|p| p.to_string_lossy().into_owned())
        }
    }
}

fn focus_and_show(workspace_name: &str, address: &str) -> Result<(), String> {
    dispatch_toggle_special(workspace_name)?;
    dispatch_focus_window(address)?;
    Ok(())
}

fn spawn_and_wait(
    ws: &WorkspaceConfig,
    workspace_name: &str,
    context: Option<&str>,
) -> Result<(), String> {
    let context_id = context.unwrap_or(workspace_name);
    let _lock = match SpawnLock::try_acquire(context_id) {
        Some(lock) => lock,
        None => return Ok(()), // Already spawning
    };

    let title = context
        .map(|ctx| build_context_title(ws.title_prefix.as_deref(), ctx))
        .unwrap_or_default();

    let cmd = interpolate_command(&ws.spawn_command, &title, context.unwrap_or(""));

    // Snapshot existing windows for this workspace before spawning so the
    // post-spawn poll can pick the address that's NEW. Multi-instance
    // workspaces (ai) reuse class+title across tabs of the same context,
    // so `find`-by-class+title would otherwise return the pre-existing
    // window and focus would land on the wrong tab.
    let pre_spawn_addrs: HashSet<String> = get_clients()
        .map(|clients| snapshot_matching_addrs(&clients, ws))
        .unwrap_or_default();

    // Show workspace before spawning
    dispatch_toggle_special(workspace_name)?;

    // Spawn detached process
    if cmd.is_empty() {
        return Err("Empty spawn command".to_string());
    }
    let mut process = ProcessCommand::new(&cmd[0]);
    process
        .args(&cmd[1..])
        .stdin(std::process::Stdio::null())
        .stdout(std::process::Stdio::null())
        .stderr(std::process::Stdio::null());
    apply_injected_env(&mut process, ws, context);
    process
        .spawn()
        .map_err(|e| format!("Failed to spawn '{}': {}", cmd[0], e))?;

    // Poll for new window
    let deadline = Instant::now() + Duration::from_secs(2);
    while Instant::now() < deadline {
        thread::sleep(Duration::from_millis(100));
        if let Ok(clients) = get_clients() {
            if let Some(addr) = pick_new_window(&clients, ws, &title, &pre_spawn_addrs) {
                let _ = dispatch_focus_window(&addr);
                return Ok(());
            }
        }
    }

    notify::notify(
        notify::Urgency::Normal,
        "hyprspace",
        &format!("Spawn timeout for {}", workspace_name),
    );
    Ok(())
}

// Pick the first client matching the workspace's class set (primary +
// extras) whose address is not in `pre_spawn`. When `title` is non-empty,
// restrict to clients whose `initial_title` matches exactly. Used by
// `spawn_and_wait` to identify the window we just spawned — matching on
// address excludes pre-existing windows that share the same class+title
// (e.g. a second Claude launched from the same cwd as an existing one).
fn pick_new_window(
    clients: &[Client],
    ws: &WorkspaceConfig,
    title: &str,
    pre_spawn: &HashSet<String>,
) -> Option<String> {
    clients
        .iter()
        .filter(|c| {
            c.class == ws.window_class || ws.extra_classes.iter().any(|e| e == &c.class)
        })
        .filter(|c| title.is_empty() || c.initial_title == title)
        .map(|c| c.address.clone())
        .find(|addr| !pre_spawn.contains(addr))
}

fn snapshot_matching_addrs(clients: &[Client], ws: &WorkspaceConfig) -> HashSet<String> {
    clients
        .iter()
        .filter(|c| {
            c.class == ws.window_class || ws.extra_classes.iter().any(|e| e == &c.class)
        })
        .map(|c| c.address.clone())
        .collect()
}

fn find_any_window<'a>(clients: &'a [Client], ws: &WorkspaceConfig) -> Option<&'a Client> {
    let matches = hyprctl::find_windows_by_class(clients, &ws.window_class);
    if let Some(client) = matches.into_iter().next() {
        return Some(client);
    }
    for extra_class in &ws.extra_classes {
        let matches = hyprctl::find_windows_by_class(clients, extra_class);
        if let Some(client) = matches.into_iter().next() {
            return Some(client);
        }
    }
    None
}

fn build_context_title(title_prefix: Option<&str>, context_path: &str) -> String {
    match title_prefix {
        Some(prefix) => format!("{}{}", prefix, context_path),
        None => context_path.to_string(),
    }
}

fn interpolate_command(command: &[String], title: &str, context: &str) -> Vec<String> {
    command
        .iter()
        .map(|arg| arg.replace("{title}", title).replace("{context}", context))
        .collect()
}

// Inject env vars into the child process per the workspace's config:
//   1. modal_tag       -> HYPRSPACE_MODAL=<tag>
//   2. inject_parent_nvim + context resolvable -> NVIM=<socket>
//   3. pass_env keys present in our env -> forwarded
// Silent no-op when a field is unset or a value can't be resolved; the
// caller decides (via config) which injections the workspace contract
// requires.
fn apply_injected_env(cmd: &mut ProcessCommand, ws: &WorkspaceConfig, context: Option<&str>) {
    if let Some(tag) = ws.modal_tag.as_deref() {
        cmd.env("HYPRSPACE_MODAL", tag);
    }
    if ws.inject_parent_nvim {
        if let Some(ctx) = context {
            if let Some(sock) = nvim_parent::resolve(ctx) {
                cmd.env("NVIM", sock);
            }
        }
    }
    for key in &ws.pass_env {
        if let Ok(val) = std::env::var(key) {
            cmd.env(key, val);
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn interpolate_command_replaces_placeholders() {
        let cmd = vec![
            "app".to_string(),
            "--title={title}".to_string(),
            "--dir={context}".to_string(),
        ];
        let result = interpolate_command(&cmd, "claude: /home/user", "/home/user");
        assert_eq!(
            result,
            vec!["app", "--title=claude: /home/user", "--dir=/home/user"]
        );
    }

    #[test]
    fn interpolate_command_no_placeholders() {
        let cmd = vec!["app".to_string(), "--flag".to_string()];
        let result = interpolate_command(&cmd, "title", "ctx");
        assert_eq!(result, vec!["app", "--flag"]);
    }

    #[test]
    fn interpolate_command_empty() {
        let cmd: Vec<String> = vec![];
        let result = interpolate_command(&cmd, "title", "ctx");
        assert!(result.is_empty());
    }

    #[test]
    fn build_context_title_with_prefix() {
        let title = build_context_title(Some("claude: "), "/home/user/project");
        assert_eq!(title, "claude: /home/user/project");
    }

    #[test]
    fn build_context_title_without_prefix() {
        let title = build_context_title(None, "/home/user/project");
        assert_eq!(title, "/home/user/project");
    }

    #[test]
    fn miss_action_spawns_when_enabled_and_has_cwd() {
        assert_eq!(miss_action(true, true, false), MissAction::Spawn);
        assert_eq!(miss_action(true, true, true), MissAction::Spawn);
    }

    #[test]
    fn miss_action_focuses_any_without_cwd_when_existing() {
        assert_eq!(miss_action(true, false, true), MissAction::FocusAny);
    }

    #[test]
    fn miss_action_noop_without_cwd_and_no_existing() {
        assert_eq!(miss_action(true, false, false), MissAction::Noop);
    }

    #[test]
    fn miss_action_never_spawns_when_disabled() {
        assert_eq!(miss_action(false, true, true), MissAction::FocusAny);
        assert_eq!(miss_action(false, false, true), MissAction::FocusAny);
        assert_eq!(miss_action(false, true, false), MissAction::Noop);
        assert_eq!(miss_action(false, false, false), MissAction::Noop);
    }

    #[test]
    fn build_context_title_empty_prefix() {
        let title = build_context_title(Some(""), "/home/user/project");
        assert_eq!(title, "/home/user/project");
    }

    use crate::hyprctl::WorkspaceRef;

    fn make_client(address: &str, class: &str, title: &str) -> Client {
        Client {
            address: address.to_string(),
            class: class.to_string(),
            initial_title: title.to_string(),
            workspace: WorkspaceRef {
                name: "special:ai".to_string(),
            },
        }
    }

    fn ai_workspace_config() -> WorkspaceConfig {
        WorkspaceConfig {
            window_class: "claude_modal".to_string(),
            window_title: None,
            title_prefix: Some("claude: ".to_string()),
            context_type: ContextType::Cwd,
            multi_instance: true,
            dismiss_scratchpads: false,
            spawn_command: vec!["kitty".to_string()],
            extra_classes: vec!["chrome-gemini.google.com__-Default".to_string()],
            spawn_via_desktop: false,
            toggle_spawns: false,
            modal_tag: Some("ai".to_string()),
            inject_parent_nvim: false,
            pass_env: vec![],
        }
    }

    #[test]
    fn pick_new_window_returns_new_when_title_matches_multiple() {
        let ws = ai_workspace_config();
        let clients = vec![
            make_client("0x1", "claude_modal", "claude: /home/user"),
            make_client("0x2", "claude_modal", "claude: /home/user"),
        ];
        let pre: HashSet<String> = ["0x1".to_string()].into_iter().collect();
        assert_eq!(
            pick_new_window(&clients, &ws, "claude: /home/user", &pre),
            Some("0x2".to_string()),
        );
    }

    #[test]
    fn pick_new_window_returns_none_when_all_pre_existing() {
        let ws = ai_workspace_config();
        let clients = vec![
            make_client("0x1", "claude_modal", "claude: /home/user"),
            make_client("0x2", "claude_modal", "claude: /home/user"),
        ];
        let pre: HashSet<String> =
            ["0x1".to_string(), "0x2".to_string()].into_iter().collect();
        assert_eq!(pick_new_window(&clients, &ws, "claude: /home/user", &pre), None);
    }

    #[test]
    fn pick_new_window_ignores_non_matching_class() {
        let ws = ai_workspace_config();
        let clients = vec![make_client("0x9", "kitty", "claude: /home/user")];
        let pre: HashSet<String> = HashSet::new();
        assert_eq!(pick_new_window(&clients, &ws, "claude: /home/user", &pre), None);
    }

    #[test]
    fn pick_new_window_ignores_non_matching_title() {
        let ws = ai_workspace_config();
        let clients = vec![make_client("0x1", "claude_modal", "claude: /other")];
        let pre: HashSet<String> = HashSet::new();
        assert_eq!(pick_new_window(&clients, &ws, "claude: /home/user", &pre), None);
    }

    #[test]
    fn pick_new_window_matches_extra_classes() {
        let ws = ai_workspace_config();
        let clients = vec![make_client(
            "0x3",
            "chrome-gemini.google.com__-Default",
            "Gemini",
        )];
        let pre: HashSet<String> = HashSet::new();
        assert_eq!(
            pick_new_window(&clients, &ws, "", &pre),
            Some("0x3".to_string()),
        );
    }

    #[test]
    fn pick_new_window_empty_title_matches_any_title() {
        let ws = ai_workspace_config();
        let clients = vec![
            make_client("0x1", "claude_modal", "claude: /a"),
            make_client("0x2", "claude_modal", "claude: /b"),
        ];
        let pre: HashSet<String> = ["0x1".to_string()].into_iter().collect();
        assert_eq!(
            pick_new_window(&clients, &ws, "", &pre),
            Some("0x2".to_string()),
        );
    }

    #[test]
    fn snapshot_matching_addrs_includes_primary_and_extras() {
        let ws = ai_workspace_config();
        let clients = vec![
            make_client("0x1", "claude_modal", "claude: /a"),
            make_client("0x2", "kitty", "terminal"),
            make_client("0x3", "chrome-gemini.google.com__-Default", "Gemini"),
        ];
        let snap = snapshot_matching_addrs(&clients, &ws);
        assert!(snap.contains("0x1"));
        assert!(snap.contains("0x3"));
        assert!(!snap.contains("0x2"));
    }
}
