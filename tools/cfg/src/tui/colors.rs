use std::io;

use crossterm::event::{self, Event, KeyCode, KeyEventKind, KeyModifiers, MouseEventKind};
use ratatui::{
    layout::{Constraint, Direction, Layout, Rect},
    style::{Color, Modifier, Style},
    text::{Line, Span},
    widgets::{Block, Borders, Clear, List, ListItem, ListState, Paragraph, Scrollbar, ScrollbarOrientation, ScrollbarState},
    Frame,
};

use crate::color::{format_color, Color as CfgColor};
use crate::config::Config;
use crate::palette::Palette;

use super::clipboard;
use super::widgets::{FuzzyInput, FuzzyInputState, HelpPopup, Toast};
use super::{init, restore};

/// Color formats supported by the picker
const FORMATS: &[&str] = &["hex-hash", "hex", "rgb", "rgb-css", "hyprlang", "tera"];

/// Human-readable format labels
const FORMAT_LABELS: &[(&str, &str)] = &[
    ("hex-hash", "hex"),
    ("hex", "hex (no #)"),
    ("rgb", "rgb"),
    ("rgb-css", "rgb()"),
    ("hyprlang", "hyprlang"),
    ("tera", "tera"),
];

fn format_label(fmt: &str) -> &'static str {
    FORMAT_LABELS
        .iter()
        .find(|(k, _)| *k == fmt)
        .map(|(_, v)| *v)
        .unwrap_or("unknown")
}

/// Accent colors (can be set as accent/secondary)
const ACCENT_COLORS: &[&str] = &[
    "rosewater", "flamingo", "pink", "mauve", "red", "maroon",
    "peach", "yellow", "green", "teal", "sky", "sapphire", "blue", "lavender",
];

/// Surface/text colors
const SURFACE_COLORS: &[&str] = &[
    "text", "subtext1", "subtext0",
    "overlay2", "overlay1", "overlay0",
    "surface2", "surface1", "surface0",
    "base", "mantle", "crust",
];

#[derive(Debug, Clone)]
struct ColorEntry {
    name: String,
    color: CfgColor,
    is_accent: bool,
}

#[derive(Debug, Clone, Copy, PartialEq)]
enum Mode {
    Normal,
    Search,
    Help,
    Confirm,
}

/// Which pane has focus
#[derive(Debug, Clone, Copy, PartialEq, Default)]
enum Focus {
    #[default]
    List,
    Preview,
}

/// Color modification state (layered like Photoshop)
#[derive(Debug, Clone, Default)]
struct ColorModifier {
    /// Blend with another color (0 = no blend, 100 = full blend target)
    blend_amount: u8,
    /// Lightness adjustment (-100 = full darken, 0 = neutral, +100 = full lighten)
    lightness: i8,
}

pub struct ColorPicker {
    colors: Vec<ColorEntry>,
    filtered: Vec<usize>,
    selected: usize,
    list_state: ListState,
    search: FuzzyInputState,
    format_idx: usize,
    mode: Mode,
    toast: Option<Toast>,
    config: Config,
    config_path: String,
    /// Catppuccin flavor colors for theming
    flavor_colors: FlavorTheme,
    should_apply: bool,
    /// Original config values to detect changes
    original_accent: String,
    original_secondary: String,
    /// Content area for mouse click detection
    content_area: Rect,
    /// Maps visual row index to filtered data index (for mouse clicks)
    row_to_data: Vec<Option<usize>>,
    /// Color modifier state (blend + lightness)
    modifier: ColorModifier,
    /// Input buffer for typing values directly
    modifier_input: String,
    /// Track last selected index to detect changes
    last_selected: usize,
    /// Which pane has focus
    focus: Focus,
    /// Secondary selection for blend target (index into filtered)
    blend_selection: usize,
    /// Which control is active in Modify pane: 0=lightness, 1=blend
    modify_focus: usize,
    /// Preview pane area for mouse detection
    preview_area: Rect,
    /// Row positions for modifier controls (for mouse click detection)
    lightness_row: u16,
    blend_row: u16,
}

/// Theme colors from catppuccin for UI rendering
struct FlavorTheme {
    base: Color,
    surface0: Color,
    surface1: Color,
    overlay0: Color,
    overlay1: Color,
    text: Color,
    subtext0: Color,
    green: Color,
    accent: Color,
}

impl FlavorTheme {
    fn from_config(config: &Config, palette: &Palette) -> Self {
        let get_color = |name: &str| -> Color {
            palette.get(name)
                .map(|c| Color::Rgb(c.r, c.g, c.b))
                .unwrap_or(Color::White)
        };

        Self {
            base: get_color("base"),
            surface0: get_color("surface0"),
            surface1: get_color("surface1"),
            overlay0: get_color("overlay0"),
            overlay1: get_color("overlay1"),
            text: get_color("text"),
            subtext0: get_color("subtext0"),
            green: get_color("green"),
            accent: get_color(&config.accent),
        }
    }
}

impl ColorPicker {
    pub fn new(config: Config, palette: &Palette, config_path: String) -> Self {
        let flavor_colors = FlavorTheme::from_config(&config, palette);

        // Build color entries in order
        let mut colors = Vec::new();

        // Accent colors first
        for name in ACCENT_COLORS {
            if let Some(c) = palette.get(name) {
                colors.push(ColorEntry {
                    name: name.to_string(),
                    color: *c,
                    is_accent: true,
                });
            }
        }

        // Surface colors
        for name in SURFACE_COLORS {
            if let Some(c) = palette.get(name) {
                colors.push(ColorEntry {
                    name: name.to_string(),
                    color: *c,
                    is_accent: false,
                });
            }
        }

        let filtered: Vec<usize> = (0..colors.len()).collect();
        let mut list_state = ListState::default();
        list_state.select(Some(0));

        let original_accent = config.accent.clone();
        let original_secondary = config.secondary.clone();

        Self {
            colors,
            filtered,
            selected: 0,
            list_state,
            search: FuzzyInputState::new(),
            format_idx: 0,
            mode: Mode::Normal,
            toast: None,
            config,
            config_path,
            flavor_colors,
            should_apply: false,
            original_accent,
            original_secondary,
            content_area: Rect::default(),
            row_to_data: Vec::new(),
            modifier: ColorModifier::default(),
            modifier_input: String::new(),
            last_selected: 0,
            focus: Focus::List,
            blend_selection: 1, // Start at second color
            modify_focus: 0, // Start on lightness control
            preview_area: Rect::default(),
            lightness_row: 0,
            blend_row: 0,
        }
    }

    fn has_changes(&self) -> bool {
        self.config.accent != self.original_accent
            || self.config.secondary != self.original_secondary
    }

    fn current_format(&self) -> &str {
        FORMATS[self.format_idx]
    }

    fn selected_color(&self) -> Option<&ColorEntry> {
        self.filtered.get(self.selected).and_then(|&i| self.colors.get(i))
    }

    /// Get the blend target color (from filtered list via blend_selection)
    fn blend_target(&self) -> Option<&ColorEntry> {
        self.filtered.get(self.blend_selection)
            .and_then(|&i| self.colors.get(i))
    }

    /// Check if any modifications are applied
    fn has_modifications(&self) -> bool {
        self.modifier.lightness != 0 || self.modifier.blend_amount > 0
    }

    /// Compute the modified color based on current modifier settings
    /// Order: blend first, then lightness adjustment
    fn modified_color(&self) -> Option<CfgColor> {
        let entry = self.selected_color()?;
        let mut color = entry.color;

        // Step 1: Blend with target color
        if self.modifier.blend_amount > 0 {
            if let Some(target) = self.blend_target() {
                color = color.blend(&target.color, 100 - self.modifier.blend_amount);
            }
        }

        // Step 2: Apply lightness adjustment
        if self.modifier.lightness > 0 {
            color = color.lighten(self.modifier.lightness as u8);
        } else if self.modifier.lightness < 0 {
            color = color.darken((-self.modifier.lightness) as u8);
        }

        Some(color)
    }

    /// Generate tera template filter string for current modifications
    fn tera_filter_string(&self) -> Option<String> {
        let entry = self.selected_color()?;
        let name = &entry.name;

        if !self.has_modifications() {
            return Some(format!("{{{{ {} }}}}", name));
        }

        let mut filters = Vec::new();

        // Blend filter
        if self.modifier.blend_amount > 0 {
            if let Some(target) = self.blend_target() {
                filters.push(format!("blend(base={}, amount={})", target.name, self.modifier.blend_amount));
            }
        }

        // Lightness filter
        if self.modifier.lightness > 0 {
            filters.push(format!("lighten(amount={})", self.modifier.lightness));
        } else if self.modifier.lightness < 0 {
            filters.push(format!("darken(amount={})", -self.modifier.lightness));
        }

        if filters.is_empty() {
            Some(format!("{{{{ {} }}}}", name))
        } else {
            Some(format!("{{{{ {} | {} }}}}", name, filters.join(" | ")))
        }
    }

    /// Move blend selection up
    fn blend_select_up(&mut self) {
        if !self.filtered.is_empty() && self.blend_selection > 0 {
            self.blend_selection -= 1;
        }
    }

    /// Move blend selection down
    fn blend_select_down(&mut self) {
        if !self.filtered.is_empty() && self.blend_selection < self.filtered.len() - 1 {
            self.blend_selection += 1;
        }
    }

    /// Reset modifier state (called when selection changes)
    fn reset_modifier(&mut self) {
        self.modifier = ColorModifier::default();
        self.modifier_input.clear();
    }

    /// Adjust lightness by step
    fn adjust_lightness(&mut self, delta: i8) {
        self.modifier.lightness = self.modifier.lightness.saturating_add(delta).clamp(-100, 100);
        self.modifier_input.clear();
    }

    /// Adjust blend amount by step
    fn adjust_blend(&mut self, delta: i8) {
        let new_val = (self.modifier.blend_amount as i16 + delta as i16).clamp(0, 100) as u8;
        self.modifier.blend_amount = new_val;
        self.modifier_input.clear();
    }

    /// Handle digit input for direct value entry
    fn handle_amount_digit(&mut self, digit: char) {
        self.modifier_input.push(digit);

        // Parse the accumulated input
        if let Ok(value) = self.modifier_input.parse::<i32>() {
            if self.modify_focus == 0 {
                // Lightness: allow negative via - prefix, clamp to -100..100
                // For now, typed values are positive, use +/- for sign
                self.modifier.lightness = (value.clamp(-100, 100)) as i8;
            } else {
                // Blend: 0-100
                self.modifier.blend_amount = (value.clamp(0, 100)) as u8;
            }
        }

        // Reset input after 3 digits to allow fresh entry
        if self.modifier_input.len() >= 3 {
            self.modifier_input.clear();
        }
    }

    fn update_filter(&mut self) {
        if self.search.is_empty() {
            self.filtered = (0..self.colors.len()).collect();
        } else {
            let results = self.search.filter(&self.colors, |c| &c.name);
            self.filtered = results.into_iter().map(|(i, _)| i).collect();
        }
        self.selected = 0;
        self.list_state.select(Some(0));
    }

    fn move_up(&mut self) {
        if !self.filtered.is_empty() && self.selected > 0 {
            self.selected -= 1;
            self.list_state.select(Some(self.selected));
        }
    }

    fn move_down(&mut self) {
        if !self.filtered.is_empty() && self.selected < self.filtered.len() - 1 {
            self.selected += 1;
            self.list_state.select(Some(self.selected));
        }
    }

    fn move_top(&mut self) {
        self.selected = 0;
        self.list_state.select(Some(0));
    }

    fn move_bottom(&mut self) {
        if !self.filtered.is_empty() {
            self.selected = self.filtered.len() - 1;
            self.list_state.select(Some(self.selected));
        }
    }

    fn page_down(&mut self, page_size: usize) {
        if !self.filtered.is_empty() {
            self.selected = (self.selected + page_size).min(self.filtered.len() - 1);
            self.list_state.select(Some(self.selected));
        }
    }

    fn page_up(&mut self, page_size: usize) {
        self.selected = self.selected.saturating_sub(page_size);
        self.list_state.select(Some(self.selected));
    }

    fn copy_selected(&mut self) {
        if let Some(color) = self.modified_color() {
            let formatted = if self.current_format() == "tera" {
                self.tera_filter_string().unwrap_or_default()
            } else {
                format_color(&color, self.current_format(), 1.0)
            };
            clipboard::copy(&formatted);
            self.toast = Some(Toast::new(format!("Copied: {}", formatted))
                .style(Style::default().fg(self.flavor_colors.green))
                .border_style(Style::default().fg(self.flavor_colors.green)));
        }
    }

    fn select_as_accent(&mut self) {
        if let Some(entry) = self.selected_color() {
            if entry.is_accent {
                self.config.accent = entry.name.clone();
            }
        }
    }

    fn render(&mut self, frame: &mut Frame) {
        let theme = &self.flavor_colors;
        let area = frame.area();

        frame.render_widget(Clear, area);
        frame.render_widget(
            Block::default().style(Style::default().bg(theme.base)),
            area,
        );

        let chunks = Layout::default()
            .direction(Direction::Vertical)
            .constraints([
                Constraint::Length(3),
                Constraint::Min(10),
                Constraint::Length(1),
            ])
            .split(area);

        self.render_header(frame, chunks[0]);
        self.content_area = chunks[1];
        self.render_content(frame, chunks[1]);
        self.render_footer(frame, chunks[2]);

        if let Some(ref toast) = self.toast {
            if !toast.is_expired() {
                frame.render_widget(toast.clone(), area);
            } else {
                self.toast = None;
            }
        }

        if self.mode == Mode::Help {
            self.render_help(frame, area);
        }

        if self.mode == Mode::Confirm {
            self.render_confirm(frame, area);
        }
    }

    fn render_header(&mut self, frame: &mut Frame, area: Rect) {
        let theme = &self.flavor_colors;
        let block = Block::default()
            .borders(Borders::ALL)
            .border_style(Style::default().fg(theme.surface1))
            .title(Span::styled(
                format!(" cfg theme  {} ", self.config.flavor),
                Style::default().fg(theme.accent).add_modifier(Modifier::BOLD),
            ));

        let inner = block.inner(area);
        frame.render_widget(block, area);

        let search_widget = FuzzyInput::default()
            .style(Style::default().fg(theme.text))
            .cursor_style(Style::default().fg(theme.base).bg(theme.text))
            .border_style(Style::default().fg(theme.overlay1));

        frame.render_stateful_widget(search_widget, inner, &mut self.search);
    }

    /// Check if we should use wide (3-column) layout
    fn is_wide_layout(&self, width: u16) -> bool {
        width >= 120
    }

    fn render_content(&mut self, frame: &mut Frame, area: Rect) {
        if self.is_wide_layout(area.width) {
            // Wide layout: Colors | Modify | Preview
            let chunks = Layout::default()
                .direction(Direction::Horizontal)
                .constraints([
                    Constraint::Percentage(40),
                    Constraint::Percentage(30),
                    Constraint::Percentage(30),
                ])
                .split(area);

            self.render_color_list(frame, chunks[0]);
            self.render_modify_pane(frame, chunks[1]);
            self.render_swatch_column(frame, chunks[2]);
        } else {
            // Normal layout: Colors | Preview+Modify combined
            let chunks = Layout::default()
                .direction(Direction::Horizontal)
                .constraints([Constraint::Percentage(65), Constraint::Percentage(35)])
                .split(area);

            self.render_color_list(frame, chunks[0]);
            self.render_preview(frame, chunks[1]);
        }
    }

    fn render_color_list(&mut self, frame: &mut Frame, area: Rect) {
        let theme = &self.flavor_colors;
        let border_color = if self.focus == Focus::List { theme.accent } else { theme.surface1 };
        let block = Block::default()
            .borders(Borders::ALL)
            .border_style(Style::default().fg(border_color))
            .title(if self.focus == Focus::List {
                Span::styled(" Colors ", Style::default().fg(theme.accent))
            } else {
                Span::styled(" Colors ", Style::default().fg(theme.overlay1))
            });

        let inner = block.inner(area);
        frame.render_widget(block, area);

        let mut items: Vec<ListItem> = Vec::new();
        let mut prev_is_accent = true;

        // Clear and rebuild row-to-data mapping for mouse clicks
        self.row_to_data.clear();

        for (idx, &color_idx) in self.filtered.iter().enumerate() {
            let entry = &self.colors[color_idx];

            if prev_is_accent && !entry.is_accent && idx > 0 {
                // Empty line before "Surface Colors" header
                items.push(ListItem::new(Line::from("")));
                self.row_to_data.push(None);
                // "Surface Colors" header
                items.push(ListItem::new(Line::from(Span::styled(
                    "Surface Colors",
                    Style::default().fg(theme.overlay1).add_modifier(Modifier::BOLD),
                ))));
                self.row_to_data.push(None);
            } else if entry.is_accent && idx == 0 {
                // "Accent Colors" header
                items.push(ListItem::new(Line::from(Span::styled(
                    "Accent Colors",
                    Style::default().fg(theme.overlay1).add_modifier(Modifier::BOLD),
                ))));
                self.row_to_data.push(None);
            }
            prev_is_accent = entry.is_accent;

            let c = &entry.color;
            let swatch_color = Color::Rgb(c.r, c.g, c.b);
            let is_current = entry.name == self.config.accent || entry.name == self.config.secondary;
            let is_selected = idx == self.selected;
            let is_blend_target = self.modifier.blend_amount > 0 && idx == self.blend_selection;

            // Show selection indicator: > for primary, » for blend target
            let indicator = if is_selected {
                Span::styled("> ", Style::default().fg(theme.accent))
            } else if is_blend_target {
                Span::styled("» ", Style::default().fg(theme.green))
            } else {
                Span::raw("  ")
            };

            let mut spans = vec![
                indicator,
                Span::styled("██", Style::default().fg(swatch_color)),
                Span::raw(" "),
            ];

            let name_style = if is_current {
                Style::default().fg(theme.accent).add_modifier(Modifier::BOLD)
            } else {
                Style::default().fg(theme.text)
            };

            if self.search.is_empty() {
                spans.push(Span::styled(format!("{:<12}", entry.name), name_style));
            } else {
                let highlight_style = name_style.fg(theme.accent).add_modifier(Modifier::BOLD);
                let highlighted = self.search.highlight(&entry.name, name_style, highlight_style);
                for span in highlighted.spans {
                    spans.push(span);
                }
                let padding = 12usize.saturating_sub(entry.name.len());
                spans.push(Span::raw(" ".repeat(padding)));
            }

            spans.push(Span::styled(
                format_color(c, "hex-hash", 1.0),
                Style::default().fg(theme.subtext0),
            ));

            if entry.name == self.config.accent {
                spans.push(Span::styled(" ← accent", Style::default().fg(theme.overlay1)));
            } else if entry.name == self.config.secondary {
                spans.push(Span::styled(" ← secondary", Style::default().fg(theme.overlay1)));
            }

            let style = if is_selected {
                Style::default().bg(theme.surface0)
            } else if is_blend_target {
                Style::default().bg(theme.surface0)
            } else {
                Style::default()
            };

            items.push(ListItem::new(Line::from(spans)).style(style));
            // Map this visual row to the data index
            self.row_to_data.push(Some(idx));
        }

        let list = List::new(items);
        frame.render_stateful_widget(list, inner, &mut self.list_state);

        if self.filtered.len() > inner.height as usize {
            let scrollbar = Scrollbar::new(ScrollbarOrientation::VerticalRight)
                .style(Style::default().fg(theme.surface1));
            let mut scrollbar_state = ScrollbarState::new(self.filtered.len())
                .position(self.selected);
            frame.render_stateful_widget(
                scrollbar,
                area.inner(ratatui::layout::Margin { horizontal: 0, vertical: 1 }),
                &mut scrollbar_state,
            );
        }
    }

    fn render_preview(&mut self, frame: &mut Frame, area: Rect) {
        // Store preview area for mouse detection
        self.preview_area = area;

        let theme = &self.flavor_colors;
        let border_color = if self.focus == Focus::Preview { theme.accent } else { theme.surface1 };
        let block = Block::default()
            .borders(Borders::ALL)
            .border_style(Style::default().fg(border_color))
            .title(if self.focus == Focus::Preview {
                Span::styled(" Modify ", Style::default().fg(theme.accent))
            } else {
                Span::styled(" Preview ", Style::default().fg(theme.overlay1))
            });

        let inner = block.inner(area);
        frame.render_widget(block, area);

        // Copy data to avoid borrow issues with self mutation
        let entry_data = self.selected_color().map(|e| (e.name.clone(), e.color));
        let modified = self.modified_color();
        let blend_target_data = self.blend_target().map(|t| (t.name.clone(), t.color));
        let tera_string = self.tera_filter_string();

        if let Some((entry_name, original)) = entry_data {
            let modified = modified.unwrap_or(original);
            let orig_swatch = Color::Rgb(original.r, original.g, original.b);
            let mod_swatch = Color::Rgb(modified.r, modified.g, modified.b);

            let has_modifier = self.has_modifications();

            let mut lines = vec![Line::from("")];
            let mut line_count = 1u16;

            // Side-by-side swatches when modifier active
            if has_modifier {
                // Calculate swatch width to fill available space
                let available_width = inner.width.saturating_sub(2) as usize; // -2 for gap
                let swatch_width = available_width / 2;
                let swatch_str: String = "█".repeat(swatch_width);

                // Larger swatches side by side (3 rows)
                for _ in 0..3 {
                    lines.push(Line::from(vec![
                        Span::styled(swatch_str.clone(), Style::default().fg(orig_swatch)),
                        Span::raw("  "),
                        Span::styled(swatch_str.clone(), Style::default().fg(mod_swatch)),
                    ]));
                }
                lines.push(Line::from(""));
                line_count += 4;

                // Show modification summary
                let mut mod_parts = Vec::new();
                if self.modifier.blend_amount > 0 {
                    if let Some((ref target_name, _)) = blend_target_data {
                        mod_parts.push(format!("→{} {}%", target_name, self.modifier.blend_amount));
                    }
                }
                if self.modifier.lightness != 0 {
                    mod_parts.push(format!("{:+}%", self.modifier.lightness));
                }
                lines.push(Line::from(vec![
                    Span::styled(&entry_name, Style::default().fg(theme.subtext0)),
                    Span::raw("  "),
                    Span::styled(mod_parts.join(" "), Style::default().fg(theme.accent)),
                ]));
                line_count += 1;
            } else {
                // Large single swatch when no modifier - full width
                let swatch_width = inner.width as usize;
                let swatch_str: String = "█".repeat(swatch_width);

                for _ in 0..3 {
                    lines.push(Line::from(Span::styled(swatch_str.clone(), Style::default().fg(orig_swatch))));
                }
                lines.push(Line::from(""));
                lines.push(Line::from(Span::styled(
                    entry_name.clone(),
                    Style::default().fg(theme.text).add_modifier(Modifier::BOLD),
                )));
                line_count += 5;
            }

            lines.push(Line::from(""));
            line_count += 1;

            // Formats section header
            lines.push(Line::from(Span::styled(
                "─── Formats ───",
                Style::default().fg(theme.surface1),
            )));
            line_count += 1;

            // Show format values for the MODIFIED color
            let display_color = if has_modifier { &modified } else { &original };
            for (i, fmt) in FORMATS.iter().enumerate() {
                let value = if *fmt == "tera" {
                    tera_string.clone().unwrap_or_default()
                } else {
                    format_color(display_color, fmt, 1.0)
                };
                let is_selected = i == self.format_idx;
                let label_style = Style::default().fg(theme.overlay1);
                let value_style = if is_selected {
                    Style::default().fg(theme.accent).add_modifier(Modifier::BOLD)
                } else {
                    Style::default().fg(theme.subtext0)
                };
                lines.push(Line::from(vec![
                    Span::styled(format!("{}: ", format_label(fmt)), label_style),
                    Span::styled(value, value_style),
                ]));
                line_count += 1;
            }

            lines.push(Line::from(""));
            line_count += 1;

            // Modifier controls section
            lines.push(Line::from(Span::styled(
                "─── Modify ───",
                Style::default().fg(theme.surface1),
            )));
            line_count += 1;

            // Track lightness control row (relative to inner area)
            self.lightness_row = inner.y + line_count;

            // Lightness dial (-100 to +100)
            let lightness_focused = self.focus == Focus::Preview && self.modify_focus == 0;
            let lightness_label = if lightness_focused {
                Span::styled("Lightness: ", Style::default().fg(theme.accent))
            } else {
                Span::styled("Lightness: ", Style::default().fg(theme.overlay1))
            };
            let lightness_bar = self.render_dial(self.modifier.lightness, lightness_focused, theme);
            lines.push(Line::from(vec![
                lightness_label,
                Span::styled(
                    format!("{:+4}", self.modifier.lightness),
                    Style::default().fg(theme.text).add_modifier(Modifier::BOLD),
                ),
            ]));
            lines.push(lightness_bar);
            line_count += 2;

            lines.push(Line::from(""));
            line_count += 1;

            // Track blend control row
            self.blend_row = inner.y + line_count;

            // Blend control (0 to 100)
            let blend_focused = self.focus == Focus::Preview && self.modify_focus == 1;
            let blend_label = if blend_focused {
                Span::styled("Blend:     ", Style::default().fg(theme.accent))
            } else {
                Span::styled("Blend:     ", Style::default().fg(theme.overlay1))
            };
            let blend_bar = self.render_slider(self.modifier.blend_amount, blend_focused, theme);
            lines.push(Line::from(vec![
                blend_label,
                Span::styled(
                    format!("{:>3}%", self.modifier.blend_amount),
                    Style::default().fg(theme.text).add_modifier(Modifier::BOLD),
                ),
            ]));
            lines.push(blend_bar);

            // Show blend target if blend amount > 0
            if self.modifier.blend_amount > 0 {
                let (target_name, target_color) = match &blend_target_data {
                    Some((name, color)) => (name.as_str(), Color::Rgb(color.r, color.g, color.b)),
                    None => ("none", theme.text),
                };
                lines.push(Line::from(vec![
                    Span::styled("  Target:  ", Style::default().fg(theme.overlay1)),
                    Span::styled("██", Style::default().fg(target_color)),
                    Span::raw(" "),
                    Span::styled(target_name.to_string(), Style::default().fg(theme.text)),
                    Span::styled(" (» in list)", Style::default().fg(theme.overlay0)),
                ]));
            }

            let para = Paragraph::new(lines);
            frame.render_widget(para, inner);
        }
    }

    /// Render modify pane (controls only, for wide layout)
    fn render_modify_pane(&mut self, frame: &mut Frame, area: Rect) {
        // Store preview area for mouse detection (same as regular preview)
        self.preview_area = area;

        let theme = &self.flavor_colors;
        let border_color = if self.focus == Focus::Preview { theme.accent } else { theme.surface1 };
        let block = Block::default()
            .borders(Borders::ALL)
            .border_style(Style::default().fg(border_color))
            .title(if self.focus == Focus::Preview {
                Span::styled(" Modify ", Style::default().fg(theme.accent))
            } else {
                Span::styled(" Modify ", Style::default().fg(theme.overlay1))
            });

        let inner = block.inner(area);
        frame.render_widget(block, area);

        // Copy data to avoid borrow issues
        let entry_data = self.selected_color().map(|e| (e.name.clone(), e.color));
        let modified = self.modified_color();
        let blend_target_data = self.blend_target().map(|t| (t.name.clone(), t.color));
        let tera_string = self.tera_filter_string();

        if let Some((entry_name, original)) = entry_data {
            let modified = modified.unwrap_or(original);
            let has_modifier = self.has_modifications();

            let mut lines = vec![Line::from("")];
            let mut line_count = 1u16;

            // Color name and modification summary
            if has_modifier {
                let mut mod_parts = Vec::new();
                if self.modifier.blend_amount > 0 {
                    if let Some((ref target_name, _)) = blend_target_data {
                        mod_parts.push(format!("→{} {}%", target_name, self.modifier.blend_amount));
                    }
                }
                if self.modifier.lightness != 0 {
                    mod_parts.push(format!("{:+}%", self.modifier.lightness));
                }
                lines.push(Line::from(vec![
                    Span::styled(&entry_name, Style::default().fg(theme.text).add_modifier(Modifier::BOLD)),
                    Span::raw("  "),
                    Span::styled(mod_parts.join(" "), Style::default().fg(theme.accent)),
                ]));
            } else {
                lines.push(Line::from(Span::styled(
                    entry_name.clone(),
                    Style::default().fg(theme.text).add_modifier(Modifier::BOLD),
                )));
            }
            line_count += 1;

            lines.push(Line::from(""));
            line_count += 1;

            // Formats section header
            lines.push(Line::from(Span::styled(
                "─── Formats ───",
                Style::default().fg(theme.surface1),
            )));
            line_count += 1;

            // Show format values for the MODIFIED color
            let display_color = if has_modifier { &modified } else { &original };
            for (i, fmt) in FORMATS.iter().enumerate() {
                let value = if *fmt == "tera" {
                    tera_string.clone().unwrap_or_default()
                } else {
                    format_color(display_color, fmt, 1.0)
                };
                let is_selected = i == self.format_idx;
                let label_style = Style::default().fg(theme.overlay1);
                let value_style = if is_selected {
                    Style::default().fg(theme.accent).add_modifier(Modifier::BOLD)
                } else {
                    Style::default().fg(theme.subtext0)
                };
                lines.push(Line::from(vec![
                    Span::styled(format!("{}: ", format_label(fmt)), label_style),
                    Span::styled(value, value_style),
                ]));
                line_count += 1;
            }

            lines.push(Line::from(""));
            line_count += 1;

            // Modifier controls section
            lines.push(Line::from(Span::styled(
                "─── Modify ───",
                Style::default().fg(theme.surface1),
            )));
            line_count += 1;

            // Track lightness control row
            self.lightness_row = inner.y + line_count;

            // Lightness dial
            let lightness_focused = self.focus == Focus::Preview && self.modify_focus == 0;
            let lightness_label = if lightness_focused {
                Span::styled("Lightness: ", Style::default().fg(theme.accent))
            } else {
                Span::styled("Lightness: ", Style::default().fg(theme.overlay1))
            };
            let lightness_bar = self.render_dial(self.modifier.lightness, lightness_focused, theme);
            lines.push(Line::from(vec![
                lightness_label,
                Span::styled(
                    format!("{:+4}", self.modifier.lightness),
                    Style::default().fg(theme.text).add_modifier(Modifier::BOLD),
                ),
            ]));
            lines.push(lightness_bar);
            line_count += 2;

            lines.push(Line::from(""));
            line_count += 1;

            // Track blend control row
            self.blend_row = inner.y + line_count;

            // Blend control
            let blend_focused = self.focus == Focus::Preview && self.modify_focus == 1;
            let blend_label = if blend_focused {
                Span::styled("Blend:     ", Style::default().fg(theme.accent))
            } else {
                Span::styled("Blend:     ", Style::default().fg(theme.overlay1))
            };
            let blend_bar = self.render_slider(self.modifier.blend_amount, blend_focused, theme);
            lines.push(Line::from(vec![
                blend_label,
                Span::styled(
                    format!("{:>3}%", self.modifier.blend_amount),
                    Style::default().fg(theme.text).add_modifier(Modifier::BOLD),
                ),
            ]));
            lines.push(blend_bar);

            // Show blend target if blend amount > 0
            if self.modifier.blend_amount > 0 {
                let (target_name, target_color) = match &blend_target_data {
                    Some((name, color)) => (name.as_str(), Color::Rgb(color.r, color.g, color.b)),
                    None => ("none", theme.text),
                };
                lines.push(Line::from(vec![
                    Span::styled("  Target:  ", Style::default().fg(theme.overlay1)),
                    Span::styled("██", Style::default().fg(target_color)),
                    Span::raw(" "),
                    Span::styled(target_name.to_string(), Style::default().fg(theme.text)),
                    Span::styled(" (» in list)", Style::default().fg(theme.overlay0)),
                ]));
            }

            let para = Paragraph::new(lines);
            frame.render_widget(para, inner);
        }
    }

    /// Render swatch column (full-height color preview, for wide layout)
    fn render_swatch_column(&self, frame: &mut Frame, area: Rect) {
        let theme = &self.flavor_colors;

        let entry_data = self.selected_color().map(|e| (e.name.clone(), e.color));
        let modified = self.modified_color();

        if let Some((entry_name, original)) = entry_data {
            let orig_swatch = Color::Rgb(original.r, original.g, original.b);
            let has_modifier = self.has_modifications();

            if has_modifier {
                let modified = modified.unwrap_or(original);
                let mod_swatch = Color::Rgb(modified.r, modified.g, modified.b);

                // Split vertically: original on top, modified on bottom
                let chunks = Layout::default()
                    .direction(Direction::Vertical)
                    .constraints([Constraint::Percentage(50), Constraint::Percentage(50)])
                    .split(area);

                // Original swatch (top half) - title in border
                self.render_full_swatch_block(frame, chunks[0], orig_swatch, &entry_name, theme);

                // Modified swatch (bottom half) - title in border
                self.render_full_swatch_block(frame, chunks[1], mod_swatch, "modified", theme);
            } else {
                // Full height single swatch with name in border
                self.render_full_swatch_block(frame, area, orig_swatch, &entry_name, theme);
            }
        }
    }

    /// Helper to render a full-area color swatch with border and title
    fn render_full_swatch_block(&self, frame: &mut Frame, area: Rect, color: Color, title: &str, theme: &FlavorTheme) {
        let block = Block::default()
            .borders(Borders::ALL)
            .border_style(Style::default().fg(theme.surface1))
            .title(Span::styled(format!(" {} ", title), Style::default().fg(theme.overlay1)));

        let inner = block.inner(area);
        frame.render_widget(block, area);

        // Fill entire inner area with swatch color
        let swatch_char = "█";
        let width = inner.width as usize;
        let mut lines = Vec::new();

        for _ in 0..inner.height {
            lines.push(Line::from(Span::styled(
                swatch_char.repeat(width),
                Style::default().fg(color),
            )));
        }

        let para = Paragraph::new(lines);
        frame.render_widget(para, inner);
    }

    /// Render a visual dial for lightness (-100 to +100)
    fn render_dial(&self, value: i8, focused: bool, theme: &FlavorTheme) -> Line<'static> {
        let bar_width = 15;
        let center = bar_width / 2;
        // Map -100..+100 to 0..bar_width
        let pos = ((value as i32 + 100) * bar_width as i32 / 200).clamp(0, bar_width as i32 - 1) as usize;

        let mut spans = vec![Span::raw(" ")];
        for i in 0..bar_width {
            let char = if i == center { "│" } else if i == pos { "●" } else { "─" };
            let style = if i == pos {
                if focused {
                    Style::default().fg(theme.accent).add_modifier(Modifier::BOLD)
                } else {
                    Style::default().fg(theme.text)
                }
            } else if i == center {
                Style::default().fg(theme.overlay1)
            } else {
                Style::default().fg(theme.surface1)
            };
            spans.push(Span::styled(char.to_string(), style));
        }
        Line::from(spans)
    }

    /// Render a visual slider for blend amount (0 to 100)
    fn render_slider(&self, value: u8, focused: bool, theme: &FlavorTheme) -> Line<'static> {
        let bar_width = 15;
        // Map 0..100 to 0..bar_width
        let pos = (value as usize * (bar_width - 1) / 100).min(bar_width - 1);

        let mut spans = vec![Span::raw(" ")];
        for i in 0..bar_width {
            let char = if i == pos { "●" } else { "─" };
            let style = if i == pos {
                if focused {
                    Style::default().fg(theme.accent).add_modifier(Modifier::BOLD)
                } else {
                    Style::default().fg(theme.text)
                }
            } else if i <= pos {
                // Filled portion
                Style::default().fg(theme.overlay1)
            } else {
                Style::default().fg(theme.surface1)
            };
            spans.push(Span::styled(char.to_string(), style));
        }
        Line::from(spans)
    }

    fn render_footer(&self, frame: &mut Frame, area: Rect) {
        let theme = &self.flavor_colors;

        // Context-aware hints based on focus and state
        let hints: Vec<(&str, &str)> = match self.focus {
            Focus::List => {
                vec![
                    ("j/k", "navigate"),
                    ("Enter", "accent"),
                    ("y", "copy"),
                    ("Tab", "modify"),
                    ("?", "help"),
                    ("q", "quit"),
                ]
            }
            Focus::Preview => {
                // Different hints based on which control is focused
                if self.modify_focus == 0 {
                    // Lightness control
                    vec![
                        ("h/l", "darken/lighten"),
                        ("j/k", "→blend"),
                        ("f", "format"),
                        ("n", "reset"),
                        ("y", "copy"),
                        ("Tab", "colors"),
                    ]
                } else {
                    // Blend control
                    if self.modifier.blend_amount > 0 {
                        vec![
                            ("h/l", "blend %"),
                            ("J/K", "target"),
                            ("j/k", "→lightness"),
                            ("f", "format"),
                            ("n", "reset"),
                            ("Tab", "colors"),
                        ]
                    } else {
                        vec![
                            ("l", "start blend"),
                            ("j/k", "→lightness"),
                            ("f", "format"),
                            ("n", "reset"),
                            ("y", "copy"),
                            ("Tab", "colors"),
                        ]
                    }
                }
            }
        };

        let spans: Vec<Span> = hints
            .iter()
            .enumerate()
            .flat_map(|(i, (key, desc))| {
                let mut s = vec![
                    Span::styled(*key, Style::default().fg(theme.accent)),
                    Span::styled(format!(" {} ", desc), Style::default().fg(theme.overlay1)),
                ];
                if i < hints.len() - 1 {
                    s.push(Span::raw(" "));
                }
                s
            })
            .collect();

        let para = Paragraph::new(Line::from(spans));
        frame.render_widget(para, area);
    }

    fn render_help(&self, frame: &mut Frame, area: Rect) {
        let theme = &self.flavor_colors;

        // Context-aware help based on current focus
        let (title, bindings): (&str, Vec<(&str, &str)>) = match self.focus {
            Focus::List => ("Colors", vec![
                ("j/k ↑/↓", "Navigate"),
                ("g/G", "Top/bottom"),
                ("Ctrl+d/u", "Page down/up"),
                ("/", "Search"),
                ("Enter", "Set as accent"),
                ("y", "Copy color"),
                ("Tab", "→ Modify pane"),
                ("Esc", "Clear search"),
                ("?", "Toggle help"),
                ("q", "Quit"),
            ]),
            Focus::Preview => ("Modify", vec![
                ("j/k", "Switch control"),
                ("h/l", "Adjust value"),
                ("+/-", "Fine adjust ±5"),
                ("0-9", "Type value"),
                ("n", "Reset all"),
                ("", ""),
                ("f", "Cycle format"),
                ("y", "Copy modified"),
                ("Tab/Esc", "→ Colors"),
            ]),
        };

        let popup = HelpPopup::new(title)
            .bindings(bindings)
            .style(Style::default().bg(theme.surface0))
            .border_style(Style::default().fg(theme.accent))
            .key_style(Style::default().fg(theme.accent).add_modifier(Modifier::BOLD))
            .desc_style(Style::default().fg(theme.text));

        frame.render_widget(popup, area);
    }

    fn render_confirm(&self, frame: &mut Frame, area: Rect) {
        let theme = &self.flavor_colors;
        let width = 40u16;
        let height = 5u16;
        let x = area.x + (area.width.saturating_sub(width)) / 2;
        let y = area.y + (area.height.saturating_sub(height)) / 2;
        let popup_area = Rect::new(x, y, width, height);

        frame.render_widget(Clear, popup_area);

        let block = Block::default()
            .borders(Borders::ALL)
            .border_style(Style::default().fg(theme.accent))
            .style(Style::default().bg(theme.surface0))
            .title(Span::styled(" Confirm ", Style::default().fg(theme.accent)));

        let inner = block.inner(popup_area);
        frame.render_widget(block, popup_area);

        let text = vec![
            Line::from(""),
            Line::from(vec![
                Span::raw("Apply changes? "),
                Span::styled("y", Style::default().fg(theme.green).add_modifier(Modifier::BOLD)),
                Span::raw("es / "),
                Span::styled("n", Style::default().fg(theme.accent).add_modifier(Modifier::BOLD)),
                Span::raw("o"),
            ]),
        ];

        let para = Paragraph::new(text).alignment(ratatui::layout::Alignment::Center);
        frame.render_widget(para, inner);
    }

    /// Handle an event, returns false when picker should quit
    pub fn handle_event(&mut self, event: Event) -> io::Result<bool> {
        if let Some(ref toast) = self.toast {
            if toast.is_expired() {
                self.toast = None;
            }
        }

        match event {
            Event::Key(key) if key.kind == KeyEventKind::Press => {
                match self.mode {
                    Mode::Help => {
                        self.mode = Mode::Normal;
                    }
                    Mode::Confirm => {
                        match key.code {
                            KeyCode::Char('y') | KeyCode::Char('Y') => {
                                // Save config on confirmation
                                if let Err(e) = self.config.save(&self.config_path) {
                                    eprintln!("Failed to save config: {}", e);
                                }
                                self.should_apply = true;
                                return Ok(false);
                            }
                            KeyCode::Char('n') | KeyCode::Char('N') | KeyCode::Esc => {
                                // Revert changes
                                self.config.accent = self.original_accent.clone();
                                self.config.secondary = self.original_secondary.clone();
                                self.mode = Mode::Normal;
                            }
                            _ => {}
                        }
                    }
                    Mode::Search => {
                        match key.code {
                            KeyCode::Esc => {
                                self.search.clear();
                                self.update_filter();
                                self.mode = Mode::Normal;
                            }
                            KeyCode::Enter => {
                                self.mode = Mode::Normal;
                            }
                            KeyCode::Backspace => {
                                self.search.backspace();
                                self.update_filter();
                            }
                            KeyCode::Delete => {
                                self.search.delete();
                                self.update_filter();
                            }
                            KeyCode::Left => self.search.move_left(),
                            KeyCode::Right => self.search.move_right(),
                            KeyCode::Home => self.search.move_start(),
                            KeyCode::End => self.search.move_end(),
                            KeyCode::Char(c) => {
                                self.search.insert(c);
                                self.update_filter();
                            }
                            KeyCode::Down => {
                                self.move_down();
                            }
                            KeyCode::Up => {
                                self.move_up();
                            }
                            _ => {}
                        }
                    }
                    Mode::Normal => {
                        // Global keys (work in any focus)
                        match key.code {
                            KeyCode::Char('q') => return Ok(false),
                            KeyCode::Char('?') | KeyCode::F(1) => {
                                self.mode = Mode::Help;
                                return Ok(true);
                            }
                            KeyCode::Tab => {
                                // Toggle focus between panes
                                self.focus = match self.focus {
                                    Focus::List => Focus::Preview,
                                    Focus::Preview => Focus::List,
                                };
                                return Ok(true);
                            }
                            KeyCode::Char('y') => {
                                self.copy_selected();
                                return Ok(true);
                            }
                            KeyCode::Esc => {
                                if self.focus == Focus::Preview {
                                    // Esc in preview goes back to list
                                    self.focus = Focus::List;
                                } else if self.has_modifications() {
                                    self.reset_modifier();
                                } else if !self.search.is_empty() {
                                    self.search.clear();
                                    self.update_filter();
                                }
                                return Ok(true);
                            }
                            _ => {}
                        }

                        // Focus-specific keys
                        match self.focus {
                            Focus::List => {
                                match key.code {
                                    KeyCode::Char('/') => self.mode = Mode::Search,
                                    KeyCode::Char('j') | KeyCode::Down => self.move_down(),
                                    KeyCode::Char('k') | KeyCode::Up => self.move_up(),
                                    KeyCode::Char('g') | KeyCode::Home => self.move_top(),
                                    KeyCode::Char('G') | KeyCode::End => self.move_bottom(),
                                    KeyCode::Char('h') | KeyCode::Left => self.move_up(),
                                    KeyCode::Char('l') | KeyCode::Right => self.move_down(),
                                    KeyCode::Char('d') if key.modifiers.contains(KeyModifiers::CONTROL) => {
                                        self.page_down(10);
                                    }
                                    KeyCode::Char('u') if key.modifiers.contains(KeyModifiers::CONTROL) => {
                                        self.page_up(10);
                                    }
                                    KeyCode::Enter => {
                                        self.select_as_accent();
                                        if self.has_changes() {
                                            self.mode = Mode::Confirm;
                                        }
                                    }
                                    KeyCode::Char(c) if !key.modifiers.contains(KeyModifiers::CONTROL) => {
                                        self.mode = Mode::Search;
                                        self.search.insert(c);
                                        self.update_filter();
                                    }
                                    _ => {}
                                }
                            }
                            Focus::Preview => {
                                match key.code {
                                    // j/k to switch between lightness (0) and blend (1) controls
                                    KeyCode::Char('j') | KeyCode::Down => {
                                        self.modify_focus = (self.modify_focus + 1) % 2;
                                    }
                                    KeyCode::Char('k') | KeyCode::Up => {
                                        self.modify_focus = if self.modify_focus == 0 { 1 } else { 0 };
                                    }
                                    // h/l to adjust the currently focused control
                                    KeyCode::Char('h') | KeyCode::Left => {
                                        if self.modify_focus == 0 {
                                            // Lightness: decrease (more darken)
                                            self.adjust_lightness(-10);
                                        } else {
                                            // Blend: decrease amount
                                            self.adjust_blend(-10);
                                        }
                                    }
                                    KeyCode::Char('l') | KeyCode::Right => {
                                        if self.modify_focus == 0 {
                                            // Lightness: increase (more lighten)
                                            self.adjust_lightness(10);
                                        } else {
                                            // Blend: increase amount
                                            self.adjust_blend(10);
                                        }
                                    }
                                    // Fine adjustment with +/-
                                    KeyCode::Char('+') | KeyCode::Char('=') => {
                                        if self.modify_focus == 0 {
                                            self.adjust_lightness(5);
                                        } else {
                                            self.adjust_blend(5);
                                        }
                                    }
                                    KeyCode::Char('-') | KeyCode::Char('_') => {
                                        if self.modify_focus == 0 {
                                            self.adjust_lightness(-5);
                                        } else {
                                            self.adjust_blend(-5);
                                        }
                                    }
                                    // Number input for direct value entry
                                    KeyCode::Char(c @ '0'..='9') => {
                                        self.handle_amount_digit(c);
                                    }
                                    // Reset with n
                                    KeyCode::Char('n') | KeyCode::Char('N') => {
                                        self.reset_modifier();
                                    }
                                    // Format cycling with f
                                    KeyCode::Char('f') => {
                                        self.format_idx = (self.format_idx + 1) % FORMATS.len();
                                    }
                                    // Move blend target with shift+j/k when in blend control
                                    KeyCode::Char('J') if self.modify_focus == 1 => {
                                        self.blend_select_down();
                                    }
                                    KeyCode::Char('K') if self.modify_focus == 1 => {
                                        self.blend_select_up();
                                    }
                                    _ => {}
                                }
                            }
                        }
                    }
                }
            }
            Event::Mouse(mouse) => {
                match mouse.kind {
                    MouseEventKind::ScrollDown => {
                        if self.focus == Focus::Preview {
                            // Scroll adjusts current control (±1 for fine control)
                            if self.modify_focus == 0 {
                                self.adjust_lightness(-1);
                            } else {
                                self.adjust_blend(-1);
                            }
                        } else {
                            self.move_down();
                        }
                    }
                    MouseEventKind::ScrollUp => {
                        if self.focus == Focus::Preview {
                            if self.modify_focus == 0 {
                                self.adjust_lightness(1);
                            } else {
                                self.adjust_blend(1);
                            }
                        } else {
                            self.move_up();
                        }
                    }
                    MouseEventKind::Down(crossterm::event::MouseButton::Left) => {
                        // Check if click is on lightness control
                        if mouse.row == self.lightness_row || mouse.row == self.lightness_row + 1 {
                            self.focus = Focus::Preview;
                            self.modify_focus = 0;
                        }
                        // Check if click is on blend control
                        else if mouse.row == self.blend_row {
                            self.focus = Focus::Preview;
                            self.modify_focus = 1;
                        }
                        // Check if click is within color list area
                        else {
                            let inner = self.content_area.inner(ratatui::layout::Margin {
                                horizontal: 1,
                                vertical: 1,
                            });
                            if mouse.row >= inner.y && mouse.row < inner.y + inner.height
                               && mouse.column < self.preview_area.x {
                                self.focus = Focus::List;
                                let clicked_row = (mouse.row - inner.y) as usize;
                                // Use row_to_data mapping to handle section headers
                                if let Some(Some(data_idx)) = self.row_to_data.get(clicked_row) {
                                    self.selected = *data_idx;
                                    self.list_state.select(Some(self.selected));
                                }
                            }
                        }
                    }
                    _ => {}
                }
            }
            _ => {}
        }

        // Reset modifier when selection changes
        if self.selected != self.last_selected {
            self.reset_modifier();
            self.last_selected = self.selected;
        }

        Ok(true)
    }

    /// Check if picker is in search mode (for tab switching logic)
    pub fn is_in_search(&self) -> bool {
        self.mode == Mode::Search
    }

    /// Check if picker wants to apply changes
    pub fn wants_apply(&self) -> bool {
        self.should_apply
    }

    /// Check if picker saved without applying
    pub fn was_saved(&self) -> bool {
        self.mode == Mode::Confirm && !self.should_apply
    }

    /// Render picker in a specific area (for embedding in tabbed app)
    pub fn render_in_area(&mut self, frame: &mut Frame, area: Rect) {
        let theme = &self.flavor_colors;

        frame.render_widget(
            Block::default().style(Style::default().bg(theme.base)),
            area,
        );

        let chunks = Layout::default()
            .direction(Direction::Vertical)
            .constraints([
                Constraint::Length(3),
                Constraint::Min(10),
                Constraint::Length(1),
            ])
            .split(area);

        self.render_header(frame, chunks[0]);
        self.content_area = chunks[1];
        self.render_content(frame, chunks[1]);
        self.render_footer(frame, chunks[2]);

        if let Some(ref toast) = self.toast {
            if !toast.is_expired() {
                frame.render_widget(toast.clone(), area);
            } else {
                self.toast = None;
            }
        }

        if self.mode == Mode::Help {
            self.render_help(frame, area);
        }

        if self.mode == Mode::Confirm {
            self.render_confirm(frame, area);
        }
    }

    pub fn run(mut self) -> io::Result<Option<bool>> {
        let mut terminal = init()?;

        loop {
            terminal.draw(|f| self.render(f))?;

            if event::poll(std::time::Duration::from_millis(100))? {
                let event = event::read()?;
                if !self.handle_event(event)? {
                    break;
                }
            }
        }

        restore()?;

        if self.mode == Mode::Confirm || self.should_apply {
            Ok(Some(self.should_apply))
        } else {
            Ok(None)
        }
    }
}

/// Run the color picker TUI
pub fn run_picker(config: &Config, palette: &Palette, config_path: &str) -> io::Result<Option<bool>> {
    let picker = ColorPicker::new(config.clone(), palette, config_path.to_string());
    picker.run()
}
