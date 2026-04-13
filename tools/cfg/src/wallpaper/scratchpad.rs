use std::process::Command;

use crossterm::event::{self, Event, KeyEventKind};
use crossterm::terminal::{disable_raw_mode, enable_raw_mode};

use super::expand_tilde;

/// Preview an image in the current terminal via `kitten icat`, then block
/// until any key is pressed. The wait matters for two callers:
///
/// * TUI (`p` key) spawns a new kitty with `cfg wallpaper --scratchpad <path>`
///   as the child command — kitty closes when the child exits, so the image
///   would vanish instantly without this wait.
/// * Standalone CLI from a kitty shell — same reason, keep the image on
///   screen until the user dismisses it.
pub fn run(path: &str) -> Result<(), String> {
    let expanded = expand_tilde(path);
    let meta = std::fs::metadata(&expanded)
        .map_err(|_| format!("wallpaper path does not exist: {}", expanded))?;
    if !meta.is_file() {
        return Err(format!("wallpaper path is not a file: {}", expanded));
    }

    let status = Command::new("kitten")
        .args(["icat", "--align=center", "--stdin=no", &expanded])
        .status()
        .map_err(|e| {
            if e.kind() == std::io::ErrorKind::NotFound {
                "kitten binary not found — needs kitty terminal".to_string()
            } else {
                format!("failed to run kitten icat: {}", e)
            }
        })?;

    if !status.success() {
        return Err(format!("kitten icat exited with status {}", status));
    }

    wait_for_keypress()
}

fn wait_for_keypress() -> Result<(), String> {
    enable_raw_mode().map_err(|e| format!("failed to enable raw mode: {}", e))?;
    let result = loop {
        match event::read() {
            Ok(Event::Key(k)) if k.kind == KeyEventKind::Press => break Ok(()),
            Ok(_) => continue,
            Err(e) => break Err(format!("event read failed: {}", e)),
        }
    };
    let _ = disable_raw_mode();
    result
}
