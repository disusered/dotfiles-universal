use std::io;

use crossterm::event::{self, Event, KeyCode, KeyEventKind, KeyModifiers, MouseEventKind};
use ratatui::{
    layout::{Constraint, Direction, Layout, Rect},
    style::{Color, Modifier, Style},
    text::{Line, Span},
    widgets::{Block, Borders, Clear, List, ListItem, ListState, Paragraph, Scrollbar, ScrollbarOrientation, ScrollbarState},
    Frame,
};

use crate::config::Config;
use crate::fonts::{self, FontCategory, FontListing};
use crate::palette::Palette;

use super::clipboard;
use super::widgets::{FuzzyInput, FuzzyInputState, HelpPopup, Toast};
use super::{init, restore};

#[derive(Debug, Clone, Copy, PartialEq)]
enum CategoryFilter {
    All,
    Mono,
    Sans,
}

impl CategoryFilter {
    fn next(self) -> Self {
        match self {
            CategoryFilter::All => CategoryFilter::Mono,
            CategoryFilter::Mono => CategoryFilter::Sans,
            CategoryFilter::Sans => CategoryFilter::All,
        }
    }

    fn label(self) -> &'static str {
        match self {
            CategoryFilter::All => "All",
            CategoryFilter::Mono => "Mono",
            CategoryFilter::Sans => "Sans",
        }
    }
}

#[derive(Debug, Clone, Copy, PartialEq)]
enum Mode {
    Normal,
    Search,
    Help,
    Confirm,
}

struct FontEntry {
    listing: FontListing,
    category: FontCategory,
}

/// Theme colors from catppuccin for UI rendering
struct FlavorTheme {
    base: Color,
    surface0: Color,
    surface1: Color,
    text: Color,
    subtext0: Color,
    overlay1: Color,
    accent: Color,
    green: Color,
    yellow: Color,
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
            text: get_color("text"),
            subtext0: get_color("subtext0"),
            overlay1: get_color("overlay1"),
            accent: get_color(&config.accent),
            green: get_color("green"),
            yellow: get_color("yellow"),
        }
    }
}

pub struct FontPicker {
    fonts: Vec<FontEntry>,
    filtered: Vec<usize>,
    selected: usize,
    list_state: ListState,
    search: FuzzyInputState,
    category_filter: CategoryFilter,
    mode: Mode,
    toast: Option<Toast>,
    config: Config,
    config_path: String,
    flavor_colors: FlavorTheme,
    should_apply: bool,
    /// Original config values to detect changes
    original_mono: String,
    original_sans: String,
}

impl FontPicker {
    pub fn new(config: Config, palette: &Palette, config_path: String) -> Self {
        let flavor_colors = FlavorTheme::from_config(&config, palette);

        // Get all fonts
        let mono_fonts = fonts::list_fonts(Some(FontCategory::Mono));
        let sans_fonts = fonts::list_fonts(Some(FontCategory::Sans));

        let mut all_fonts: Vec<FontEntry> = Vec::new();
        for listing in mono_fonts {
            all_fonts.push(FontEntry {
                listing,
                category: FontCategory::Mono,
            });
        }
        for listing in sans_fonts {
            all_fonts.push(FontEntry {
                listing,
                category: FontCategory::Sans,
            });
        }

        let filtered: Vec<usize> = (0..all_fonts.len()).collect();
        let mut list_state = ListState::default();
        list_state.select(Some(0));

        let original_mono = config.fonts.mono.clone();
        let original_sans = config.fonts.sans.clone();

        Self {
            fonts: all_fonts,
            filtered,
            selected: 0,
            list_state,
            search: FuzzyInputState::new(),
            category_filter: CategoryFilter::All,
            mode: Mode::Normal,
            toast: None,
            config,
            config_path,
            flavor_colors,
            should_apply: false,
            original_mono,
            original_sans,
        }
    }

    fn has_changes(&self) -> bool {
        self.config.fonts.mono != self.original_mono
            || self.config.fonts.sans != self.original_sans
    }

    fn selected_font(&self) -> Option<&FontEntry> {
        self.filtered.get(self.selected).and_then(|&i| self.fonts.get(i))
    }

    fn update_filter(&mut self) {
        let category_matches = |entry: &FontEntry| -> bool {
            match self.category_filter {
                CategoryFilter::All => true,
                CategoryFilter::Mono => entry.category == FontCategory::Mono,
                CategoryFilter::Sans => entry.category == FontCategory::Sans,
            }
        };

        if self.search.is_empty() {
            self.filtered = self.fonts
                .iter()
                .enumerate()
                .filter(|(_, f)| category_matches(f))
                .map(|(i, _)| i)
                .collect();
        } else {
            let search_results = self.search.filter(&self.fonts, |f| f.listing.name);
            self.filtered = search_results
                .into_iter()
                .filter(|&(i, _)| category_matches(&self.fonts[i]))
                .map(|(i, _)| i)
                .collect();
        }

        self.selected = 0;
        self.list_state.select(if self.filtered.is_empty() { None } else { Some(0) });
    }

    fn cycle_category(&mut self) {
        self.category_filter = self.category_filter.next();
        self.update_filter();
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
        self.list_state.select(if self.filtered.is_empty() { None } else { Some(0) });
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
        if let Some(entry) = self.selected_font() {
            clipboard::copy(entry.listing.name);
            let theme = &self.flavor_colors;
            self.toast = Some(Toast::new(format!("Copied: {}", entry.listing.name))
                .style(Style::default().fg(theme.green))
                .border_style(Style::default().fg(theme.green)));
        }
    }

    fn select_font(&mut self) {
        if let Some(entry) = self.selected_font() {
            let font_name = entry.listing.name.to_string();
            match entry.category {
                FontCategory::Mono => {
                    self.config.fonts.mono = font_name;
                }
                FontCategory::Sans => {
                    self.config.fonts.sans = font_name;
                }
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
        let title = format!(
            " cfg font  {}  [{}] ",
            self.config.flavor,
            self.category_filter.label()
        );

        let block = Block::default()
            .borders(Borders::ALL)
            .border_style(Style::default().fg(theme.surface1))
            .title(Span::styled(
                title,
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
        let theme = &self.flavor_colors;
        let block = Block::default()
            .borders(Borders::ALL)
            .border_style(Style::default().fg(theme.surface1));

        let inner = block.inner(area);
        frame.render_widget(block, area);

        let mut items: Vec<ListItem> = Vec::new();
        let mut prev_category: Option<FontCategory> = None;

        for (idx, &font_idx) in self.filtered.iter().enumerate() {
            let entry = &self.fonts[font_idx];

            // Section headers
            if prev_category != Some(entry.category) {
                if prev_category.is_some() {
                    items.push(ListItem::new(Line::from("")));
                }
                let header = match entry.category {
                    FontCategory::Mono => "Monospace",
                    FontCategory::Sans => "Sans-serif",
                };
                items.push(ListItem::new(Line::from(Span::styled(
                    header,
                    Style::default().fg(theme.overlay1).add_modifier(Modifier::BOLD),
                ))));
                prev_category = Some(entry.category);
            }

            let listing = &entry.listing;
            let is_current = match entry.category {
                FontCategory::Mono => listing.name == self.config.fonts.mono,
                FontCategory::Sans => listing.name == self.config.fonts.sans,
            };
            let is_selected = idx == self.selected;

            let mut spans = vec![Span::raw("  ")];

            // Install status
            if listing.installed {
                spans.push(Span::styled("✓ ", Style::default().fg(theme.green)));
            } else {
                spans.push(Span::styled("  ", Style::default()));
            }

            // Name with highlighting
            let name_base_style = if !listing.installed {
                Style::default().fg(theme.overlay1)
            } else if is_current {
                Style::default().fg(theme.accent).add_modifier(Modifier::BOLD)
            } else {
                Style::default().fg(theme.text)
            };

            if self.search.is_empty() {
                spans.push(Span::styled(format!("{:<26}", listing.name), name_base_style));
            } else {
                let highlight_style = name_base_style.fg(theme.accent).add_modifier(Modifier::BOLD);
                let highlighted = self.search.highlight(listing.name, name_base_style, highlight_style);
                for span in highlighted.spans {
                    spans.push(span);
                }
                let padding = 26usize.saturating_sub(listing.name.len());
                spans.push(Span::raw(" ".repeat(padding)));
            }

            // Badges
            if listing.ligatures {
                spans.push(Span::styled("lig ", Style::default().fg(theme.overlay1)));
            } else {
                spans.push(Span::raw("    "));
            }

            if listing.nerd_font {
                spans.push(Span::styled("\u{f002d} ", Style::default().fg(theme.overlay1)));
            } else {
                spans.push(Span::raw("  "));
            }

            // Description (full width, will be clipped by terminal)
            let desc_style = if !listing.installed {
                Style::default().fg(theme.overlay1)
            } else {
                Style::default().fg(theme.subtext0)
            };
            spans.push(Span::styled(listing.description, desc_style));

            // Current indicator
            if is_current {
                spans.push(Span::styled(" ← current", Style::default().fg(theme.overlay1)));
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

        // Scrollbar
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

    fn render_footer(&self, frame: &mut Frame, area: Rect) {
        let theme = &self.flavor_colors;
        let hints = vec![
            ("j/k", "navigate"),
            ("Enter", "select"),
            ("y", "copy"),
            ("Tab", "category"),
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
            ("Tab", "Cycle category"),
            ("y", "Copy font name"),
            ("Enter", "Select font"),
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
                                self.config.fonts.mono = self.original_mono.clone();
                                self.config.fonts.sans = self.original_sans.clone();
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
                            KeyCode::Down => self.move_down(),
                            KeyCode::Up => self.move_up(),
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
                            KeyCode::Tab => self.cycle_category(),
                            KeyCode::Char('y') => self.copy_selected(),
                            KeyCode::Enter => {
                                if let Some(entry) = self.selected_font() {
                                    if !entry.listing.installed {
                                        let theme = &self.flavor_colors;
                                        self.toast = Some(Toast::new("Font not installed!")
                                            .style(Style::default().fg(theme.yellow))
                                            .border_style(Style::default().fg(theme.yellow)));
                                    }
                                }
                                self.select_font();
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

/// Run the font picker TUI
pub fn run_picker(config: &Config, palette: &Palette, config_path: &str) -> io::Result<Option<bool>> {
    let picker = FontPicker::new(config.clone(), palette, config_path.to_string());
    picker.run()
}
