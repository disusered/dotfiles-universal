use glob::glob;
use serde::Deserialize;
use std::collections::HashMap;
use std::path::{Path, PathBuf};
use tera::{Context, Result as TeraResult, Tera, Value};

use crate::color::Color;
use crate::config::Config;
use crate::palette::Palette;

/// Map Catppuccin color names to ANSI color names
fn catppuccin_to_ansi(color_name: &str) -> &'static str {
    match color_name {
        // Reds/Pinks
        "red" | "maroon" => "red",
        "flamingo" | "pink" => "brightred",
        "rosewater" => "brightwhite",

        // Oranges/Yellows
        "peach" => "brightyellow",
        "yellow" => "yellow",

        // Greens
        "green" => "green",

        // Blues/Cyans
        "teal" => "cyan",
        "sky" => "brightcyan",
        "sapphire" | "lavender" => "brightblue",
        "blue" => "blue",

        // Purples
        "mauve" => "magenta",

        // Grays (light to dark)
        "text" | "subtext0" => "white",
        "subtext1" => "brightwhite",
        "overlay2" | "overlay1" | "overlay0" => "brightblack",
        "surface2" | "surface1" | "surface0" => "black",
        "base" | "mantle" | "crust" => "black",

        _ => "white", // fallback
    }
}

/// Helper: deserialize Color from Tera Value
fn value_to_color(value: &Value) -> TeraResult<Color> {
    Color::deserialize(value.clone())
        .map_err(|e| tera::Error::msg(format!("Failed to deserialize color: {}", e)))
}

/// Custom Tera filter: bare hex (same as default, but explicit)
/// Usage: {{ blue | hex }}
fn hex_filter(value: &Value, _args: &HashMap<String, Value>) -> TeraResult<Value> {
    let color = value_to_color(value)?;
    Ok(Value::String(color.to_hex()))
}

/// Custom Tera filter: uppercase hex
/// Usage: {{ blue | upper }}
fn upper_filter(value: &Value, _args: &HashMap<String, Value>) -> TeraResult<Value> {
    let color = value_to_color(value)?;
    Ok(Value::String(color.to_hex_upper()))
}

/// Custom Tera filter: space-separated RGB
/// Usage: {{ blue | rgb }}
fn rgb_filter(value: &Value, _args: &HashMap<String, Value>) -> TeraResult<Value> {
    let color = value_to_color(value)?;
    Ok(Value::String(color.to_rgb()))
}

/// Custom Tera filter: CSS rgb()
/// Usage: {{ blue | rgb_css }}
fn rgb_css_filter(value: &Value, _args: &HashMap<String, Value>) -> TeraResult<Value> {
    let color = value_to_color(value)?;
    Ok(Value::String(color.to_rgb_css()))
}

/// Custom Tera filter: CSS rgba()
/// Usage: {{ blue | rgba_css(alpha=0.9) }}
fn rgba_css_filter(value: &Value, args: &HashMap<String, Value>) -> TeraResult<Value> {
    let color = value_to_color(value)?;
    let alpha =
        args.get("alpha")
            .and_then(|v| v.as_f64())
            .ok_or_else(|| tera::Error::msg("rgba_css: missing 'alpha' argument"))? as f32;
    Ok(Value::String(color.to_rgba(alpha)))
}

/// Custom Tera filter: Hyprlang rgb()
/// Usage: {{ blue | hyprlang }}
fn hyprlang_filter(value: &Value, _args: &HashMap<String, Value>) -> TeraResult<Value> {
    let color = value_to_color(value)?;
    Ok(Value::String(color.to_hyprlang()))
}

/// Custom Tera filter: Hyprlang rgba()
/// Usage: {{ blue | hyprlang_rgba(alpha=0.9) }}
fn hyprlang_rgba_filter(value: &Value, args: &HashMap<String, Value>) -> TeraResult<Value> {
    let color = value_to_color(value)?;
    let alpha = args
        .get("alpha")
        .and_then(|v| v.as_f64())
        .ok_or_else(|| tera::Error::msg("hyprlang_rgba: missing 'alpha' argument"))?
        as f32;
    Ok(Value::String(color.to_hyprlang_rgba(alpha)))
}

/// Custom Tera filter: Qt ARGB hex format
/// Usage: {{ blue | hex_argb }} or {{ blue | hex_argb(alpha=0.5) }}
fn hex_argb_filter(value: &Value, args: &HashMap<String, Value>) -> TeraResult<Value> {
    let color = value_to_color(value)?;
    let alpha = args.get("alpha").and_then(|v| v.as_f64()).unwrap_or(1.0) as f32;
    Ok(Value::String(color.to_hex_argb(alpha)))
}

/// Custom Tera filter: ANSI color name
/// Usage: {{ blue_name | ansi }} or {{ accent_name | ansi }}
/// Input: Catppuccin color name string (e.g., "blue", "text", "mauve")
/// Output: ANSI color name (e.g., "blue", "white", "magenta")
fn ansi_filter(value: &Value, _args: &HashMap<String, Value>) -> TeraResult<Value> {
    if let Some(name) = value.as_str() {
        Ok(Value::String(catppuccin_to_ansi(name).to_string()))
    } else {
        Err(tera::Error::msg(
            "ansi: expected color name string (use blue_name, accent_name, etc.)",
        ))
    }
}

/// Custom Tera filter: blend colors
/// Usage: {{ red | blend(base=base, amount=25) }}
fn blend_filter(value: &Value, args: &HashMap<String, Value>) -> TeraResult<Value> {
    let fg = value_to_color(value)?;
    let bg_value = args
        .get("base")
        .ok_or_else(|| tera::Error::msg("blend: missing 'base' argument"))?;
    let bg = value_to_color(bg_value)?;
    let amount =
        args.get("amount")
            .and_then(|v| v.as_u64())
            .ok_or_else(|| tera::Error::msg("blend: missing 'amount' argument"))? as u8;

    let blended = fg.blend(&bg, amount);
    Ok(tera::to_value(blended)?)
}

/// Custom Tera filter: lighten color
/// Usage: {{ blue | lighten(amount=15) }}
fn lighten_filter(value: &Value, args: &HashMap<String, Value>) -> TeraResult<Value> {
    let color = value_to_color(value)?;
    let amount = args
        .get("amount")
        .and_then(|v| v.as_u64())
        .ok_or_else(|| tera::Error::msg("lighten: missing 'amount' argument"))? as u8;
    Ok(tera::to_value(color.lighten(amount))?)
}

/// Custom Tera filter: darken color
/// Usage: {{ blue | darken(amount=15) }}
fn darken_filter(value: &Value, args: &HashMap<String, Value>) -> TeraResult<Value> {
    let color = value_to_color(value)?;
    let amount = args
        .get("amount")
            .and_then(|v| v.as_u64())
            .ok_or_else(|| tera::Error::msg("darken: missing 'amount' argument"))? as u8;
    Ok(tera::to_value(color.darken(amount))?)
}

/// Discover all .tera template files in a directory (recursively)
pub fn discover_templates(root: &Path) -> Vec<PathBuf> {
    let pattern = format!("{}/**/*.tera", root.display());
    glob(&pattern)
        .expect("Invalid glob pattern")
        .filter_map(Result::ok)
        .collect()
}

/// Get the output path for a template (strips .tera extension)
pub fn output_path(template_path: &Path) -> PathBuf {
    let stem = template_path.file_stem().unwrap().to_str().unwrap();
    template_path.with_file_name(stem)
}

/// Build a Tera context with all available variables
pub fn build_context(config: &Config, palette: &Palette) -> Context {
    let mut ctx = Context::new();

    // Add config values
    ctx.insert("flavor", &config.flavor);
    ctx.insert("icon_theme", &config.icon_theme);
    ctx.insert("gtk_theme", &config.gtk_theme);
    ctx.insert("qt_style", &config.qt_style);
    ctx.insert("font_mono", &config.fonts.mono);
    ctx.insert("font_mono_size", &config.fonts.mono_size);
    ctx.insert("font_sans", &config.fonts.sans);
    ctx.insert("font_sans_size", &config.fonts.sans_size);

    // Add HOME for path templating
    if let Ok(home) = std::env::var("HOME") {
        ctx.insert("home", &home);
    }

    // Add all palette colors as Color objects
    // Templates can use: {{ blue }}, #{{ blue }}, {{ blue | rgb_css }}, etc.
    for (name, color) in &palette.colors {
        ctx.insert(name, color);
        // Also add color name as string for ANSI filter
        ctx.insert(&format!("{}_name", name), name);
    }

    // Add accent and secondary color objects
    if let Some(accent_color) = palette.get(&config.accent) {
        ctx.insert("accent", accent_color);
        ctx.insert("accent_name", &config.accent);
    }
    if let Some(secondary_color) = palette.get(&config.secondary) {
        ctx.insert("secondary", secondary_color);
        ctx.insert("secondary_name", &config.secondary);
    }

    ctx
}

/// Render a single template file
pub fn render_template(template_path: &Path, context: &Context) -> Result<String, String> {
    let content = std::fs::read_to_string(template_path).map_err(|e| {
        format!(
            "Failed to read template '{}': {}",
            template_path.display(),
            e
        )
    })?;

    // Create a one-off Tera instance for this template
    let mut tera = Tera::default();
    tera.register_filter("hex", hex_filter);
    tera.register_filter("upper", upper_filter);
    tera.register_filter("rgb", rgb_filter);
    tera.register_filter("rgb_css", rgb_css_filter);
    tera.register_filter("rgba_css", rgba_css_filter);
    tera.register_filter("hyprlang", hyprlang_filter);
    tera.register_filter("hyprlang_rgba", hyprlang_rgba_filter);
    tera.register_filter("hex_argb", hex_argb_filter);
    tera.register_filter("ansi", ansi_filter);
    tera.register_filter("blend", blend_filter);
    tera.register_filter("lighten", lighten_filter);
    tera.register_filter("darken", darken_filter);
    tera.add_raw_template("template", &content).map_err(|e| {
        format!(
            "Failed to parse template '{}': {}",
            template_path.display(),
            e
        )
    })?;

    let rendered = tera.render("template", context).map_err(|e| {
        format!(
            "Failed to render template '{}': {:?}",
            template_path.display(),
            e
        )
    })?;

    // Strip vim/editor modelines from output (they're only for template editing)
    Ok(strip_modelines(&rendered))
}

/// Strip editor modelines from rendered output (they're only for template editing)
fn strip_modelines(content: &str) -> String {
    let mut result: String = content
        .lines()
        .filter(|line| {
            let trimmed = line.trim();
            // Skip vim modelines (only needed for template syntax highlighting)
            !(trimmed.starts_with("# vi:")
                || trimmed.starts_with("# vim:")
                || trimmed.starts_with("// vi:")
                || trimmed.starts_with("// vim:")
                || trimmed.starts_with("/* vi:")
                || trimmed.starts_with("/* vim:"))
        })
        .collect::<Vec<_>>()
        .join("\n");

    // Ensure trailing newline
    if !result.ends_with('\n') {
        result.push('\n');
    }
    result
}

/// Render a template and write to output file
pub fn render_to_file(
    template_path: &Path,
    context: &Context,
    dry_run: bool,
) -> Result<PathBuf, String> {
    let output = output_path(template_path);
    let rendered = render_template(template_path, context)?;

    if dry_run {
        // Just return the output path without writing
        return Ok(output);
    }

    std::fs::write(&output, rendered)
        .map_err(|e| format!("Failed to write '{}': {}", output.display(), e))?;

    Ok(output)
}
