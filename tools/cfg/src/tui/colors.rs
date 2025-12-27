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
        if let Some(entry) = self.selected_color() {
            let formatted = format_color(&entry.color, self.current_format(), 1.0);
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
        let block = Block::default()
            .borders(Borders::ALL)
            .border_style(Style::default().fg(theme.surface1));

        let inner = block.inner(area);
        frame.render_widget(block, area);

        let mut items: Vec<ListItem> = Vec::new();
        let mut prev_is_accent = true;

        for (idx, &color_idx) in self.filtered.iter().enumerate() {
            let entry = &self.colors[color_idx];

            if prev_is_accent && !entry.is_accent && idx > 0 {
                items.push(ListItem::new(Line::from("")));
                items.push(ListItem::new(Line::from(Span::styled(
                    "Surface Colors",
                    Style::default().fg(theme.overlay1).add_modifier(Modifier::BOLD),
                ))));
            } else if entry.is_accent && idx == 0 {
                items.push(ListItem::new(Line::from(Span::styled(
                    "Accent Colors",
                    Style::default().fg(theme.overlay1).add_modifier(Modifier::BOLD),
                ))));
            }
            prev_is_accent = entry.is_accent;

            let c = &entry.color;
            let swatch_color = Color::Rgb(c.r, c.g, c.b);
            let is_current = entry.name == self.config.accent || entry.name == self.config.secondary;
            let is_selected = idx == self.selected;

            let mut spans = vec![
                Span::raw("  "),
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
            } else {
                Style::default()
            };

            items.push(ListItem::new(Line::from(spans)).style(style));
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
        let block = Block::default()
            .borders(Borders::ALL)
            .border_style(Style::default().fg(theme.surface1))
            .title(Span::styled(" Preview ", Style::default().fg(theme.overlay1)));

        let inner = block.inner(area);
        frame.render_widget(block, area);

        if let Some(entry) = self.selected_color() {
            let c = &entry.color;
            let swatch_color = Color::Rgb(c.r, c.g, c.b);

            let mut lines = vec![
                Line::from(""),
                Line::from(Span::styled("████████", Style::default().fg(swatch_color))),
                Line::from(Span::styled("████████", Style::default().fg(swatch_color))),
                Line::from(""),
                Line::from(Span::styled(
                    &entry.name,
                    Style::default().fg(theme.text).add_modifier(Modifier::BOLD),
                )),
                Line::from(""),
            ];

            for (i, fmt) in FORMATS.iter().enumerate() {
                let value = format_color(c, fmt, 1.0);
                let style = if i == self.format_idx {
                    Style::default().fg(theme.accent).add_modifier(Modifier::BOLD)
                } else {
                    Style::default().fg(theme.subtext0)
                };
                lines.push(Line::from(Span::styled(value, style)));
            }

            lines.push(Line::from(""));
            lines.push(Line::from(Span::styled(
                format!("Tab: {}", self.current_format()),
                Style::default().fg(theme.overlay1),
            )));

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
        let bindings = vec![
            ("j/k, ↑/↓", "Navigate"),
            ("g/G", "Top/bottom"),
            ("Ctrl+d/u", "Page down/up"),
            ("/", "Search"),
            ("Esc", "Clear search"),
            ("Tab", "Cycle format"),
            ("y", "Copy to clipboard"),
            ("Enter", "Select as accent"),
            ("?", "Toggle help"),
            ("q", "Quit"),
        ];

        let popup = HelpPopup::new("Keybindings")
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
                        match key.code {
                            KeyCode::Char('q') => return Ok(false),
                            KeyCode::Char('/') => self.mode = Mode::Search,
                            KeyCode::Char('?') | KeyCode::F(1) => self.mode = Mode::Help,
                            KeyCode::Char('j') | KeyCode::Down => self.move_down(),
                            KeyCode::Char('k') | KeyCode::Up => self.move_up(),
                            KeyCode::Char('g') | KeyCode::Home => self.move_top(),
                            KeyCode::Char('G') | KeyCode::End => self.move_bottom(),
                            KeyCode::Char('d') if key.modifiers.contains(KeyModifiers::CONTROL) => {
                                self.page_down(10);
                            }
                            KeyCode::Char('u') if key.modifiers.contains(KeyModifiers::CONTROL) => {
                                self.page_up(10);
                            }
                            KeyCode::Tab => self.cycle_format(),
                            KeyCode::Char('y') => self.copy_selected(),
                            KeyCode::Enter => {
                                self.select_as_accent();
                                // Only show confirm dialog if something changed
                                if self.has_changes() {
                                    self.mode = Mode::Confirm;
                                }
                            }
                            KeyCode::Esc => {
                                if !self.search.is_empty() {
                                    self.search.clear();
                                    self.update_filter();
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
                }
            }
            Event::Mouse(mouse) => {
                match mouse.kind {
                    MouseEventKind::ScrollDown => self.move_down(),
                    MouseEventKind::ScrollUp => self.move_up(),
                    _ => {}
                }
            }
            _ => {}
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
