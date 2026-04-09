mod config;
mod context;
mod hyprctl;
mod lock;
mod notify;
mod scratchpads;
mod workspace;

use clap::{Parser, Subcommand};

#[derive(Parser)]
#[command(name = "hyprspace")]
#[command(about = "Hyprland special workspace manager")]
struct Cli {
    #[command(subcommand)]
    command: Command,
}

#[derive(Subcommand)]
enum Command {
    /// Context-aware show/hide of a special workspace
    Toggle {
        /// Name of the workspace to toggle
        workspace: String,
    },
    /// Explicitly spawn a new instance in a special workspace
    Spawn {
        /// Name of the workspace to spawn into
        workspace: String,
    },
    /// Bare togglespecialworkspace (no context logic)
    Raw {
        /// Name of the workspace to toggle
        workspace: String,
    },
    /// Dismiss all pyprland scratchpads
    DismissScratchpads,
}

fn main() {
    let cli = Cli::parse();

    match cli.command {
        Command::Toggle { workspace } => {
            let config = config::Config::load().unwrap_or_else(|e| {
                eprintln!("hyprspace: {}", e);
                std::process::exit(1);
            });
            if let Err(e) = workspace::toggle(&workspace, &config) {
                notify::notify(notify::Urgency::Critical, "hyprspace", &e);
                std::process::exit(1);
            }
        }
        Command::Spawn { workspace } => {
            let config = config::Config::load().unwrap_or_else(|e| {
                eprintln!("hyprspace: {}", e);
                std::process::exit(1);
            });
            if let Err(e) = workspace::spawn(&workspace, &config) {
                notify::notify(notify::Urgency::Critical, "hyprspace", &e);
                std::process::exit(1);
            }
        }
        Command::Raw { workspace } => {
            if let Err(e) = workspace::raw(&workspace) {
                notify::notify(notify::Urgency::Critical, "hyprspace", &e);
                std::process::exit(1);
            }
        }
        Command::DismissScratchpads => {
            let config = config::Config::load().unwrap_or_else(|e| {
                eprintln!("hyprspace: {}", e);
                std::process::exit(1);
            });
            scratchpads::dismiss_all(&config.scratchpads.names);
        }
    }
}
