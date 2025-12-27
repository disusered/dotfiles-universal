mod color;
mod config;
mod fonts;
mod palette;
mod render;
mod templates;

use std::path::PathBuf;

use clap::{Parser, Subcommand};
use color::format_color;
use config::Config;
use palette::Palette;
use render::{build_context, render_to_file};
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
    /// Render templates + symlink + reload apps
    Update {
        /// Names to update. If empty, updates all.
        names: Vec<String>,
        /// List available templates
        #[arg(long)]
        list: bool,
        /// Preview without writing
        #[arg(long)]
        dry_run: bool,
    },
    /// Theme configuration (colors)
    Theme {
        /// Get a specific value
        #[arg(long)]
        get: Option<String>,
        /// Set a value (format: key=value)
        #[arg(long)]
        set: Option<String>,
        /// List available colors (palette)
        #[arg(long)]
        list: bool,
        /// After --set, update (render + reload). Optionally scope to specific names.
        #[arg(long, requires = "set", num_args = 0..)]
        apply: Option<Vec<String>>,
        /// Output format for --list: hex, hex-hash, rgb, rgb-css, hyprlang
        #[arg(long, requires = "list")]
        format: Option<String>,
        /// Output as JSON (for --list)
        #[arg(long, requires = "list")]
        json: bool,
    },
    /// Font configuration
    Font {
        /// Get a specific value (mono, sans)
        #[arg(long)]
        get: Option<String>,
        /// Set a value (format: key=value)
        #[arg(long)]
        set: Option<String>,
        /// List available fonts
        #[arg(long)]
        list: bool,
        /// After --set, update (render + reload). Optionally scope to specific names.
        #[arg(long, requires = "set", num_args = 0..)]
        apply: Option<Vec<String>>,
        /// Filter --list to monospace fonts
        #[arg(long, requires = "list")]
        mono: bool,
        /// Filter --list to sans-serif fonts
        #[arg(long, requires = "list")]
        sans: bool,
    },
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

/// Update apps: render + symlink + reload
fn update_apps(cfg_dir: &str, dotfiles_dir: &str, app_names: &[String], dry_run: bool) {
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

    // Load templates registry
    let templates_path = format!("{}/templates.toml", cfg_dir);
    let templates = match TemplatesFile::load(&templates_path) {
        Ok(t) => t,
        Err(e) => {
            eprintln!("Error loading templates.toml: {}", e);
            std::process::exit(1);
        }
    };

    // Determine which apps to update
    let targets: Vec<&String> = if app_names.is_empty() {
        templates.names()
    } else {
        // Validate all app names exist
        for name in app_names {
            if templates.get(name).is_none() {
                eprintln!("Unknown: {}", name);
                eprintln!("Available: {}", templates.names().iter().map(|s| s.as_str()).collect::<Vec<_>>().join(", "));
                std::process::exit(1);
            }
        }
        app_names.iter().collect()
    };

    let mut rendered: Vec<String> = Vec::new();
    let mut linked: std::collections::HashSet<String> = std::collections::HashSet::new();

    // Phase 1: Render + symlink
    for name in &targets {
        let tpl_config = templates.get(name).unwrap();
        let template_path = PathBuf::from(format!("{}/{}", dotfiles_dir, tpl_config.path));

        if !template_path.exists() {
            eprintln!("  {} - template not found: {}", name, template_path.display());
            continue;
        }

        match render_to_file(&template_path, &context, dry_run) {
            Ok(output) => {
                let prefix = if dry_run { "[dry-run] " } else { "" };
                println!("{}{}  →  {}", prefix, name, output.display());
                rendered.push((*name).clone());

                // Auto-symlink if not dry-run and link is defined
                if !dry_run {
                    if let Some(link_module) = &tpl_config.link {
                        if !linked.contains(link_module) {
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
            Err(e) => {
                eprintln!("  {} - error: {}", name, e);
            }
        }
    }

    // Phase 2: Reload (only rendered apps, skip dry-run)
    if !dry_run && !rendered.is_empty() {
        println!("\nReloading...");
        for name in &rendered {
            if let Some(tpl_config) = templates.get(name) {
                if let Some(cmd) = &tpl_config.reload {
                    print!("  {}... ", name);
                    match reload_app(cmd) {
                        Ok(()) => println!("ok"),
                        Err(e) => println!("failed: {}", e),
                    }
                }
            }
        }
    }
}

fn main() {
    let cli = Cli::parse();

    match cli.command {
        Command::Update { names, list, dry_run } => {
            let cfg_dir = get_cfg_dir();
            let dotfiles_dir = get_dotfiles_dir();

            if list {
                // List available templates
                let templates_path = format!("{}/templates.toml", cfg_dir);
                let templates = match TemplatesFile::load(&templates_path) {
                    Ok(t) => t,
                    Err(e) => {
                        eprintln!("Error: {}", e);
                        std::process::exit(1);
                    }
                };
                let mut names: Vec<_> = templates.names();
                names.sort();
                for name in names {
                    println!("{}", name);
                }
            } else {
                update_apps(&cfg_dir, &dotfiles_dir, &names, dry_run);
            }
        }
        Command::Theme { get, set, list, apply, format, json } => {
            let cfg_dir = get_cfg_dir();
            let dotfiles_dir = get_dotfiles_dir();
            let config_path = format!("{}/config.toml", cfg_dir);

            let mut config = Config::load(&config_path).unwrap_or_default();

            if list {
                // Show palette colors
                let palette_path = format!("{}/palettes/{}.toml", cfg_dir, config.flavor);
                let palette = match Palette::load(&palette_path) {
                    Ok(p) => p,
                    Err(e) => {
                        eprintln!("Error: {}", e);
                        std::process::exit(1);
                    }
                };

                let mut names: Vec<_> = palette.colors.keys().collect();
                names.sort();

                let fmt = format.as_deref().unwrap_or("hex-hash");
                if json {
                    let mut obj = serde_json::Map::new();
                    for name in &names {
                        let c = palette.get(name).unwrap();
                        obj.insert(name.to_string(), serde_json::json!(format_color(c, fmt, 1.0)));
                    }
                    println!("{}", serde_json::to_string_pretty(&serde_json::Value::Object(obj)).unwrap());
                } else {
                    for name in &names {
                        let c = palette.get(name).unwrap();
                        let formatted = format_color(c, fmt, 1.0);
                        println!("\x1b[38;2;{};{};{}m██\x1b[0m {:12} {}", c.r, c.g, c.b, name, formatted);
                    }
                }
            } else if let Some(key_value) = set {
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

                if let Some(scope) = apply {
                    update_apps(&cfg_dir, &dotfiles_dir, &scope, false);
                }
            } else if let Some(key) = get {
                match config.get(&key) {
                    Some(value) => println!("{}", value),
                    None => {
                        eprintln!("Unknown key: {}", key);
                        std::process::exit(1);
                    }
                }
            } else {
                // Show current theme config
                println!("flavor={}", config.flavor);
                println!("accent={}", config.accent);
                println!("secondary={}", config.secondary);
            }
        }
        Command::Font { get, set, list, apply, mono, sans } => {
            let cfg_dir = get_cfg_dir();
            let dotfiles_dir = get_dotfiles_dir();
            let config_path = format!("{}/config.toml", cfg_dir);

            let mut config = Config::load(&config_path).unwrap_or_default();

            if list {
                // Determine category filter
                let category = if mono {
                    Some(fonts::FontCategory::Mono)
                } else if sans {
                    Some(fonts::FontCategory::Sans)
                } else {
                    None
                };

                let listings = fonts::list_fonts(category);

                // Group by category if no filter
                let show_mono = !sans;
                let show_sans = !mono;

                if show_mono {
                    println!("Monospace (coding):");
                    for font in listings.iter().filter(|f| {
                        fonts::is_valid_font(f.name, fonts::FontCategory::Mono)
                    }) {
                        let status = if font.installed { "✓" } else { " " };
                        let lig = if font.ligatures { "lig" } else { "   " };
                        let current = if font.name == config.fonts.mono { " ←" } else { "" };
                        println!("  {} {} {:30} {}{}", status, lig, font.name, font.description, current);
                    }
                }

                if show_sans {
                    if show_mono {
                        println!();
                    }
                    println!("Sans-serif (UI):");
                    for font in listings.iter().filter(|f| {
                        fonts::is_valid_font(f.name, fonts::FontCategory::Sans)
                    }) {
                        let status = if font.installed { "✓" } else { " " };
                        let current = if font.name == config.fonts.sans { " ←" } else { "" };
                        println!("  {}     {:30} {}{}", status, font.name, font.description, current);
                    }
                }

                println!();
                println!("✓ = installed, lig = has ligatures, ← = current");
            } else if let Some(key_value) = set {
                // Parse key=value
                let parts: Vec<&str> = key_value.splitn(2, '=').collect();
                if parts.len() != 2 {
                    eprintln!("Error: --set requires format key=value");
                    std::process::exit(1);
                }

                let key = parts[0];
                let value = parts[1];

                // Validate font names against registry
                match key {
                    "mono" => {
                        if !fonts::is_valid_font(value, fonts::FontCategory::Mono) {
                            eprintln!("Unknown mono font: {}", value);
                            eprintln!("Use 'cfg font --list --mono' to see available fonts");
                            std::process::exit(1);
                        }
                        if !fonts::is_font_installed(value) {
                            eprintln!("Warning: {} is not installed", value);
                        }
                    }
                    "sans" => {
                        if !fonts::is_valid_font(value, fonts::FontCategory::Sans) {
                            eprintln!("Unknown sans font: {}", value);
                            eprintln!("Use 'cfg font --list --sans' to see available fonts");
                            std::process::exit(1);
                        }
                        if !fonts::is_font_installed(value) {
                            eprintln!("Warning: {} is not installed", value);
                        }
                    }
                    "mono_size" | "sans_size" => {
                        // Just validate it's a number
                        if value.parse::<u32>().is_err() {
                            eprintln!("Error: {} must be a number", key);
                            std::process::exit(1);
                        }
                    }
                    _ => {
                        eprintln!("Unknown key: {} (valid: mono, mono_size, sans, sans_size)", key);
                        std::process::exit(1);
                    }
                }

                // Use the config's set method with proper key prefix
                let config_key = format!("fonts.{}", key);
                if let Err(e) = config.set(&config_key, value) {
                    eprintln!("Error: {}", e);
                    std::process::exit(1);
                }
                if let Err(e) = config.save(&config_path) {
                    eprintln!("Error: {}", e);
                    std::process::exit(1);
                }
                println!("{}={}", key, value);

                if let Some(scope) = apply {
                    update_apps(&cfg_dir, &dotfiles_dir, &scope, false);
                }
            } else if let Some(key) = get {
                // Get specific font value
                match key.as_str() {
                    "mono" => println!("{}", config.fonts.mono),
                    "mono_size" => println!("{}", config.fonts.mono_size),
                    "sans" => println!("{}", config.fonts.sans),
                    "sans_size" => println!("{}", config.fonts.sans_size),
                    _ => {
                        eprintln!("Unknown key: {} (valid: mono, mono_size, sans, sans_size)", key);
                        std::process::exit(1);
                    }
                }
            } else {
                // Show current font config
                println!("mono={}", config.fonts.mono);
                println!("mono_size={}", config.fonts.mono_size);
                println!("sans={}", config.fonts.sans);
                println!("sans_size={}", config.fonts.sans_size);
            }
        }
    }
}
