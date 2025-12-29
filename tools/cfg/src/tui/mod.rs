pub mod clipboard;
pub mod colors;
pub mod fonts;
mod widgets;

use std::io::{self, stdout, Stdout};

use crossterm::{
    event::{DisableMouseCapture, EnableMouseCapture},
    execute,
    terminal::{disable_raw_mode, enable_raw_mode, EnterAlternateScreen, LeaveAlternateScreen},
};
use ratatui::{backend::CrosstermBackend, Terminal};

pub type Tui = Terminal<CrosstermBackend<Stdout>>;

/// Initialize the terminal for TUI mode
pub fn init() -> io::Result<Tui> {
    execute!(stdout(), EnterAlternateScreen, EnableMouseCapture)?;
    enable_raw_mode()?;
    let backend = CrosstermBackend::new(stdout());
    Terminal::new(backend)
}

/// Restore terminal to normal state
pub fn restore() -> io::Result<()> {
    execute!(stdout(), LeaveAlternateScreen, DisableMouseCapture)?;
    disable_raw_mode()
}

/// Check if we're in a proper terminal for TUI
pub fn is_tty() -> bool {
    use std::io::IsTerminal;
    stdout().is_terminal()
        && std::env::var("TERM")
            .map(|t| t != "dumb")
            .unwrap_or(false)
}

