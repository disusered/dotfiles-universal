mod config;
mod context;
mod eject;
mod hyprctl;
mod lock;
mod notify;
mod nvim_parent;
mod scratchpads;
mod watch;
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
    /// Ensure a workspace is visible and focused, spawning on miss even
    /// when the workspace's toggle_spawns=false (for IDE/leader triggers)
    Open {
        /// Name of the workspace to open
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
    /// List configured workspaces
    List,
    /// Dismiss all pyprland scratchpads
    DismissScratchpads,
    /// Long-running watcher: auto-eject stray windows that land on
    /// hyprspace-managed special workspaces with a non-matching class.
    Watch,
    /// Eject the focused window from its special workspace to the
    /// monitor's regular active workspace.
    Eject,
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
        Command::Open { workspace } => {
            let config = config::Config::load().unwrap_or_else(|e| {
                eprintln!("hyprspace: {}", e);
                std::process::exit(1);
            });
            if let Err(e) = workspace::open(&workspace, &config) {
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
        Command::List => {
            let config = config::Config::load().unwrap_or_else(|e| {
                eprintln!("hyprspace: {}", e);
                std::process::exit(1);
            });
            let mut names: Vec<&String> = config.workspaces.keys().collect();
            names.sort();
            for name in names {
                println!("{}", name);
            }
        }
        Command::DismissScratchpads => {
            let config = config::Config::load().unwrap_or_else(|e| {
                eprintln!("hyprspace: {}", e);
                std::process::exit(1);
            });
            scratchpads::dismiss_all(&config.scratchpads.names);
        }
        Command::Watch => {
            let config = config::Config::load().unwrap_or_else(|e| {
                eprintln!("hyprspace: {}", e);
                std::process::exit(1);
            });
            if let Err(e) = watch::run(&config) {
                eprintln!("hyprspace watch: {}", e);
                std::process::exit(1);
            }
        }
        Command::Eject => {
            let config = config::Config::load().unwrap_or_else(|e| {
                eprintln!("hyprspace: {}", e);
                std::process::exit(1);
            });
            if let Err(e) = eject::run(&config) {
                notify::notify(notify::Urgency::Critical, "hyprspace", &e);
                std::process::exit(1);
            }
        }
    }
}
