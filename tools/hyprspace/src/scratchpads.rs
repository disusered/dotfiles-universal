use std::process::Command;

// Integration only — tested manually.

/// Dismiss all pyprland scratchpads by name.
pub fn dismiss_all(names: &[String]) {
    for name in names {
        let _ = Command::new("pypr").arg("hide").arg(name).output();
    }
}
