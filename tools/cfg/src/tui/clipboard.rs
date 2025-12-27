use std::io::{self, Write};
use std::process::{Command, Stdio};

/// Copy text to clipboard using OSC 52 escape sequence.
/// This works over SSH when the terminal supports it (Kitty, iTerm2, WezTerm, etc.)
pub fn copy_osc52(text: &str) {
    use base64::Engine;
    let encoded = base64::engine::general_purpose::STANDARD.encode(text);
    // OSC 52: \x1b]52;c;<base64>\x07
    // c = clipboard (vs p = primary selection)
    print!("\x1b]52;c;{}\x07", encoded);
    io::stdout().flush().ok();
}

/// Copy text using native clipboard tool (wl-copy, xclip, or pbcopy)
pub fn copy_native(text: &str) -> io::Result<()> {
    let (cmd, args): (&str, &[&str]) = if std::env::var("WAYLAND_DISPLAY").is_ok() {
        ("wl-copy", &[])
    } else if std::env::var("DISPLAY").is_ok() {
        ("xclip", &["-selection", "clipboard"])
    } else if cfg!(target_os = "macos") {
        ("pbcopy", &[])
    } else {
        return Ok(()); // No native clipboard available
    };

    let mut child = Command::new(cmd)
        .args(args)
        .stdin(Stdio::piped())
        .stdout(Stdio::null())
        .stderr(Stdio::null())
        .spawn()?;

    if let Some(stdin) = child.stdin.as_mut() {
        stdin.write_all(text.as_bytes())?;
    }
    child.wait()?;
    Ok(())
}

/// Copy text to clipboard using both OSC 52 and native fallback.
/// OSC 52 is always attempted (works over SSH), native is best-effort.
pub fn copy(text: &str) {
    // OSC 52 first - always works if terminal supports it
    copy_osc52(text);

    // Also try native for local sessions (fire and forget)
    let _ = copy_native(text);
}
