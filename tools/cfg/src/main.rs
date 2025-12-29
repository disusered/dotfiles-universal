mod color;
mod config;
mod fonts;
mod palette;
mod render;
mod templates;
mod tui;

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
    /// Interactive settings TUI (colors + fonts)
    #[arg(short, long, global = true)]
    interactive: bool,

    #[command(subcommand)]
    command: Option<Command>,
}

#[derive(Subcommand)]
enum Command {
    /// Render templates + symlink + reload apps
    Update {
        /// Names to update. If empty, updates all.
        #[arg(conflicts_with = "list")]
        names: Vec<String>,
        /// List available templates
        #[arg(long, conflicts_with = "dry_run")]
        list: bool,
        /// Preview without writing
        #[arg(long)]
        dry_run: bool,
    },
    /// Theme configuration (colors)
    Theme {
        /// Get a specific value
        #[arg(long, group = "mode")]
        get: Option<String>,
        /// Set a value (format: key=value)
        #[arg(long, group = "mode")]
        set: Option<String>,
        /// List available colors (palette)
        #[arg(long, group = "mode")]
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
        /// Interactive picker mode
        #[arg(short, long, group = "mode")]
        interactive: bool,
    },
    /// Font configuration
    Font {
        /// Get a specific value (mono, sans)
        #[arg(long, group = "mode")]
        get: Option<String>,
        /// Set a value (format: key=value)
        #[arg(long, group = "mode")]
        set: Option<String>,
        /// List available fonts (with inline graphics samples)
        #[arg(long, group = "mode")]
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
        /// Output as JSON (for --list)
        #[arg(long, requires = "list")]
        json: bool,
        /// Preview current font at multiple sizes and variants
        #[arg(long, group = "mode")]
        preview: bool,
        /// Interactive picker mode
        #[arg(short, long, group = "mode")]
        interactive: bool,
        /// Scratchpad preview mode (reads font from /tmp/cfg-font-preview)
        #[arg(long, group = "mode", hide = true)]
        scratchpad: bool,
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

    // Handle global -i flag (no subcommand needed)
    if cli.interactive && cli.command.is_none() {
        let cfg_dir = get_cfg_dir();
        let dotfiles_dir = get_dotfiles_dir();
        let config_path = format!("{}/config.toml", cfg_dir);

        if !tui::is_tty() {
            eprintln!("Interactive mode requires a terminal");
            std::process::exit(1);
        }

        let config = Config::load(&config_path).unwrap_or_default();
        let palette_path = format!("{}/palettes/{}.toml", cfg_dir, config.flavor);
        let palette = match Palette::load(&palette_path) {
            Ok(p) => p,
            Err(e) => {
                eprintln!("Error: {}", e);
                std::process::exit(1);
            }
        };

        match tui::app::run(&config, &palette, &config_path) {
            Ok(Some(true)) => {
                // User wants to apply
                update_apps(&cfg_dir, &dotfiles_dir, &[], false);
            }
            Ok(Some(false)) => {
                // Saved but no apply
                println!("Config saved (run 'cfg update' to apply)");
            }
            Ok(None) => {
                // Quit without saving
            }
            Err(e) => {
                eprintln!("Error: {}", e);
                std::process::exit(1);
            }
        }
        return;
    }

    // Require a subcommand if -i not used at root
    let command = match cli.command {
        Some(cmd) => cmd,
        None => {
            eprintln!("Usage: cfg <COMMAND> or cfg -i");
            eprintln!("Try 'cfg --help' for more information.");
            std::process::exit(1);
        }
    };

    match command {
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
        Command::Theme { get, set, list, apply, format, json, interactive } => {
            let cfg_dir = get_cfg_dir();
            let dotfiles_dir = get_dotfiles_dir();
            let config_path = format!("{}/config.toml", cfg_dir);

            let mut config = Config::load(&config_path).unwrap_or_default();

            if interactive {
                // Interactive TUI picker
                if !tui::is_tty() {
                    eprintln!("Interactive mode requires a terminal");
                    std::process::exit(1);
                }

                let palette_path = format!("{}/palettes/{}.toml", cfg_dir, config.flavor);
                let palette = match Palette::load(&palette_path) {
                    Ok(p) => p,
                    Err(e) => {
                        eprintln!("Error: {}", e);
                        std::process::exit(1);
                    }
                };

                match tui::colors::run_picker(&config, &palette, &config_path) {
                    Ok(Some(true)) => {
                        // User wants to apply
                        update_apps(&cfg_dir, &dotfiles_dir, &[], false);
                    }
                    Ok(Some(false)) => {
                        // Saved but no apply
                        println!("Config saved (run 'cfg update' to apply)");
                    }
                    Ok(None) => {
                        // Quit without saving
                    }
                    Err(e) => {
                        eprintln!("Error: {}", e);
                        std::process::exit(1);
                    }
                }
            } else if list {
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
        Command::Font { get, set, list, apply, mono, sans, json, preview, interactive, scratchpad } => {
            let cfg_dir = get_cfg_dir();
            let dotfiles_dir = get_dotfiles_dir();
            let config_path = format!("{}/config.toml", cfg_dir);

            let mut config = Config::load(&config_path).unwrap_or_default();

            if scratchpad {
                // Scratchpad preview mode - read font from temp file
                let font_name = std::fs::read_to_string("/tmp/cfg-font-preview")
                    .unwrap_or_else(|_| config.fonts.mono.clone())
                    .trim()
                    .to_string();

                // Load palette for theming
                let palette_path = format!("{}/palettes/{}.toml", cfg_dir, config.flavor);
                let palette = Palette::load(&palette_path).unwrap_or_else(|_| {
                    Palette { colors: std::collections::HashMap::new() }
                });

                match tui::fonts::run_scratchpad_preview(&font_name, &config, &palette, &config_path) {
                    Ok(true) => {
                        // User saved - update apps that use mono font
                        update_apps(&cfg_dir, &dotfiles_dir, &[], false);
                    }
                    Ok(false) => {}
                    Err(e) => {
                        eprintln!("Error: {}", e);
                        std::process::exit(1);
                    }
                }
            } else if preview {
                // Load palette for colors
                let palette_path = format!("{}/palettes/{}.toml", cfg_dir, config.flavor);
                let palette = Palette::load(&palette_path).ok();

                let accent_rgb = palette
                    .as_ref()
                    .and_then(|p| p.get(&config.accent))
                    .map(|c| (c.r, c.g, c.b));
                let subtext_rgb = palette
                    .as_ref()
                    .and_then(|p| p.get("subtext0"))
                    .map(|c| (c.r, c.g, c.b));

                fonts::preview_font_styled(&config.fonts.mono, accent_rgb, subtext_rgb);
            } else if interactive {
                // Interactive TUI picker
                if !tui::is_tty() {
                    eprintln!("Interactive mode requires a terminal");
                    std::process::exit(1);
                }

                // Load palette for theming
                let palette_path = format!("{}/palettes/{}.toml", cfg_dir, config.flavor);
                let palette = Palette::load(&palette_path).unwrap_or_else(|_| {
                    Palette { colors: std::collections::HashMap::new() }
                });

                match tui::fonts::run_picker(&config, &palette, &config_path) {
                    Ok(Some(true)) => {
                        // User wants to apply
                        update_apps(&cfg_dir, &dotfiles_dir, &[], false);
                    }
                    Ok(Some(false)) => {
                        // Saved but no apply
                        println!("Config saved (run 'cfg update' to apply)");
                    }
                    Ok(None) => {
                        // Quit without saving
                    }
                    Err(e) => {
                        eprintln!("Error: {}", e);
                        std::process::exit(1);
                    }
                }
            } else if list {
                if json {
                    let mono_fonts: Vec<serde_json::Value> = fonts::list_fonts(Some(fonts::FontCategory::Mono))
                        .iter()
                        .map(|f| serde_json::json!({
                            "name": f.name,
                            "description": f.description,
                            "installed": f.installed,
                            "ligatures": f.ligatures,
                            "nerd_font": f.nerd_font
                        }))
                        .collect();

                    let sans_fonts: Vec<serde_json::Value> = fonts::list_fonts(Some(fonts::FontCategory::Sans))
                        .iter()
                        .map(|f| serde_json::json!({
                            "name": f.name,
                            "description": f.description,
                            "installed": f.installed,
                            "ligatures": f.ligatures,
                            "nerd_font": f.nerd_font
                        }))
                        .collect();

                    let mut result = serde_json::Map::new();
                    result.insert("mono".to_string(), serde_json::Value::Array(mono_fonts));
                    result.insert("sans".to_string(), serde_json::Value::Array(sans_fonts));

                    println!("{}", serde_json::to_string_pretty(&serde_json::Value::Object(result)).unwrap());
                    return;
                }

                // Load palette for colors
                let palette_path = format!("{}/palettes/{}.toml", cfg_dir, config.flavor);
                let palette = Palette::load(&palette_path).ok();

                // Get accent color for highlighting current font
                let accent = palette.as_ref()
                    .and_then(|p| p.get(&config.accent))
                    .map(|c| format!("\x1b[38;2;{};{};{}m", c.r, c.g, c.b))
                    .unwrap_or_default();
                let green = palette.as_ref()
                    .and_then(|p| p.get("green"))
                    .map(|c| format!("\x1b[38;2;{};{};{}m", c.r, c.g, c.b))
                    .unwrap_or_else(|| "\x1b[32m".to_string());
                let dim = "\x1b[2m";
                let reset = "\x1b[0m";

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

                // Helper to print a font row
                let print_font = |font: &fonts::FontListing, is_current: bool| {
                    let status = if font.installed { format!("{}✓{}", green, reset) } else { " ".to_string() };
                    let lig = if font.ligatures { format!("{}lig{}", dim, reset) } else { "   ".to_string() };
                    let nerd = if font.nerd_font { format!("{}nf{}", dim, reset) } else { "  ".to_string() };

                    // Highlight current font with accent color
                    let (name_start, name_end) = if is_current {
                        (accent.as_str(), reset)
                    } else if !font.installed {
                        (dim, reset)
                    } else {
                        ("", "")
                    };

                    // Table layout: status name lig nerd description
                    println!(
                        "{} {}{:<28}{} {} {} {}",
                        status, name_start, font.name, name_end, lig, nerd, font.description
                    );

                    // Show inline graphics sample for installed fonts
                    if font.installed {
                        let sample = "The quick brown fox jumps over the lazy dog";
                        if let Ok(png) = fonts::render_font_sample(font.name, sample, 14) {
                            fonts::display_kitty_image(&png);
                            println!();
                        }
                    }
                };

                if show_mono {
                    println!("{}Monospace:{}", accent, reset);
                    for font in listings.iter().filter(|f| {
                        fonts::is_valid_font(f.name, fonts::FontCategory::Mono)
                    }) {
                        let is_current = font.name == config.fonts.mono;
                        print_font(font, is_current);
                    }
                }

                if show_sans {
                    if show_mono {
                        println!();
                    }
                    println!("{}Sans-serif:{}", accent, reset);
                    for font in listings.iter().filter(|f| {
                        fonts::is_valid_font(f.name, fonts::FontCategory::Sans)
                    }) {
                        let is_current = font.name == config.fonts.sans;
                        print_font(font, is_current);
                    }
                }

                println!();
                println!("{}✓{} installed  {}lig{} ligatures  {}nf{} nerd font", green, reset, dim, reset, dim, reset);
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
