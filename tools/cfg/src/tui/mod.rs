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

/// Result type for TUI operations
pub type TuiResult<T> = Result<T, TuiError>;

#[derive(Debug)]
pub enum TuiError {
    Io(io::Error),
    NotATty,
}

impl From<io::Error> for TuiError {
    fn from(e: io::Error) -> Self {
        TuiError::Io(e)
    }
}

impl std::fmt::Display for TuiError {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        match self {
            TuiError::Io(e) => write!(f, "IO error: {}", e),
            TuiError::NotATty => write!(f, "Interactive mode requires a terminal"),
        }
    }
}
