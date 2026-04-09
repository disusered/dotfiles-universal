use std::process::Command;

// Integration only — tested manually.

/// Dismiss all pyprland scratchpads by name.
pub fn dismiss_all(names: &[String]) {
    for name in names {
        let _ = Command::new("pypr-client")
            .arg("hide")
            .arg(name)
            .stdout(std::process::Stdio::null())
            .stderr(std::process::Stdio::null())
            .output();
    }
}
