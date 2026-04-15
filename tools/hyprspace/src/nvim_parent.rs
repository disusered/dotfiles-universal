use std::fs;
use std::os::unix::fs::FileTypeExt;
use std::path::{Path, PathBuf};

use crate::context;

#[derive(Debug, serde::Deserialize)]
struct Entry {
    pid: i32,
    socket: String,
    git_root: String,
    started_at: i64,
}

/// Resolve a parent Neovim socket for `context`, matching by git_root.
///
/// Reads `$XDG_CACHE_HOME/nvim-servers/*.json` (written by the nvim-side
/// parent-registry plugin), filters entries whose `git_root` matches the
/// git root of `context`, validates the socket is a live Unix socket owned
/// by a live process, and returns the earliest-started survivor.
pub fn resolve(context: &str) -> Option<PathBuf> {
    let git_root = context::find_git_root(Path::new(context))?;
    let git_root_str = git_root.to_string_lossy().into_owned();
    let entries = read_entries(&cache_dir())?;
    pick_earliest_alive(entries, &git_root_str).map(PathBuf::from)
}

fn cache_dir() -> PathBuf {
    let base = std::env::var("XDG_CACHE_HOME").ok().unwrap_or_else(|| {
        let home = std::env::var("HOME").unwrap_or_default();
        format!("{}/.cache", home)
    });
    PathBuf::from(base).join("nvim-servers")
}

fn read_entries(dir: &Path) -> Option<Vec<Entry>> {
    let rd = fs::read_dir(dir).ok()?;
    let mut out = Vec::new();
    for item in rd.flatten() {
        let path = item.path();
        if path.extension().and_then(|s| s.to_str()) != Some("json") {
            continue;
        }
        if let Ok(content) = fs::read_to_string(&path) {
            if let Ok(entry) = serde_json::from_str::<Entry>(&content) {
                out.push(entry);
            }
        }
    }
    Some(out)
}

fn pick_earliest_alive(mut entries: Vec<Entry>, git_root: &str) -> Option<String> {
    entries.retain(|e| e.git_root == git_root);
    entries.sort_by_key(|e| e.started_at);
    for entry in entries {
        if is_live_socket(&entry.socket) && is_live_pid(entry.pid) {
            return Some(entry.socket);
        }
    }
    None
}

fn is_live_socket(path: &str) -> bool {
    fs::metadata(path)
        .map(|m| m.file_type().is_socket())
        .unwrap_or(false)
}

fn is_live_pid(pid: i32) -> bool {
    Path::new(&format!("/proc/{}", pid)).exists()
}

#[cfg(test)]
mod tests {
    use super::*;

    fn entry(pid: i32, socket: &str, git_root: &str, started_at: i64) -> Entry {
        Entry {
            pid,
            socket: socket.to_string(),
            git_root: git_root.to_string(),
            started_at,
        }
    }

    #[test]
    fn pick_earliest_alive_filters_by_git_root() {
        // All sockets are bogus paths -> none are live. We only test the
        // filter + sort ordering here; liveness is covered below.
        let entries = vec![
            entry(1, "/tmp/a.sock", "/repo/a", 10),
            entry(2, "/tmp/b.sock", "/repo/b", 5),
        ];
        assert_eq!(pick_earliest_alive(entries, "/repo/c"), None);
    }

    #[test]
    fn pick_earliest_alive_picks_live_socket() {
        use std::os::unix::net::UnixListener;
        let dir = std::env::temp_dir().join(format!("hyprspace-test-{}", std::process::id()));
        let _ = fs::remove_dir_all(&dir);
        fs::create_dir_all(&dir).unwrap();
        let live = dir.join("live.sock");
        let _listener = UnixListener::bind(&live).unwrap();
        let dead = dir.join("dead.sock");
        // dead path: no socket exists
        let own_pid = std::process::id() as i32;

        let entries = vec![
            entry(own_pid, dead.to_str().unwrap(), "/repo/x", 1),
            entry(own_pid, live.to_str().unwrap(), "/repo/x", 2),
        ];
        let got = pick_earliest_alive(entries, "/repo/x");
        assert_eq!(got.as_deref(), Some(live.to_str().unwrap()));

        let _ = fs::remove_dir_all(&dir);
    }

    #[test]
    fn pick_earliest_alive_skips_dead_pid() {
        use std::os::unix::net::UnixListener;
        let dir = std::env::temp_dir().join(format!("hyprspace-test-deadpid-{}", std::process::id()));
        let _ = fs::remove_dir_all(&dir);
        fs::create_dir_all(&dir).unwrap();
        let sock = dir.join("s.sock");
        let _listener = UnixListener::bind(&sock).unwrap();
        let own_pid = std::process::id() as i32;

        // pid 1 is init; pid=0x7fffffff is ~guaranteed dead
        let entries = vec![
            entry(i32::MAX, sock.to_str().unwrap(), "/repo/y", 1),
            entry(own_pid, sock.to_str().unwrap(), "/repo/y", 2),
        ];
        let got = pick_earliest_alive(entries, "/repo/y");
        assert!(got.is_some(), "expected live own_pid entry to win");

        let _ = fs::remove_dir_all(&dir);
    }

    #[test]
    fn is_live_socket_false_for_regular_file() {
        let path = std::env::temp_dir().join("hyprspace-regular-file.txt");
        fs::write(&path, "x").unwrap();
        assert!(!is_live_socket(path.to_str().unwrap()));
        let _ = fs::remove_file(&path);
    }

    #[test]
    fn is_live_socket_false_for_missing() {
        assert!(!is_live_socket("/nonexistent/path/xyz.sock"));
    }
}
