use std::collections::HashMap;

use ratatui::{
    buffer::Buffer,
    layout::Rect,
    style::{Modifier, Style},
    text::{Line, Span},
    widgets::{Block, Borders, Clear, Paragraph, Scrollbar, ScrollbarOrientation, ScrollbarState, StatefulWidget, Widget},
};
use ratatui_image::{picker::Picker, protocol::StatefulProtocol, Resize, StatefulImage};

use crate::fonts::{self, FontCategory};

/// Sample texts for font preview
pub struct FontSamples;

impl FontSamples {
    /// Short pangram for size previews
    pub const PANGRAM: &'static str = "The quick brown fox jumps";

    /// Full character set - lowercase
    pub const LOWERCASE: &'static str = "abcdefghijklmnopqrstuvwxyz";

    /// Full character set - uppercase
    pub const UPPERCASE: &'static str = "ABCDEFGHIJKLMNOPQRSTUVWXYZ";

    /// Digits
    pub const DIGITS: &'static str = "0123456789";

    /// Common symbols
    pub const SYMBOLS: &'static str = "!@#$%^&*()_+-=[]{}|;':\",./<>?";

    /// Programming ligatures test
    pub const LIGATURES: &'static str = "=> -> <- <-> != !== == === <= >= |>";

    /// Code sample
    pub const CODE: &'static str = "fn main() { let x = 42; }";

    /// Nerd Font glyphs sample (common icons)
    pub const NERD_GLYPHS: &'static str = "\u{f002d} \u{e606} \u{e73c} \u{f0e7} \u{f120} \u{f121} \u{f1d3} \u{f07c} \u{f023} \u{f013}";
}

/// Cache key for rendered images
#[derive(Debug, Clone, PartialEq, Eq, Hash)]
pub struct ImageCacheKey {
    pub size: u32,
    pub text: String,
}

/// State for the font preview modal
pub struct FontPreviewState {
    /// Current scroll offset (in lines)
    pub scroll_offset: usize,
    /// Total content height (for scrollbar)
    pub total_lines: usize,
    /// Visible height
    pub visible_height: usize,
    /// Whether images are still loading
    pub loading: bool,
    /// Cached rendered images (keyed by size + text)
    pub image_cache: HashMap<ImageCacheKey, Vec<u8>>,
    /// Image picker for ratatui-image
    pub picker: Option<Picker>,
    /// Rendered protocol images ready for display
    pub protocols: HashMap<ImageCacheKey, StatefulProtocol>,
}

impl Default for FontPreviewState {
    fn default() -> Self {
        // Try to create a picker, but don't fail if we can't
        let picker = Picker::from_query_stdio().ok();

        Self {
            scroll_offset: 0,
            total_lines: 0,
            visible_height: 0,
            loading: true,
            image_cache: HashMap::new(),
            picker,
            protocols: HashMap::new(),
        }
    }
}

impl FontPreviewState {
    pub fn new() -> Self {
        Self::default()
    }

    pub fn scroll_down(&mut self, amount: usize) {
        let max_scroll = self.total_lines.saturating_sub(self.visible_height);
        self.scroll_offset = (self.scroll_offset + amount).min(max_scroll);
    }

    pub fn scroll_up(&mut self, amount: usize) {
        self.scroll_offset = self.scroll_offset.saturating_sub(amount);
    }

    pub fn scroll_top(&mut self) {
        self.scroll_offset = 0;
    }

    pub fn scroll_bottom(&mut self) {
        self.scroll_offset = self.total_lines.saturating_sub(self.visible_height);
    }

    /// Render a font sample and cache it
    pub fn render_sample(&mut self, font_name: &str, text: &str, size: u32) -> bool {
        let key = ImageCacheKey {
            size,
            text: text.to_string(),
        };

        // Already cached?
        if self.image_cache.contains_key(&key) {
            return true;
        }

        // Try to render
        match fonts::render_font_sample(font_name, text, size) {
            Ok(png_bytes) => {
                // Convert to protocol if we have a picker
                if let Some(ref mut picker) = self.picker {
                    if let Ok(dyn_img) = image::load_from_memory(&png_bytes) {
                        let protocol = picker.new_resize_protocol(dyn_img);
                        self.protocols.insert(key.clone(), protocol);
                    }
                }
                self.image_cache.insert(key, png_bytes);
                true
            }
            Err(_) => false,
        }
    }

    /// Get a protocol for rendering
    pub fn get_protocol(&mut self, size: u32, text: &str) -> Option<&mut StatefulProtocol> {
        let key = ImageCacheKey {
            size,
            text: text.to_string(),
        };
        self.protocols.get_mut(&key)
    }

    /// Check if we have a protocol
    pub fn has_protocol(&self, size: u32, text: &str) -> bool {
        let key = ImageCacheKey {
            size,
            text: text.to_string(),
        };
        self.protocols.contains_key(&key)
    }

}

/// Preview section types - simplified
#[derive(Debug, Clone)]
pub enum PreviewSection {
    /// Size sample (rendered as image)
    SizeSample { size: u32 },
    /// Variants section (rendered as styled text)
    Variants,
    /// Character set section
    CharacterSet { label: &'static str, chars: &'static str },
    /// Section divider with label
    Divider { label: &'static str },
}

/// Font preview modal widget
pub struct FontPreviewModal<'a> {
    /// Font name
    name: &'a str,
    /// Font category
    category: FontCategory,
    /// Whether font is installed
    installed: bool,
    /// Whether font has ligatures
    ligatures: bool,
    /// Whether font is a Nerd Font
    nerd_font: bool,
    /// Preview sections to render
    sections: Vec<PreviewSection>,
    /// Theme styles
    style: Style,
    border_style: Style,
    title_style: Style,
    label_style: Style,
    text_style: Style,
    accent_style: Style,
    dim_style: Style,
}

impl<'a> FontPreviewModal<'a> {
    pub fn new(
        name: &'a str,
        category: FontCategory,
        installed: bool,
        ligatures: bool,
        nerd_font: bool,
    ) -> Self {
        Self {
            name,
            category,
            installed,
            ligatures,
            nerd_font,
            sections: Vec::new(),
            style: Style::default(),
            border_style: Style::default(),
            title_style: Style::default(),
            label_style: Style::default(),
            text_style: Style::default(),
            accent_style: Style::default(),
            dim_style: Style::default(),
        }
    }

    pub fn sections(mut self, sections: Vec<PreviewSection>) -> Self {
        self.sections = sections;
        self
    }

    pub fn style(mut self, style: Style) -> Self {
        self.style = style;
        self
    }

    pub fn border_style(mut self, style: Style) -> Self {
        self.border_style = style;
        self
    }

    pub fn title_style(mut self, style: Style) -> Self {
        self.title_style = style;
        self
    }

    pub fn label_style(mut self, style: Style) -> Self {
        self.label_style = style;
        self
    }

    pub fn text_style(mut self, style: Style) -> Self {
        self.text_style = style;
        self
    }

    pub fn accent_style(mut self, style: Style) -> Self {
        self.accent_style = style;
        self
    }

    pub fn dim_style(mut self, style: Style) -> Self {
        self.dim_style = style;
        self
    }

    /// Build default preview sections for a font
    pub fn build_sections(
        category: FontCategory,
        ligatures: bool,
        nerd_font: bool,
    ) -> Vec<PreviewSection> {
        let mut sections = Vec::new();

        // Size samples section (rendered as images)
        sections.push(PreviewSection::Divider { label: "Sizes" });
        for size in [16, 24, 36, 48] {
            sections.push(PreviewSection::SizeSample { size });
        }

        // Variants section (rendered as styled terminal text)
        sections.push(PreviewSection::Divider { label: "Variants" });
        sections.push(PreviewSection::Variants);

        // Character sets
        sections.push(PreviewSection::Divider { label: "Character Sets" });
        sections.push(PreviewSection::CharacterSet {
            label: "Lowercase",
            chars: FontSamples::LOWERCASE,
        });
        sections.push(PreviewSection::CharacterSet {
            label: "Uppercase",
            chars: FontSamples::UPPERCASE,
        });
        sections.push(PreviewSection::CharacterSet {
            label: "Digits",
            chars: FontSamples::DIGITS,
        });
        sections.push(PreviewSection::CharacterSet {
            label: "Symbols",
            chars: FontSamples::SYMBOLS,
        });

        // Ligatures (only for fonts that support them)
        if ligatures {
            sections.push(PreviewSection::Divider { label: "Ligatures" });
            sections.push(PreviewSection::CharacterSet {
                label: "Common",
                chars: FontSamples::LIGATURES,
            });
        }

        // Code sample (only for mono)
        if category == FontCategory::Mono {
            sections.push(PreviewSection::Divider { label: "Code" });
            sections.push(PreviewSection::CharacterSet {
                label: "Sample",
                chars: FontSamples::CODE,
            });
        }

        // Nerd Font glyphs
        if nerd_font {
            sections.push(PreviewSection::Divider { label: "Nerd Font Icons" });
            sections.push(PreviewSection::CharacterSet {
                label: "Icons",
                chars: FontSamples::NERD_GLYPHS,
            });
        }

        sections
    }
}

impl StatefulWidget for FontPreviewModal<'_> {
    type State = FontPreviewState;

    fn render(self, area: Rect, buf: &mut Buffer, state: &mut Self::State) {
        // Calculate modal dimensions - take up most of the screen
        let width = (area.width - 4).min(100);
        let height = area.height - 4;
        let x = area.x + (area.width.saturating_sub(width)) / 2;
        let y = area.y + 2;
        let modal_area = Rect::new(x, y, width, height);

        // Clear and draw border
        Clear.render(modal_area, buf);

        let category_label = match self.category {
            FontCategory::Mono => "Monospace",
            FontCategory::Sans => "Sans-serif",
        };

        let title = format!(" {} ", self.name);
        let block = Block::default()
            .title(Span::styled(title, self.title_style))
            .borders(Borders::ALL)
            .border_style(self.border_style)
            .style(self.style);

        let inner = block.inner(modal_area);
        block.render(modal_area, buf);

        // Build content lines
        let mut lines: Vec<Line> = Vec::new();

        // Header with metadata badges
        let mut badges = vec![
            Span::styled(category_label, self.label_style),
        ];

        if self.installed {
            badges.push(Span::raw("  "));
            badges.push(Span::styled("✓ Installed", self.accent_style));
        } else {
            badges.push(Span::raw("  "));
            badges.push(Span::styled("✗ Not installed", self.dim_style));
        }

        if self.ligatures {
            badges.push(Span::raw("  "));
            badges.push(Span::styled("lig", self.label_style));
        }

        if self.nerd_font {
            badges.push(Span::raw("  "));
            badges.push(Span::styled("\u{f002d}", self.label_style));
        }

        lines.push(Line::from(badges));
        lines.push(Line::from(""));

        // Render sections
        for section in &self.sections {
            match section {
                PreviewSection::Divider { label } => {
                    lines.push(Line::from(""));
                    lines.push(Line::from(Span::styled(
                        format!("─── {} ───", label),
                        self.label_style.add_modifier(Modifier::BOLD),
                    )));
                    lines.push(Line::from(""));
                }
                PreviewSection::SizeSample { size } => {
                    // Show size label
                    lines.push(Line::from(vec![
                        Span::styled(format!("{}pt: ", size), self.label_style),
                    ]));

                    // Check if we have a rendered image
                    if state.has_protocol(*size, FontSamples::PANGRAM) {
                        // Reserve space for image (estimate based on size)
                        let img_height = (*size as usize / 12).max(1).min(4);
                        for _ in 0..img_height {
                            lines.push(Line::from(""));
                        }
                    } else {
                        // Fallback to text
                        lines.push(Line::from(Span::styled(FontSamples::PANGRAM, self.text_style)));
                    }
                    lines.push(Line::from(""));
                }
                PreviewSection::Variants => {
                    let sample = FontSamples::PANGRAM;

                    // Regular
                    lines.push(Line::from(vec![
                        Span::styled("Regular:     ", self.label_style),
                        Span::styled(sample, self.text_style),
                    ]));

                    // Bold
                    lines.push(Line::from(vec![
                        Span::styled("Bold:        ", self.label_style),
                        Span::styled(sample, self.text_style.add_modifier(Modifier::BOLD)),
                    ]));

                    // Italic
                    lines.push(Line::from(vec![
                        Span::styled("Italic:      ", self.label_style),
                        Span::styled(sample, self.text_style.add_modifier(Modifier::ITALIC)),
                    ]));

                    // Bold Italic
                    lines.push(Line::from(vec![
                        Span::styled("Bold Italic: ", self.label_style),
                        Span::styled(sample, self.text_style
                            .add_modifier(Modifier::BOLD)
                            .add_modifier(Modifier::ITALIC)),
                    ]));

                    lines.push(Line::from(""));
                }
                PreviewSection::CharacterSet { label, chars } => {
                    lines.push(Line::from(vec![
                        Span::styled(format!("{}: ", label), self.label_style),
                    ]));
                    lines.push(Line::from(Span::styled(*chars, self.text_style)));
                    lines.push(Line::from(""));
                }
            }
        }

        // Footer with keybindings
        lines.push(Line::from(""));
        lines.push(Line::from(vec![
            Span::styled("j/k", self.accent_style),
            Span::styled(" scroll  ", self.dim_style),
            Span::styled("g/G", self.accent_style),
            Span::styled(" top/bottom  ", self.dim_style),
            Span::styled("y", self.accent_style),
            Span::styled(" copy  ", self.dim_style),
            Span::styled("Esc", self.accent_style),
            Span::styled(" close", self.dim_style),
        ]));

        // Update state
        state.total_lines = lines.len();
        state.visible_height = inner.height as usize;

        // Apply scroll offset
        let visible_lines: Vec<Line> = lines
            .into_iter()
            .skip(state.scroll_offset)
            .take(state.visible_height)
            .collect();

        let paragraph = Paragraph::new(visible_lines);
        paragraph.render(inner, buf);

        // Render scrollbar if needed
        if state.total_lines > state.visible_height {
            let scrollbar = Scrollbar::new(ScrollbarOrientation::VerticalRight)
                .style(self.border_style);
            let mut scrollbar_state = ScrollbarState::new(state.total_lines)
                .position(state.scroll_offset);
            scrollbar.render(
                modal_area.inner(ratatui::layout::Margin { horizontal: 0, vertical: 1 }),
                buf,
                &mut scrollbar_state,
            );
        }

        // Now render images on top of text placeholders
        // We need to calculate the actual positions based on scroll
        let mut line_idx = 0;

        for section in &self.sections {
            if line_idx >= state.scroll_offset + state.visible_height {
                break;
            }

            match section {
                PreviewSection::Divider { .. } => {
                    line_idx += 3; // Empty line + divider + empty line
                }
                PreviewSection::SizeSample { size } => {
                    line_idx += 1; // Label line

                    // If this section is visible
                    if line_idx > state.scroll_offset && line_idx < state.scroll_offset + state.visible_height {
                        let visible_y = inner.y + (line_idx - state.scroll_offset) as u16;
                        let img_height = (*size as u16 / 12).max(1).min(4);

                        // Try to render image
                        if let Some(protocol) = state.get_protocol(*size, FontSamples::PANGRAM) {
                            let img_area = Rect::new(inner.x, visible_y, inner.width, img_height);
                            let img_widget = StatefulImage::default().resize(Resize::Fit(None));
                            img_widget.render(img_area, buf, protocol);
                        }
                    }

                    let img_height = (*size as usize / 12).max(1).min(4);
                    line_idx += img_height + 1; // Image space + empty line
                }
                PreviewSection::Variants => {
                    line_idx += 5; // 4 variants + empty line
                }
                PreviewSection::CharacterSet { .. } => {
                    line_idx += 3; // Label + chars + empty line
                }
            }
        }
    }
}
