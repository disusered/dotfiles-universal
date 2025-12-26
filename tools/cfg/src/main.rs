mod color;
mod config;
mod palette;
mod render;
mod templates;

use std::path::PathBuf;

use clap::{Parser, Subcommand};
use color::format_color;
use config::Config;
use palette::Palette;
use render::{build_context, discover_templates, render_to_file};
use templates::{reload_app, rotz_link, TemplatesFile};

#[derive(Parser)]
#[command(name = "cfg")]
#[command(about = "Linux Configuration Manager")]
struct Cli {
    #[command(subcommand)]
    command: Command,
}

#[derive(Subcommand)]
enum Command {
    /// Render templates (template substitution)
    Render {
        /// Template name (without .tera extension)
        name: Option<String>,
        #[arg(long)]
        all: bool,
        #[arg(long)]
        dry_run: bool,
        #[arg(long)]
        force: bool,
    },
    /// Sync: render templates + update symlinks + reload apps
    Sync {
        /// Template name filter (substring match)
        name: Option<String>,
    },
    /// Theme management (Catppuccin colors, reload)
    Theme {
        #[command(subcommand)]
        command: ThemeCommand,
    },
    /// Font configuration
    Font {
        #[command(subcommand)]
        command: FontCommand,
    },
}

#[derive(Subcommand)]
enum ThemeCommand {
    /// Show/set theme configuration
    Config {
        #[arg(long)]
        get: Option<String>,
        #[arg(long)]
        set: Option<String>,
        /// After setting, immediately render + link + reload
        #[arg(long)]
        apply: bool,
    },
    /// Output palette colors
    Palette {
        /// Specific color name (e.g., "blue", "base")
        color: Option<String>,
        /// Output format: hex, hex-hash, rgb, rgb-css, hyprlang, rgba
        #[arg(long, default_value = "hex")]
        format: String,
        /// Alpha value for rgba formats (0.0-1.0)
        #[arg(long, default_value = "1.0")]
        alpha: f32,
        /// Flavor to use (mocha, macchiato, frappe, latte)
        #[arg(long, default_value = "mocha")]
        flavor: String,
        /// Output as JSON
        #[arg(long)]
        json: bool,
        /// Output as raw key=value (no color blocks)
        #[arg(long)]
        raw: bool,
    },
    /// Reload applications
    Reload {
        app: Option<String>,
        #[arg(long)]
        all: bool,
    },
}

#[derive(Subcommand)]
enum FontCommand {
    /// List installed fonts
    List {
        #[arg(long)]
        mono: bool,
        #[arg(long)]
        sans: bool,
    },
    /// Show/set font configuration
    Config,
    /// Set font choice
    Set {
        #[arg(long)]
        mono: Option<String>,
        #[arg(long)]
        sans: Option<String>,
    },
    /// Install font package
    Install { package: String },
}

/// Get the cfg configuration directory
fn get_cfg_dir() -> String {
    // First try CFG_DIR env var, then default to ~/.dotfiles/cfg
    std::env::var("CFG_DIR").unwrap_or_else(|_| {
        let home = std::env::var("HOME").expect("HOME not set");
        format!("{}/.dotfiles/cfg", home)
    })
}

/// Get the dotfiles root directory
fn get_dotfiles_dir() -> String {
    // First try DOTFILES_DIR env var, then default to ~/.dotfiles
    std::env::var("DOTFILES_DIR").unwrap_or_else(|_| {
        let home = std::env::var("HOME").expect("HOME not set");
        format!("{}/.dotfiles", home)
    })
}

/// Run full sync: render templates + run rotz link + reload apps
fn run_sync(cfg_dir: &str, dotfiles_dir: &str, name_filter: Option<&str>) {
    // Load config and palette
    let config = Config::load(&format!("{}/config.toml", cfg_dir)).unwrap_or_default();
    let palette_path = format!("{}/palettes/{}.toml", cfg_dir, config.flavor);
    let palette = match Palette::load(&palette_path) {
        Ok(p) => p,
        Err(e) => {
            eprintln!("Error loading palette: {}", e);
            std::process::exit(1);
        }
    };

    let context = build_context(&config, &palette);

    // Render templates (filtered if name provided)
    println!("Rendering templates...");
    let all_templates = discover_templates(&PathBuf::from(dotfiles_dir));
    let templates_list: Vec<PathBuf> = match name_filter {
        Some(name) => all_templates
            .into_iter()
            .filter(|p| p.to_str().map(|s| s.contains(name)).unwrap_or(false))
            .collect(),
        None => all_templates,
    };

    if templates_list.is_empty() {
        eprintln!("No templates found");
        std::process::exit(1);
    }

    for template_path in &templates_list {
        match render_to_file(template_path, &context, false) {
            Ok(output) => {
                println!("  {}  →  {}", template_path.display(), output.display());
            }
            Err(e) => {
                eprintln!("  Error: {}", e);
            }
        }
    }

    // Load templates registry for link and reload commands
    let templates_path = format!("{}/templates.toml", cfg_dir);
    if let Ok(templates) = TemplatesFile::load(&templates_path) {
        // Build set of rendered template paths for filtering
        let rendered_paths: std::collections::HashSet<String> = templates_list
            .iter()
            .filter_map(|p| p.to_str().map(|s| s.to_string()))
            .collect();

        // Run rotz link for apps that need it (filtered by rendered templates)
        let mut linked: std::collections::HashSet<String> = std::collections::HashSet::new();
        let mut any_links = false;
        for name in templates.names() {
            if let Some(tpl_config) = templates.get(name) {
                // Skip if this template wasn't rendered
                let full_path = format!("{}/{}", dotfiles_dir, tpl_config.path);
                if !rendered_paths.iter().any(|p| p.contains(&full_path) || full_path.contains(p)) {
                    continue;
                }
                if let Some(link_module) = &tpl_config.link {
                    if !linked.contains(link_module) {
                        if !any_links {
                            println!("\nLinking...");
                            any_links = true;
                        }
                        print!("  rotz link {}... ", link_module);
                        match rotz_link(link_module) {
                            Ok(()) => println!("ok"),
                            Err(e) => println!("failed: {}", e),
                        }
                        linked.insert(link_module.clone());
                    }
                }
            }
        }

        // Reload apps (filtered by rendered templates)
        let mut any_reloads = false;
        for name in templates.names() {
            if let Some(tpl_config) = templates.get(name) {
                // Skip if this template wasn't rendered
                let full_path = format!("{}/{}", dotfiles_dir, tpl_config.path);
                if !rendered_paths.iter().any(|p| p.contains(&full_path) || full_path.contains(p)) {
                    continue;
                }
                if let Some(cmd) = &tpl_config.reload {
                    if !any_reloads {
                        println!("\nReloading apps...");
                        any_reloads = true;
                    }
                    print!("  {}... ", name);
                    match reload_app(cmd) {
                        Ok(()) => println!("ok"),
                        Err(e) => println!("failed: {}", e),
                    }
                }
            }
        }
    }

    println!("\nDone!");
}

fn main() {
    let cli = Cli::parse();

    match cli.command {
        Command::Render {
            name,
            all,
            dry_run,
            force: _,
        } => {
            let cfg_dir = get_cfg_dir();
            let dotfiles_dir = get_dotfiles_dir();

            // Load config and palette
            let config = Config::load(&format!("{}/config.toml", cfg_dir)).unwrap_or_default();
            let palette_path = format!("{}/palettes/{}.toml", cfg_dir, config.flavor);
            let palette = match Palette::load(&palette_path) {
                Ok(p) => p,
                Err(e) => {
                    eprintln!("Error loading palette: {}", e);
                    std::process::exit(1);
                }
            };

            let context = build_context(&config, &palette);

            // Find templates to render
            let templates: Vec<PathBuf> = if all || name.is_none() {
                discover_templates(&PathBuf::from(&dotfiles_dir))
            } else {
                // Find template by name (match against full path)
                let name = name.unwrap();
                let all_templates = discover_templates(&PathBuf::from(&dotfiles_dir));
                all_templates
                    .into_iter()
                    .filter(|p| p.to_str().map(|s| s.contains(&name)).unwrap_or(false))
                    .collect()
            };

            if templates.is_empty() {
                eprintln!("No templates found");
                std::process::exit(1);
            }

            let mut success_count = 0;
            let mut error_count = 0;

            for template_path in &templates {
                match render_to_file(template_path, &context, dry_run) {
                    Ok(output) => {
                        let prefix = if dry_run { "[dry-run] " } else { "" };
                        println!(
                            "{}{}  →  {}",
                            prefix,
                            template_path.display(),
                            output.display()
                        );
                        success_count += 1;
                    }
                    Err(e) => {
                        eprintln!("Error: {}", e);
                        error_count += 1;
                    }
                }
            }

            if error_count > 0 {
                eprintln!(
                    "\nRendered {} templates, {} errors",
                    success_count, error_count
                );
                std::process::exit(1);
            }
        }
        Command::Sync { name } => {
            let cfg_dir = get_cfg_dir();
            let dotfiles_dir = get_dotfiles_dir();
            run_sync(&cfg_dir, &dotfiles_dir, name.as_deref());
        }
        Command::Theme { command } => match command {
            ThemeCommand::Config { get, set, apply } => {
                let cfg_dir = get_cfg_dir();
                let dotfiles_dir = get_dotfiles_dir();
                let config_path = format!("{}/config.toml", cfg_dir);

                let mut config = Config::load(&config_path).unwrap_or_default();

                if let Some(key_value) = set {
                    // Parse key=value
                    let parts: Vec<&str> = key_value.splitn(2, '=').collect();
                    if parts.len() != 2 {
                        eprintln!("Error: --set requires format key=value");
                        std::process::exit(1);
                    }
                    if let Err(e) = config.set(parts[0], parts[1]) {
                        eprintln!("Error: {}", e);
                        std::process::exit(1);
                    }
                    if let Err(e) = config.save(&config_path) {
                        eprintln!("Error: {}", e);
                        std::process::exit(1);
                    }
                    println!("{}={}", parts[0], parts[1]);

                    // If --apply flag is set, run full sync
                    if apply {
                        run_sync(&cfg_dir, &dotfiles_dir, None);
                    }
                } else if let Some(key) = get {
                    match config.get(&key) {
                        Some(value) => println!("{}", value),
                        None => {
                            eprintln!("Unknown config key: {}", key);
                            std::process::exit(1);
                        }
                    }
                } else {
                    // Show all config
                    println!("flavor={}", config.flavor);
                    println!("secondary={}", config.secondary);
                    println!("accent={}", config.accent);
                    println!("fonts.mono={}", config.fonts.mono);
                    println!("fonts.mono_size={}", config.fonts.mono_size);
                    println!("fonts.sans={}", config.fonts.sans);
                    println!("fonts.sans_size={}", config.fonts.sans_size);
                }
            }
            ThemeCommand::Palette {
                color,
                format,
                alpha,
                flavor,
                json,
                raw,
            } => {
                let cfg_dir = get_cfg_dir();
                let palette_path = format!("{}/palettes/{}.toml", cfg_dir, flavor);
                let palette = match Palette::load(&palette_path) {
                    Ok(p) => p,
                    Err(e) => {
                        eprintln!("Error: {}", e);
                        std::process::exit(1);
                    }
                };

                match color {
                    Some(name) => {
                        if let Some(c) = palette.get(&name) {
                            if json {
                                // Single color JSON: {"hex": "89b4fa", "rgb": [137, 180, 250]}
                                let obj = serde_json::json!({
                                    "hex": c.to_hex(),
                                    "rgb": [c.r, c.g, c.b]
                                });
                                println!("{}", serde_json::to_string(&obj).unwrap());
                            } else if raw {
                                // Raw: just the formatted value
                                println!("{}", format_color(c, &format, alpha));
                            } else {
                                // Default: color block + hex
                                println!("\x1b[38;2;{};{};{}m██\x1b[0m {}", c.r, c.g, c.b, c.to_hex_hash());
                            }
                        } else {
                            eprintln!("Unknown color: {}", name);
                            std::process::exit(1);
                        }
                    }
                    None => {
                        let mut names: Vec<_> = palette.colors.keys().collect();
                        names.sort();

                        if json {
                            // Full palette JSON
                            let mut obj = serde_json::Map::new();
                            for name in &names {
                                let c = palette.get(name).unwrap();
                                obj.insert(name.to_string(), serde_json::json!({
                                    "hex": c.to_hex(),
                                    "rgb": [c.r, c.g, c.b]
                                }));
                            }
                            println!("{}", serde_json::to_string_pretty(&serde_json::Value::Object(obj)).unwrap());
                        } else if raw {
                            // Raw: key=value
                            for name in &names {
                                let c = palette.get(name).unwrap();
                                println!("{}={}", name, format_color(c, &format, alpha));
                            }
                        } else {
                            // Default: color blocks + name + hex
                            for name in &names {
                                let c = palette.get(name).unwrap();
                                println!("\x1b[38;2;{};{};{}m██\x1b[0m {:12} {}", c.r, c.g, c.b, name, c.to_hex_hash());
                            }
                        }
                    }
                }
            }
            ThemeCommand::Reload { app, all } => {
                let cfg_dir = get_cfg_dir();
                let templates_path = format!("{}/templates.toml", cfg_dir);

                let templates = match TemplatesFile::load(&templates_path) {
                    Ok(t) => t,
                    Err(e) => {
                        eprintln!("Error: {}", e);
                        std::process::exit(1);
                    }
                };

                let targets: Vec<&String> = if all || app.is_none() {
                    templates.names()
                } else {
                    let name = app.as_ref().unwrap();
                    if templates.get(name).is_some() {
                        vec![name]
                    } else {
                        eprintln!("Unknown app: {}", name);
                        std::process::exit(1);
                    }
                };

                for name in targets {
                    if let Some(config) = templates.get(name) {
                        if let Some(cmd) = &config.reload {
                            print!("Reloading {}... ", name);
                            match reload_app(cmd) {
                                Ok(()) => println!("ok"),
                                Err(e) => println!("failed: {}", e),
                            }
                        } else {
                            println!("{}: no reload command", name);
                        }
                    }
                }
            }
        },
        Command::Font { command } => match command {
            FontCommand::List { mono, sans } => {
                println!("font list: mono={} sans={}", mono, sans);
            }
            FontCommand::Config => {
                println!("font config");
            }
            FontCommand::Set { mono, sans } => {
                println!("font set: mono={:?} sans={:?}", mono, sans);
            }
            FontCommand::Install { package } => {
                println!("font install: {}", package);
            }
        },
    }
}
