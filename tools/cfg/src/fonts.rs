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
    pub category: FontCategory,
    /// Has programming ligatures
    pub ligatures: bool,
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
        description: "JetBrains IDE font, excellent readability",
    },
    FontEntry {
        name: "FiraCode Nerd Font",
        package: "ttf-firacode-nerd",
        category: FontCategory::Mono,
        ligatures: true,
        description: "Mozilla's monospace with rich ligatures",
    },
    FontEntry {
        name: "CaskaydiaCove Nerd Font",
        package: "ttf-cascadia-code-nerd",
        category: FontCategory::Mono,
        ligatures: true,
        description: "Microsoft's Windows Terminal font",
    },
    FontEntry {
        name: "Hack Nerd Font",
        package: "ttf-hack-nerd",
        category: FontCategory::Mono,
        ligatures: false,
        description: "Classic coding font, large x-height",
    },
    FontEntry {
        name: "Iosevka Nerd Font",
        package: "ttf-iosevka-nerd",
        category: FontCategory::Mono,
        ligatures: true,
        description: "Narrow, customizable, many variants",
    },
    FontEntry {
        name: "VictorMono Nerd Font",
        package: "ttf-victor-mono-nerd",
        category: FontCategory::Mono,
        ligatures: true,
        description: "Cursive italics, clean ligatures",
    },
    FontEntry {
        name: "SourceCodePro Nerd Font",
        package: "ttf-sourcecodepro-nerd",
        category: FontCategory::Mono,
        ligatures: false,
        description: "Adobe's coding font, balanced design",
    },
    FontEntry {
        name: "Hasklug Nerd Font",
        package: "otf-hasklig-nerd",
        category: FontCategory::Mono,
        ligatures: true,
        description: "Source Code Pro + Haskell ligatures",
    },
    FontEntry {
        name: "UbuntuMono Nerd Font",
        package: "ttf-ubuntu-mono-nerd",
        category: FontCategory::Mono,
        ligatures: false,
        description: "Ubuntu's distinctive monospace",
    },
    FontEntry {
        name: "RobotoMono Nerd Font",
        package: "ttf-roboto-mono-nerd",
        category: FontCategory::Mono,
        ligatures: false,
        description: "Google's geometric monospace",
    },
    FontEntry {
        name: "Mononoki Nerd Font",
        package: "ttf-mononoki-nerd",
        category: FontCategory::Mono,
        ligatures: false,
        description: "Minimal, easy on the eyes",
    },
    FontEntry {
        name: "GeistMono Nerd Font",
        package: "otf-geist-mono-nerd",
        category: FontCategory::Mono,
        ligatures: false,
        description: "Vercel's modern monospace",
    },
    FontEntry {
        name: "CommitMono Nerd Font",
        package: "otf-commit-mono-nerd",
        category: FontCategory::Mono,
        ligatures: false,
        description: "Neutral, anonymous coding font",
    },
    FontEntry {
        name: "Monaspace Nerd Font",
        package: "otf-monaspace-nerd",
        category: FontCategory::Mono,
        ligatures: true,
        description: "GitHub's 5 stylistic variants",
    },
    FontEntry {
        name: "ZedMono Nerd Font",
        package: "ttf-zed-mono-nerd",
        category: FontCategory::Mono,
        ligatures: false,
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
        description: "Google's universal font, full Unicode",
    },
    FontEntry {
        name: "Adwaita Sans",
        package: "adwaita-fonts",
        category: FontCategory::Sans,
        ligatures: false,
        description: "GNOME's default, clean and modern",
    },
    FontEntry {
        name: "Inter",
        package: "inter-font",
        category: FontCategory::Sans,
        ligatures: false,
        description: "Designed for UI, excellent legibility",
    },
    FontEntry {
        name: "Cantarell",
        package: "cantarell-fonts",
        category: FontCategory::Sans,
        ligatures: false,
        description: "GNOME legacy, humanist design",
    },
    FontEntry {
        name: "Source Sans 3",
        package: "adobe-source-sans-fonts",
        category: FontCategory::Sans,
        ligatures: false,
        description: "Adobe's open-source UI font",
    },
    FontEntry {
        name: "Ubuntu",
        package: "ttf-ubuntu-font-family",
        category: FontCategory::Sans,
        ligatures: false,
        description: "Ubuntu's distinctive branding font",
    },
    FontEntry {
        name: "Roboto",
        package: "ttf-roboto",
        category: FontCategory::Sans,
        ligatures: false,
        description: "Google's Material Design font",
    },
    FontEntry {
        name: "IBM Plex Sans",
        package: "ttf-ibm-plex",
        category: FontCategory::Sans,
        ligatures: false,
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
    pub package: &'static str,
    pub installed: bool,
    pub ligatures: bool,
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
                    description: font.description,
                });
            }
            for font in SANS_FONTS {
                result.push(FontListing {
                    name: font.name,
                    package: font.package,
                    installed: installed.contains(font.name),
                    ligatures: font.ligatures,
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
