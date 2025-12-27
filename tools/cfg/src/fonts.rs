use std::collections::HashSet;
use std::process::Command;

/// A curated font entry with metadata
#[derive(Debug, Clone)]
pub struct FontEntry {
    /// Display name (as it appears in fc-list)
    pub name: &'static str,
    /// Arch Linux package name
    pub package: &'static str,
    /// Font category
    #[allow(dead_code)]
    pub category: FontCategory,
    /// Has programming ligatures
    pub ligatures: bool,
    /// Is a Nerd Font (has icons/glyphs)
    pub nerd_font: bool,
    /// Short description
    pub description: &'static str,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum FontCategory {
    Mono,
    Sans,
}

/// Curated list of recommended monospace fonts (Nerd Font patched)
const MONO_FONTS: &[FontEntry] = &[
    FontEntry {
        name: "JetBrainsMono Nerd Font",
        package: "ttf-jetbrains-mono-nerd",
        category: FontCategory::Mono,
        ligatures: true,
        nerd_font: true,
        description: "JetBrains IDE font, excellent readability",
    },
    FontEntry {
        name: "FiraCode Nerd Font",
        package: "ttf-firacode-nerd",
        category: FontCategory::Mono,
        ligatures: true,
        nerd_font: true,
        description: "Mozilla's monospace with rich ligatures",
    },
    FontEntry {
        name: "CaskaydiaCove Nerd Font",
        package: "ttf-cascadia-code-nerd",
        category: FontCategory::Mono,
        ligatures: true,
        nerd_font: true,
        description: "Microsoft's Windows Terminal font",
    },
    FontEntry {
        name: "Hack Nerd Font",
        package: "ttf-hack-nerd",
        category: FontCategory::Mono,
        ligatures: false,
        nerd_font: true,
        description: "Classic coding font, large x-height",
    },
    FontEntry {
        name: "Iosevka Nerd Font",
        package: "ttf-iosevka-nerd",
        category: FontCategory::Mono,
        ligatures: true,
        nerd_font: true,
        description: "Narrow, customizable, many variants",
    },
    FontEntry {
        name: "VictorMono Nerd Font",
        package: "ttf-victor-mono-nerd",
        category: FontCategory::Mono,
        ligatures: true,
        nerd_font: true,
        description: "Cursive italics, clean ligatures",
    },
    FontEntry {
        name: "Hasklug Nerd Font",
        package: "otf-hasklig-nerd",
        category: FontCategory::Mono,
        ligatures: true,
        nerd_font: true,
        description: "Source Code Pro + Haskell ligatures",
    },
    FontEntry {
        name: "UbuntuMono Nerd Font",
        package: "ttf-ubuntu-mono-nerd",
        category: FontCategory::Mono,
        ligatures: false,
        nerd_font: true,
        description: "Ubuntu's distinctive monospace",
    },
    FontEntry {
        name: "RobotoMono Nerd Font",
        package: "ttf-roboto-mono-nerd",
        category: FontCategory::Mono,
        ligatures: false,
        nerd_font: true,
        description: "Google's geometric monospace",
    },
    FontEntry {
        name: "Mononoki Nerd Font",
        package: "ttf-mononoki-nerd",
        category: FontCategory::Mono,
        ligatures: false,
        nerd_font: true,
        description: "Minimal, easy on the eyes",
    },
    FontEntry {
        name: "GeistMono Nerd Font",
        package: "otf-geist-mono-nerd",
        category: FontCategory::Mono,
        ligatures: false,
        nerd_font: true,
        description: "Vercel's modern monospace",
    },
    FontEntry {
        name: "CommitMono Nerd Font",
        package: "otf-commit-mono-nerd",
        category: FontCategory::Mono,
        ligatures: false,
        nerd_font: true,
        description: "Neutral, anonymous coding font",
    },
    FontEntry {
        name: "ZedMono Nerd Font",
        package: "ttf-zed-mono-nerd",
        category: FontCategory::Mono,
        ligatures: false,
        nerd_font: true,
        description: "Zed editor's custom font",
    },
];

/// Curated list of recommended sans-serif fonts for UI
const SANS_FONTS: &[FontEntry] = &[
    FontEntry {
        name: "Noto Sans",
        package: "noto-fonts",
        category: FontCategory::Sans,
        ligatures: false,
        nerd_font: false,
        description: "Google's universal font, full Unicode",
    },
    FontEntry {
        name: "Adwaita Sans",
        package: "adwaita-fonts",
        category: FontCategory::Sans,
        ligatures: false,
        nerd_font: false,
        description: "GNOME's default, clean and modern",
    },
    FontEntry {
        name: "Inter",
        package: "inter-font",
        category: FontCategory::Sans,
        ligatures: false,
        nerd_font: false,
        description: "Designed for UI, excellent legibility",
    },
    FontEntry {
        name: "Cantarell",
        package: "cantarell-fonts",
        category: FontCategory::Sans,
        ligatures: false,
        nerd_font: false,
        description: "GNOME legacy, humanist design",
    },
    FontEntry {
        name: "Source Sans 3",
        package: "adobe-source-sans-fonts",
        category: FontCategory::Sans,
        ligatures: false,
        nerd_font: false,
        description: "Adobe's open-source UI font",
    },
    FontEntry {
        name: "Ubuntu",
        package: "ttf-ubuntu-font-family",
        category: FontCategory::Sans,
        ligatures: false,
        nerd_font: false,
        description: "Ubuntu's distinctive branding font",
    },
    FontEntry {
        name: "Roboto",
        package: "ttf-roboto",
        category: FontCategory::Sans,
        ligatures: false,
        nerd_font: false,
        description: "Google's Material Design font",
    },
    FontEntry {
        name: "IBM Plex Sans",
        package: "ttf-ibm-plex",
        category: FontCategory::Sans,
        ligatures: false,
        nerd_font: false,
        description: "IBM's corporate typeface",
    },
];

/// Get installed font families from fc-list
fn get_installed_fonts() -> HashSet<String> {
    let output = Command::new("fc-list")
        .args([":", "family"])
        .output()
        .ok();

    match output {
        Some(out) if out.status.success() => {
            String::from_utf8_lossy(&out.stdout)
                .lines()
                .flat_map(|line| {
                    // fc-list returns "Family1,Alias1,Alias2" format
                    line.split(',').map(|s| s.trim().to_string())
                })
                .collect()
        }
        _ => HashSet::new(),
    }
}

/// Font listing result
pub struct FontListing {
    pub name: &'static str,
    #[allow(dead_code)]
    pub package: &'static str,
    pub installed: bool,
    pub ligatures: bool,
    pub nerd_font: bool,
    pub description: &'static str,
}

/// List fonts with install status
pub fn list_fonts(category: Option<FontCategory>) -> Vec<FontListing> {
    let installed = get_installed_fonts();

    let fonts: &[FontEntry] = match category {
        Some(FontCategory::Mono) => MONO_FONTS,
        Some(FontCategory::Sans) => SANS_FONTS,
        None => {
            // Return combined, we'll handle separately
            let mut result = Vec::new();
            for font in MONO_FONTS {
                result.push(FontListing {
                    name: font.name,
                    package: font.package,
                    installed: installed.contains(font.name),
                    ligatures: font.ligatures,
                    nerd_font: font.nerd_font,
                    description: font.description,
                });
            }
            for font in SANS_FONTS {
                result.push(FontListing {
                    name: font.name,
                    package: font.package,
                    installed: installed.contains(font.name),
                    ligatures: font.ligatures,
                    nerd_font: font.nerd_font,
                    description: font.description,
                });
            }
            return result;
        }
    };

    fonts
        .iter()
        .map(|font| FontListing {
            name: font.name,
            package: font.package,
            installed: installed.contains(font.name),
            ligatures: font.ligatures,
            nerd_font: font.nerd_font,
            description: font.description,
        })
        .collect()
}

/// Check if a font name is valid (exists in our registry)
pub fn is_valid_font(name: &str, category: FontCategory) -> bool {
    let fonts = match category {
        FontCategory::Mono => MONO_FONTS,
        FontCategory::Sans => SANS_FONTS,
    };
    fonts.iter().any(|f| f.name == name)
}

/// Check if a font is installed on the system
pub fn is_font_installed(name: &str) -> bool {
    get_installed_fonts().contains(name)
}

/// Get the font file path using fontconfig
fn get_font_path(font_name: &str) -> Option<String> {
    let output = Command::new("fc-match")
        .args([font_name, "--format=%{file}"])
        .output()
        .ok()?;

    if output.status.success() {
        let path = String::from_utf8_lossy(&output.stdout).trim().to_string();
        if !path.is_empty() {
            return Some(path);
        }
    }
    None
}

/// Render a font sample image using ImageMagick
/// Returns PNG bytes on success
pub fn render_font_sample(font_name: &str, text: &str, size: u32) -> Result<Vec<u8>, String> {
    // Get the actual font file path via fontconfig
    let font_path = get_font_path(font_name)
        .ok_or_else(|| format!("Could not find font file for: {}", font_name))?;

    let output = Command::new("magick")
        .args(["-background", "transparent"])
        .args(["-fill", "white"])
        .args(["-font", &font_path])
        .args(["-pointsize", &size.to_string()])
        .args([&format!("label:{}", text), "png:-"])
        .output()
        .map_err(|e| format!("Failed to run magick: {}", e))?;

    if !output.status.success() {
        return Err(format!(
            "ImageMagick failed: {}",
            String::from_utf8_lossy(&output.stderr)
        ));
    }

    Ok(output.stdout)
}

/// Display an image inline using Kitty graphics protocol
pub fn display_kitty_image(png_bytes: &[u8]) {
    use base64::{engine::general_purpose::STANDARD, Engine};
    let b64 = STANDARD.encode(png_bytes);

    // Kitty graphics protocol: transmit and display inline
    // f=100 means PNG format, a=T means transmit and display
    print!("\x1b_Gf=100,a=T;{}\x1b\\", b64);
}

/// Preview current font at multiple sizes using text sizing protocol (OSC 66)
pub fn preview_font_sizes(font_name: &str) {
    let sample = "The quick brown fox jumps over the lazy dog 0123456789";

    println!("{}", font_name);
    println!();

    // Show at scales 1-4 (1x, 2x, 3x, 4x)
    for scale in 1..=4 {
        print!("\x1b]66;s={};{}\x07  ({}x)", scale, sample, scale);
        // Add newlines proportional to scale height
        for _ in 0..scale {
            println!();
        }
    }
}

/// Preview font with variants (regular, bold, italic, bold-italic)
pub fn preview_font_variants(font_name: &str) {
    let sample = "The quick brown fox jumps over the lazy dog";

    println!("{}", font_name);
    println!();

    // Regular
    println!("Regular:     {}", sample);

    // Bold (ANSI bold)
    println!("Bold:        \x1b[1m{}\x1b[0m", sample);

    // Italic (ANSI italic)
    println!("Italic:      \x1b[3m{}\x1b[0m", sample);

    // Bold Italic
    println!("Bold Italic: \x1b[1;3m{}\x1b[0m", sample);

    // Underline
    println!("Underline:   \x1b[4m{}\x1b[0m", sample);
}
