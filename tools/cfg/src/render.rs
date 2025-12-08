use std::path::{Path, PathBuf};
use tera::{Context, Tera};
use glob::glob;

use crate::config::Config;
use crate::palette::Palette;

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
    ctx.insert("accent", &config.accent);
    ctx.insert("font_mono", &config.fonts.mono);
    ctx.insert("font_mono_size", &config.fonts.mono_size);
    ctx.insert("font_sans", &config.fonts.sans);
    ctx.insert("font_sans_size", &config.fonts.sans_size);

    // Add all color formats for each palette color
    for (name, color) in &palette.colors {
        // Base (no suffix) = hex without #
        ctx.insert(name, &color.to_hex());
        // _hex = with #
        ctx.insert(&format!("{}_hex", name), &color.to_hex_hash());
        // _hex_upper = with # uppercase
        ctx.insert(&format!("{}_hex_upper", name), &color.to_hex_hash_upper());
        // _rgb = space separated
        ctx.insert(&format!("{}_rgb", name), &color.to_rgb());
        // _rgb_css = rgb(r, g, b)
        ctx.insert(&format!("{}_rgb_css", name), &color.to_rgb_css());
        // _hyprlang = rgb(hex)
        ctx.insert(&format!("{}_hyprlang", name), &color.to_hyprlang());
    }

    // Add accent color shortcuts (based on current accent setting)
    if let Some(accent_color) = palette.get(&config.accent) {
        ctx.insert("accent_color", &accent_color.to_hex());
        ctx.insert("accent_color_hex", &accent_color.to_hex_hash());
        ctx.insert("accent_color_hex_upper", &accent_color.to_hex_hash_upper());
        ctx.insert("accent_color_rgb", &accent_color.to_rgb());
        ctx.insert("accent_color_rgb_css", &accent_color.to_rgb_css());
        ctx.insert("accent_color_hyprlang", &accent_color.to_hyprlang());
    }

    ctx
}

/// Render a single template file
pub fn render_template(
    template_path: &Path,
    context: &Context,
) -> Result<String, String> {
    let content = std::fs::read_to_string(template_path)
        .map_err(|e| format!("Failed to read template '{}': {}", template_path.display(), e))?;

    // Create a one-off Tera instance for this template
    let mut tera = Tera::default();
    tera.add_raw_template("template", &content)
        .map_err(|e| format!("Failed to parse template '{}': {}", template_path.display(), e))?;

    let rendered = tera.render("template", context)
        .map_err(|e| format!("Failed to render template '{}': {}", template_path.display(), e))?;

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
            !(trimmed.starts_with("# vi:") ||
              trimmed.starts_with("# vim:") ||
              trimmed.starts_with("// vi:") ||
              trimmed.starts_with("// vim:") ||
              trimmed.starts_with("/* vi:") ||
              trimmed.starts_with("/* vim:"))
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
