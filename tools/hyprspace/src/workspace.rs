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
        ContextType::None => toggle_global(ws, workspace_name, &clients),
        ContextType::Cwd => {
            let active_window = get_active_window()?;
            toggle_with_cwd(ws, workspace_name, &clients, &active_window)
        }
        ContextType::GitRoot => {
            let active_window = get_active_window()?;
            toggle_with_git_root(ws, workspace_name, &clients, &active_window)
        }
    }
}

fn toggle_global(
    ws: &WorkspaceConfig,
    workspace_name: &str,
    clients: &[Client],
) -> Result<(), String> {
    if let Some(client) = find_any_window(clients, ws) {
        focus_and_show(workspace_name, &client.address)
    } else {
        spawn_and_wait(ws, workspace_name, None)
    }
}

fn toggle_with_cwd(
    ws: &WorkspaceConfig,
    workspace_name: &str,
    clients: &[Client],
    active_window: &ActiveWindow,
) -> Result<(), String> {
    if let Some(cwd) = context::detect_cwd(active_window) {
        let cwd_str = cwd.to_string_lossy();
        let title = build_context_title(ws.title_prefix.as_deref(), &cwd_str);

        if let Some(client) =
            find_window_by_class_and_title(clients, &ws.window_class, &title)
        {
            return focus_and_show(workspace_name, &client.address);
        }

        // Context-aware: no exact match means a new context — always spawn.
        // Do NOT fall back to find_any_window here: reusing an arbitrary
        // window from a different context is the "wrong/stale window" bug.
        spawn_and_wait(ws, workspace_name, Some(&cwd_str))
    } else {
        // No CWD context: show any existing window, never spawn
        if let Some(client) = find_any_window(clients, ws) {
            focus_and_show(workspace_name, &client.address)?;
        }
        Ok(())
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

    // Show workspace before spawning
    dispatch_toggle_special(workspace_name)?;

    // Spawn detached process
    if cmd.is_empty() {
        return Err("Empty spawn command".to_string());
    }
    ProcessCommand::new(&cmd[0])
        .args(&cmd[1..])
        .stdin(std::process::Stdio::null())
        .stdout(std::process::Stdio::null())
        .stderr(std::process::Stdio::null())
        .spawn()
        .map_err(|e| format!("Failed to spawn '{}': {}", cmd[0], e))?;

    // Poll for new window
    let deadline = Instant::now() + Duration::from_secs(2);
    while Instant::now() < deadline {
        thread::sleep(Duration::from_millis(100));
        if let Ok(clients) = get_clients() {
            let found = if !title.is_empty() {
                find_window_by_class_and_title(&clients, &ws.window_class, &title)
            } else {
                hyprctl::find_windows_by_class(&clients, &ws.window_class)
                    .into_iter()
                    .next()
            };
            if let Some(client) = found {
                let _ = dispatch_focus_window(&client.address);
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
    fn build_context_title_empty_prefix() {
        let title = build_context_title(Some(""), "/home/user/project");
        assert_eq!(title, "/home/user/project");
    }
}
