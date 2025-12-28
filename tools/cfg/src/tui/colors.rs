use std::io;

use crossterm::event::{self, Event, KeyCode, KeyEventKind, KeyModifiers, MouseEventKind};
use ratatui::{
    layout::{Constraint, Direction, Layout, Rect},
    style::{Color, Modifier, Style, Stylize},
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
const FORMATS: &[&str] = &["hex-hash", "hex", "rgb", "rgb-css", "hyprlang"];

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

/// Color modifier types matching tera template filters
#[derive(Debug, Clone, Copy, PartialEq, Default)]
enum ModifierType {
    #[default]
    None,
    Lighten,
    Darken,
    Blend,
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
    /// Current color modifier type
    modifier_type: ModifierType,
    /// Modifier amount (0-100)
    modifier_amount: u8,
    /// Input buffer for typing modifier amount directly
    modifier_input: String,
    /// Track last selected index to detect changes
    last_selected: usize,
    /// Which pane has focus
    focus: Focus,
    /// Secondary selection for blend target (index into filtered)
    blend_selection: usize,
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
            modifier_type: ModifierType::None,
            modifier_amount: 15,
            modifier_input: String::new(),
            last_selected: 0,
            focus: Focus::List,
            blend_selection: 1, // Start at second color
        }
    }

    fn has_changes(&self) -> bool {
        self.config.accent != self.original_accent
            || self.config.secondary != self.original_secondary
    }

    fn current_format(&self) -> &str {
        FORMATS[self.format_idx]
    }

    fn cycle_format(&mut self) {
        self.format_idx = (self.format_idx + 1) % FORMATS.len();
    }

    fn selected_color(&self) -> Option<&ColorEntry> {
        self.filtered.get(self.selected).and_then(|&i| self.colors.get(i))
    }

    /// Get the blend target color (from filtered list via blend_selection)
    fn blend_target(&self) -> Option<&ColorEntry> {
        self.filtered.get(self.blend_selection)
            .and_then(|&i| self.colors.get(i))
    }

    /// Compute the modified color based on current modifier settings
    fn modified_color(&self) -> Option<CfgColor> {
        let entry = self.selected_color()?;
        let base = &entry.color;

        Some(match self.modifier_type {
            ModifierType::None => *base,
            ModifierType::Lighten => base.lighten(self.modifier_amount),
            ModifierType::Darken => base.darken(self.modifier_amount),
            ModifierType::Blend => {
                if let Some(target) = self.blend_target() {
                    base.blend(&target.color, 100 - self.modifier_amount)
                } else {
                    *base
                }
            }
        })
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
        self.modifier_type = ModifierType::None;
        self.modifier_amount = 15;
        self.modifier_input.clear();
    }

    /// Increase modifier amount by step
    fn increase_amount(&mut self, step: u8) {
        self.modifier_amount = self.modifier_amount.saturating_add(step).min(100);
        self.modifier_input.clear();
    }

    /// Decrease modifier amount by step
    fn decrease_amount(&mut self, step: u8) {
        self.modifier_amount = self.modifier_amount.saturating_sub(step);
        self.modifier_input.clear();
    }

    /// Handle digit input for modifier amount
    fn handle_amount_digit(&mut self, digit: char) {
        self.modifier_input.push(digit);
        if let Ok(amount) = self.modifier_input.parse::<u8>() {
            self.modifier_amount = amount.min(100);
        }
        // Reset input after 3 digits or if > 100
        if self.modifier_input.len() >= 3 || self.modifier_amount >= 100 {
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
            let formatted = format_color(&color, self.current_format(), 1.0);
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

    fn render_content(&mut self, frame: &mut Frame, area: Rect) {
        let chunks = Layout::default()
            .direction(Direction::Horizontal)
            .constraints([Constraint::Percentage(65), Constraint::Percentage(35)])
            .split(area);

        self.render_color_list(frame, chunks[0]);
        self.render_preview(frame, chunks[1]);
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
            let is_blend_target = self.modifier_type == ModifierType::Blend && idx == self.blend_selection;

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

    fn render_preview(&self, frame: &mut Frame, area: Rect) {
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

        if let Some(entry) = self.selected_color() {
            let original = &entry.color;
            let modified = self.modified_color().unwrap_or(*original);
            let orig_swatch = Color::Rgb(original.r, original.g, original.b);
            let mod_swatch = Color::Rgb(modified.r, modified.g, modified.b);

            let has_modifier = self.modifier_type != ModifierType::None;

            let mut lines = vec![Line::from("")];

            // Side-by-side swatches when modifier active
            if has_modifier {
                // Larger swatches side by side
                lines.push(Line::from(vec![
                    Span::styled("██████", Style::default().fg(orig_swatch)),
                    Span::raw("  "),
                    Span::styled("██████", Style::default().fg(mod_swatch)),
                ]));
                lines.push(Line::from(vec![
                    Span::styled("██████", Style::default().fg(orig_swatch)),
                    Span::raw("  "),
                    Span::styled("██████", Style::default().fg(mod_swatch)),
                ]));
                lines.push(Line::from(vec![
                    Span::styled("██████", Style::default().fg(orig_swatch)),
                    Span::raw("  "),
                    Span::styled("██████", Style::default().fg(mod_swatch)),
                ]));
                lines.push(Line::from(""));

                // Labels with modifier info
                let modifier_label = match self.modifier_type {
                    ModifierType::Lighten => format!("+{}%", self.modifier_amount),
                    ModifierType::Darken => format!("-{}%", self.modifier_amount),
                    ModifierType::Blend => format!("→{}%", self.modifier_amount),
                    ModifierType::None => String::new(),
                };
                lines.push(Line::from(vec![
                    Span::styled(&entry.name, Style::default().fg(theme.subtext0)),
                    Span::raw("  "),
                    Span::styled(modifier_label, Style::default().fg(theme.accent)),
                ]));
            } else {
                // Large single swatch when no modifier
                lines.push(Line::from(Span::styled("██████████████", Style::default().fg(orig_swatch))));
                lines.push(Line::from(Span::styled("██████████████", Style::default().fg(orig_swatch))));
                lines.push(Line::from(Span::styled("██████████████", Style::default().fg(orig_swatch))));
                lines.push(Line::from(""));
                lines.push(Line::from(Span::styled(
                    &entry.name,
                    Style::default().fg(theme.text).add_modifier(Modifier::BOLD),
                )));
            }

            lines.push(Line::from(""));

            // Show format values for the MODIFIED color
            let display_color = if has_modifier { &modified } else { original };
            for (i, fmt) in FORMATS.iter().enumerate() {
                let value = format_color(display_color, fmt, 1.0);
                let style = if i == self.format_idx {
                    Style::default().fg(theme.accent).add_modifier(Modifier::BOLD)
                } else {
                    Style::default().fg(theme.subtext0)
                };
                lines.push(Line::from(Span::styled(value, style)));
            }

            lines.push(Line::from(""));

            // Modifier controls section
            lines.push(Line::from(Span::styled(
                "─────────────────",
                Style::default().fg(theme.surface1),
            )));

            // Modifier type buttons
            let btn = |label: &str, active: bool| -> Span {
                if active {
                    Span::styled(format!("[{}]", label), Style::default().fg(theme.accent).add_modifier(Modifier::BOLD))
                } else {
                    Span::styled(format!(" {} ", label), Style::default().fg(theme.overlay1))
                }
            };

            lines.push(Line::from(vec![
                btn("L", self.modifier_type == ModifierType::Lighten),
                Span::raw(" "),
                btn("D", self.modifier_type == ModifierType::Darken),
                Span::raw(" "),
                btn("B", self.modifier_type == ModifierType::Blend),
            ]));

            // Amount control
            if has_modifier {
                lines.push(Line::from(vec![
                    Span::styled("Amount: ", Style::default().fg(theme.overlay1)),
                    Span::styled(
                        format!("{:>3}", self.modifier_amount),
                        Style::default().fg(theme.text).add_modifier(Modifier::BOLD),
                    ),
                    Span::styled(" [+/-]", Style::default().fg(theme.overlay1)),
                ]));

                // Blend target (only for blend mode)
                if self.modifier_type == ModifierType::Blend {
                    let target_name = self.blend_target()
                        .map(|t| t.name.as_str())
                        .unwrap_or("none");
                    let target_color = self.blend_target()
                        .map(|t| Color::Rgb(t.color.r, t.color.g, t.color.b))
                        .unwrap_or(theme.text);
                    lines.push(Line::from(vec![
                        Span::styled("Target: ", Style::default().fg(theme.overlay1)),
                        Span::styled("██", Style::default().fg(target_color)),
                        Span::raw(" "),
                        Span::styled(target_name, Style::default().fg(theme.text)),
                        Span::styled(" [h/l]", Style::default().fg(theme.overlay1)),
                    ]));
                }
            }

            let para = Paragraph::new(lines);
            frame.render_widget(para, inner);
        }
    }

    fn render_footer(&self, frame: &mut Frame, area: Rect) {
        let theme = &self.flavor_colors;
        let hints = vec![
            ("j/k", "navigate"),
            ("Enter", "select"),
            ("y", "copy"),
            ("Tab", "format"),
            ("?", "help"),
            ("q", "quit"),
        ];

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
                ("l", "Lighten"),
                ("d", "Darken"),
                ("b", "Blend (» in list)"),
                ("n", "Reset"),
                ("", ""),
                ("+/-", "Amount ±5%"),
                ("0-9", "Type amount"),
                ("j/k", "Format (or » target)"),
                ("f", "Cycle format"),
                ("", ""),
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

    fn handle_event(&mut self, event: Event) -> io::Result<bool> {
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
                                } else if self.modifier_type != ModifierType::None {
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
                                    // Modifier type selection
                                    KeyCode::Char('l') | KeyCode::Char('L') => {
                                        self.modifier_type = if self.modifier_type == ModifierType::Lighten {
                                            ModifierType::None
                                        } else {
                                            ModifierType::Lighten
                                        };
                                    }
                                    KeyCode::Char('d') | KeyCode::Char('D') => {
                                        self.modifier_type = if self.modifier_type == ModifierType::Darken {
                                            ModifierType::None
                                        } else {
                                            ModifierType::Darken
                                        };
                                    }
                                    KeyCode::Char('b') | KeyCode::Char('B') => {
                                        self.modifier_type = if self.modifier_type == ModifierType::Blend {
                                            ModifierType::None
                                        } else {
                                            ModifierType::Blend
                                        };
                                    }
                                    KeyCode::Char('n') | KeyCode::Char('N') => {
                                        self.reset_modifier();
                                    }
                                    // j/k navigation: blend target when in blend mode, format otherwise
                                    KeyCode::Char('j') | KeyCode::Down => {
                                        if self.modifier_type == ModifierType::Blend {
                                            self.blend_select_down();
                                        } else {
                                            self.format_idx = (self.format_idx + 1) % FORMATS.len();
                                        }
                                    }
                                    KeyCode::Char('k') | KeyCode::Up => {
                                        if self.modifier_type == ModifierType::Blend {
                                            self.blend_select_up();
                                        } else {
                                            self.format_idx = self.format_idx.checked_sub(1).unwrap_or(FORMATS.len() - 1);
                                        }
                                    }
                                    // Format cycling with f (always available)
                                    KeyCode::Char('f') => {
                                        self.format_idx = (self.format_idx + 1) % FORMATS.len();
                                    }
                                    // Amount controls with +/-
                                    KeyCode::Char('+') | KeyCode::Char('=') => {
                                        self.increase_amount(5);
                                    }
                                    KeyCode::Char('-') | KeyCode::Char('_') => {
                                        self.decrease_amount(5);
                                    }
                                    KeyCode::Char(c @ '0'..='9') => {
                                        self.handle_amount_digit(c);
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
                    MouseEventKind::ScrollDown => self.move_down(),
                    MouseEventKind::ScrollUp => self.move_up(),
                    MouseEventKind::Down(crossterm::event::MouseButton::Left) => {
                        // Check if click is within content area (accounting for border)
                        let inner = self.content_area.inner(ratatui::layout::Margin {
                            horizontal: 1,
                            vertical: 1,
                        });
                        if mouse.row >= inner.y && mouse.row < inner.y + inner.height {
                            let clicked_row = (mouse.row - inner.y) as usize;
                            // Use row_to_data mapping to handle section headers
                            if let Some(Some(data_idx)) = self.row_to_data.get(clicked_row) {
                                self.selected = *data_idx;
                                self.list_state.select(Some(self.selected));
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
