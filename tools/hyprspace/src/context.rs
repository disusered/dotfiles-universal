use crate::hyprctl::ActiveWindow;
use std::path::{Path, PathBuf};
use std::process::Command;

pub fn detect_cwd(window: &ActiveWindow) -> Option<PathBuf> {
    if window.class == "kitty" {
        query_kitty_socket(window.pid)
    } else if window.class.ends_with("_modal") {
        parse_modal_title(&window.initial_title)
    } else if window.class == "org.kde.dolphin" {
        parse_dolphin_title(&window.initial_title)
    } else {
        None
    }
}

pub fn find_git_root(cwd: &Path) -> Option<PathBuf> {
    let output = Command::new("git")
        .args(["-C", &cwd.to_string_lossy(), "rev-parse", "--show-toplevel"])
        .output()
        .ok()?;
    if !output.status.success() {
        return None;
    }
    let stdout = String::from_utf8(output.stdout).ok()?;
    Some(PathBuf::from(stdout.trim()))
}

fn query_kitty_socket(pid: i64) -> Option<PathBuf> {
    let pid_socket = format!("unix:@mykitty-{}", pid);
    let output = Command::new("kitty")
        .args(["@", "--to", &pid_socket, "ls"])
        .output()
        .ok();

    let output = match output {
        Some(o) if o.status.success() => o,
        _ => {
            // Fallback to shared socket
            let fallback = Command::new("kitty")
                .args(["@", "--to", "unix:@mykitty", "ls"])
                .output()
                .ok()?;
            if !fallback.status.success() {
                return None;
            }
            fallback
        }
    };

    let json: serde_json::Value =
        serde_json::from_slice(&output.stdout).ok()?;

    let tabs = json.as_array()?;
    for os_window in tabs {
        for tab in os_window.get("tabs")?.as_array()? {
            for window in tab.get("windows")?.as_array()? {
                if window.get("is_focused")?.as_bool()? {
                    let cwd = window.get("cwd")?.as_str()?;
                    return Some(PathBuf::from(cwd));
                }
            }
        }
    }

    None
}

fn parse_modal_title(title: &str) -> Option<PathBuf> {
    let (_, path_str) = title.split_once(": ")?;
    let path = Path::new(path_str);
    if path.is_dir() {
        Some(path.to_path_buf())
    } else {
        None
    }
}

fn parse_dolphin_title(title: &str) -> Option<PathBuf> {
    let (path_str, _) = title.split_once(" \u{2014} ")?;
    let path = Path::new(path_str);
    if path.is_dir() {
        Some(path.to_path_buf())
    } else {
        None
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::env;

    #[test]
    fn parse_modal_title_valid() {
        let dir = env::temp_dir();
        let title = format!("app: {}", dir.display());
        let result = parse_modal_title(&title);
        assert_eq!(result, Some(dir));
    }

    #[test]
    fn parse_modal_title_invalid_path() {
        let result = parse_modal_title("app: /nonexistent/path/xyz");
        assert!(result.is_none());
    }

    #[test]
    fn parse_modal_title_no_separator() {
        let result = parse_modal_title("no-separator-here");
        assert!(result.is_none());
    }

    #[test]
    fn parse_dolphin_title_valid() {
        let dir = env::temp_dir();
        let title = format!("{} \u{2014} Dolphin", dir.display());
        let result = parse_dolphin_title(&title);
        assert_eq!(result, Some(dir));
    }

    #[test]
    fn parse_dolphin_title_no_dash_suffix() {
        let dir = env::temp_dir();
        let title = format!("{}", dir.display());
        let result = parse_dolphin_title(&title);
        assert!(result.is_none());
    }

    #[test]
    fn parse_dolphin_title_invalid_path() {
        let result = parse_dolphin_title("/nonexistent/xyz \u{2014} Dolphin");
        assert!(result.is_none());
    }
}
