use std::io;

use crossterm::event::{self, Event, KeyCode, KeyEventKind, KeyModifiers, MouseEventKind};
use ratatui::{
    layout::{Constraint, Direction, Layout, Rect},
    style::{Color, Modifier, Style},
    text::{Line, Span},
    widgets::{
        Block, Borders, Clear, List, ListItem, ListState, Paragraph, Scrollbar,
        ScrollbarOrientation, ScrollbarState,
    },
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
    // Syntax highlighting colors
    mauve: Color, // keywords
    peach: Color, // functions
    sky: Color,   // types
}

impl FlavorTheme {
    fn from_config(config: &Config, palette: &Palette) -> Self {
        let get_color = |name: &str| -> Color {
            palette
                .get(name)
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
            mauve: get_color("mauve"),
            peach: get_color("peach"),
            sky: get_color("sky"),
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
    /// Content area for mouse click detection
    content_area: Rect,
    /// Maps visual row index to filtered data index (for mouse clicks)
    row_to_data: Vec<Option<usize>>,
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
            content_area: Rect::default(),
            row_to_data: Vec::new(),
        }
    }

    fn has_changes(&self) -> bool {
        self.config.fonts.mono != self.original_mono || self.config.fonts.sans != self.original_sans
    }

    /// Reload config from disk (to pick up changes from scratchpad)
    pub fn refresh_config(&mut self) {
        if let Ok(cfg) = Config::load(&self.config_path) {
            // Update originals so has_changes() reflects the new baseline
            self.original_mono = cfg.fonts.mono.clone();
            self.original_sans = cfg.fonts.sans.clone();
            self.config = cfg;
        }
    }

    fn selected_font(&self) -> Option<&FontEntry> {
        self.filtered
            .get(self.selected)
            .and_then(|&i| self.fonts.get(i))
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
            self.filtered = self
                .fonts
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
        self.list_state.select(if self.filtered.is_empty() {
            None
        } else {
            Some(0)
        });
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
        self.list_state.select(if self.filtered.is_empty() {
            None
        } else {
            Some(0)
        });
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
            self.toast = Some(
                Toast::new(format!("Copied: {}", entry.listing.name))
                    .style(Style::default().fg(theme.green))
                    .border_style(Style::default().fg(theme.green)),
            );
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
                Style::default()
                    .fg(theme.accent)
                    .add_modifier(Modifier::BOLD),
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
        // Track which visual row maps to which data index
        self.row_to_data.clear();

        for (idx, &font_idx) in self.filtered.iter().enumerate() {
            let entry = &self.fonts[font_idx];

            // Section headers
            if prev_category != Some(entry.category) {
                if prev_category.is_some() {
                    items.push(ListItem::new(Line::from("")));
                    self.row_to_data.push(None); // empty line
                }
                let header = match entry.category {
                    FontCategory::Mono => "Monospace",
                    FontCategory::Sans => "Sans-serif",
                };
                items.push(ListItem::new(Line::from(Span::styled(
                    header,
                    Style::default()
                        .fg(theme.overlay1)
                        .add_modifier(Modifier::BOLD),
                ))));
                self.row_to_data.push(None); // header line
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
                Style::default()
                    .fg(theme.accent)
                    .add_modifier(Modifier::BOLD)
            } else {
                Style::default().fg(theme.text)
            };

            if self.search.is_empty() {
                spans.push(Span::styled(
                    format!("{:<26}", listing.name),
                    name_base_style,
                ));
            } else {
                let highlight_style = name_base_style
                    .fg(theme.accent)
                    .add_modifier(Modifier::BOLD);
                let highlighted =
                    self.search
                        .highlight(listing.name, name_base_style, highlight_style);
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
                spans.push(Span::styled("nf ", Style::default().fg(theme.overlay1)));
            } else {
                spans.push(Span::raw("   "));
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
                spans.push(Span::styled(
                    " ← current",
                    Style::default().fg(theme.overlay1),
                ));
            }

            let style = if is_selected {
                Style::default().bg(theme.surface0)
            } else {
                Style::default()
            };

            items.push(ListItem::new(Line::from(spans)).style(style));
            self.row_to_data.push(Some(idx)); // map this row to data index
        }

        let list = List::new(items);
        frame.render_stateful_widget(list, inner, &mut self.list_state);

        // Scrollbar
        if self.filtered.len() > inner.height as usize {
            let scrollbar = Scrollbar::new(ScrollbarOrientation::VerticalRight)
                .style(Style::default().fg(theme.surface1));
            let mut scrollbar_state =
                ScrollbarState::new(self.filtered.len()).position(self.selected);
            frame.render_stateful_widget(
                scrollbar,
                area.inner(ratatui::layout::Margin {
                    horizontal: 0,
                    vertical: 1,
                }),
                &mut scrollbar_state,
            );
        }
    }

    fn render_footer(&self, frame: &mut Frame, area: Rect) {
        let theme = &self.flavor_colors;
        let hints = vec![
            ("j/k", "navigate"),
            ("p", "preview"),
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
            ("p", "Preview font"),
            ("y", "Copy font name"),
            ("Enter", "Select font"),
            ("?", "Toggle help"),
            ("q", "Quit"),
        ];

        let popup = HelpPopup::new("Keybindings")
            .bindings(bindings)
            .style(Style::default().bg(theme.surface0))
            .border_style(Style::default().fg(theme.accent))
            .key_style(
                Style::default()
                    .fg(theme.accent)
                    .add_modifier(Modifier::BOLD),
            )
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
                Span::styled(
                    "y",
                    Style::default()
                        .fg(theme.green)
                        .add_modifier(Modifier::BOLD),
                ),
                Span::raw("es / "),
                Span::styled(
                    "n",
                    Style::default()
                        .fg(theme.accent)
                        .add_modifier(Modifier::BOLD),
                ),
                Span::raw("o"),
            ]),
        ];

        let para = Paragraph::new(text).alignment(ratatui::layout::Alignment::Center);
        frame.render_widget(para, inner);
    }

    fn open_preview(&mut self) {
        if let Some(entry) = self.selected_font() {
            let font_name = entry.listing.name.to_string();

            // Kill any existing font preview first
            let _ = std::process::Command::new("hyprctl")
                .args(["dispatch", "killwindow", "class:fonts_scratch"])
                .output();

            // Spawn kitty directly as child process (dies when cfg dies)
            let child = std::process::Command::new("kitty")
                .args([
                    "--class",
                    "fonts_scratch",
                    "-o",
                    &format!("font_family={}", font_name),
                    "cfg",
                    "font",
                    "--scratchpad",
                ])
                .spawn();

            if let Ok(mut child) = child {
                std::thread::spawn(move || {
                    // Wait for window to appear, then resize and position
                    std::thread::sleep(std::time::Duration::from_millis(150));
                    let _ = std::process::Command::new("hyprctl")
                        .args(["--batch", "dispatch focuswindow class:fonts_scratch; dispatch resizeactive exact 1080 720; dispatch centerwindow 1"])
                        .output();

                    // Wait for preview to close, then restore focus to cfg
                    let _ = child.wait();
                    let _ = std::process::Command::new("hyprctl")
                        .args(["dispatch", "focuswindow", "class:cfg_scratch"])
                        .output();
                });
            }
        }
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
                                self.config.fonts.mono = self.original_mono.clone();
                                self.config.fonts.sans = self.original_sans.clone();
                                self.mode = Mode::Normal;
                            }
                            _ => {}
                        }
                    }
                    Mode::Search => match key.code {
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
                    },
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
                            KeyCode::Char('p') => self.open_preview(),
                            KeyCode::Enter => {
                                if let Some(entry) = self.selected_font() {
                                    if !entry.listing.installed {
                                        let theme = &self.flavor_colors;
                                        self.toast = Some(
                                            Toast::new("Font not installed!")
                                                .style(Style::default().fg(theme.yellow))
                                                .border_style(Style::default().fg(theme.yellow)),
                                        );
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
            Event::Mouse(mouse) => match mouse.kind {
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
                        // Use row_to_data mapping to find actual data index
                        if let Some(Some(data_idx)) = self.row_to_data.get(clicked_row) {
                            self.selected = *data_idx;
                            self.list_state.select(Some(self.selected));
                        }
                    }
                }
                _ => {}
            },
            _ => {}
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
            // Refresh config to pick up changes from scratchpad preview
            self.refresh_config();

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
pub fn run_picker(
    config: &Config,
    palette: &Palette,
    config_path: &str,
) -> io::Result<Option<bool>> {
    let picker = FontPicker::new(config.clone(), palette, config_path.to_string());
    picker.run()
}

/// Scratchpad preview section types
enum ScratchpadSection {
    Divider(&'static str),
    Variants,
    CharacterSet {
        label: &'static str,
        chars: &'static str,
    },
}

/// Token types for syntax highlighting
#[derive(Clone, Copy)]
enum TokenType {
    Keyword,
    Function,
    String,
    Type,
    Punctuation,
    Text,
}

/// A syntax-highlighted code sample
struct SyntaxSample {
    language: &'static str,
    tokens: &'static [(&'static str, TokenType)],
}

/// Syntax samples for different languages
const SYNTAX_SAMPLES: &[SyntaxSample] = &[
    SyntaxSample {
        language: "JavaScript",
        tokens: &[
            ("const", TokenType::Keyword),
            (" greet ", TokenType::Text),
            ("=", TokenType::Punctuation),
            (" (", TokenType::Punctuation),
            ("name", TokenType::Text),
            (")", TokenType::Punctuation),
            (" ", TokenType::Text),
            ("=>", TokenType::Punctuation),
            (" {\n  ", TokenType::Text),
            ("return", TokenType::Keyword),
            (" ", TokenType::Text),
            ("`Hello, ${", TokenType::String),
            ("name", TokenType::Text),
            ("}!`", TokenType::String),
            ("\n}", TokenType::Punctuation),
        ],
    },
    SyntaxSample {
        language: "Lua",
        tokens: &[
            ("local", TokenType::Keyword),
            (" ", TokenType::Text),
            ("function", TokenType::Keyword),
            (" ", TokenType::Text),
            ("greet", TokenType::Function),
            ("(", TokenType::Punctuation),
            ("name", TokenType::Text),
            (")\n  ", TokenType::Punctuation),
            ("return", TokenType::Keyword),
            (" ", TokenType::Text),
            ("\"Hello, \"", TokenType::String),
            (" ", TokenType::Text),
            ("..", TokenType::Punctuation),
            (" name\n", TokenType::Text),
            ("end", TokenType::Keyword),
        ],
    },
    SyntaxSample {
        language: "Ruby",
        tokens: &[
            ("def", TokenType::Keyword),
            (" ", TokenType::Text),
            ("greet", TokenType::Function),
            ("(", TokenType::Punctuation),
            ("name", TokenType::Text),
            (")\n  ", TokenType::Punctuation),
            ("\"Hello, #{", TokenType::String),
            ("name", TokenType::Text),
            ("}!\"", TokenType::String),
            ("\n", TokenType::Text),
            ("end", TokenType::Keyword),
        ],
    },
    SyntaxSample {
        language: "C#",
        tokens: &[
            ("public", TokenType::Keyword),
            (" ", TokenType::Text),
            ("string", TokenType::Type),
            (" ", TokenType::Text),
            ("Greet", TokenType::Function),
            ("(", TokenType::Punctuation),
            ("string", TokenType::Type),
            (" name", TokenType::Text),
            (") ", TokenType::Punctuation),
            ("=>\n  ", TokenType::Punctuation),
            ("$\"Hello, {", TokenType::String),
            ("name", TokenType::Text),
            ("}!\"", TokenType::String),
            (";", TokenType::Punctuation),
        ],
    },
    SyntaxSample {
        language: "Rust",
        tokens: &[
            ("fn", TokenType::Keyword),
            (" ", TokenType::Text),
            ("greet", TokenType::Function),
            ("(", TokenType::Punctuation),
            ("name", TokenType::Text),
            (": ", TokenType::Punctuation),
            ("&str", TokenType::Type),
            (") ", TokenType::Punctuation),
            ("->", TokenType::Punctuation),
            (" ", TokenType::Text),
            ("String", TokenType::Type),
            (" {\n  ", TokenType::Punctuation),
            ("format!", TokenType::Function),
            ("(", TokenType::Punctuation),
            ("\"Hello, {}!\"", TokenType::String),
            (", name", TokenType::Text),
            (")\n}", TokenType::Punctuation),
        ],
    },
];

/// Set Kitty font size using kitten @
fn set_kitty_font_size(size: f32) {
    let _ = std::process::Command::new("kitten")
        .args(["@", "set-font-size", "--", &format!("{:.1}", size)])
        .spawn();
}

/// Resize Kitty window using hyprctl (since we're in a floating scratchpad)
fn resize_kitty_window(delta_w: i32, delta_h: i32) {
    // Resize and recenter horizontally to grow from center
    let _ = std::process::Command::new("hyprctl")
        .args([
            "--batch",
            &format!(
                "dispatch resizeactive {} {}; dispatch centerwindow 1",
                delta_w, delta_h
            ),
        ])
        .spawn();
}

/// Helper to render a syntax sample into lines
fn render_syntax_sample<'a>(sample: &SyntaxSample, theme: &FlavorTheme) -> Vec<Line<'a>> {
    let mut lines: Vec<Line> = Vec::new();

    // Language header
    lines.push(Line::from(Span::styled(
        sample.language,
        Style::default()
            .fg(theme.subtext0)
            .add_modifier(Modifier::BOLD),
    )));

    // Build spans for the code, handling newlines
    let mut current_spans: Vec<Span> = Vec::new();

    for (text, token_type) in sample.tokens {
        let color = match token_type {
            TokenType::Keyword => theme.mauve,
            TokenType::Function => theme.peach,
            TokenType::String => theme.yellow,
            TokenType::Type => theme.sky,
            TokenType::Punctuation => theme.text,
            TokenType::Text => theme.text,
        };

        // Handle newlines in the text
        let parts: Vec<&str> = text.split('\n').collect();
        for (i, part) in parts.iter().enumerate() {
            if !part.is_empty() {
                current_spans.push(Span::styled(part.to_string(), Style::default().fg(color)));
            }
            if i < parts.len() - 1 {
                // Newline: emit current line and start a new one
                lines.push(Line::from(current_spans.clone()));
                current_spans.clear();
            }
        }
    }

    // Don't forget the last line
    if !current_spans.is_empty() {
        lines.push(Line::from(current_spans));
    }

    lines.push(Line::from("")); // spacing after sample
    lines
}

/// Run the scratchpad preview TUI - displays font samples using native Kitty rendering
/// Returns true if user saved (and apps should be updated), false otherwise
pub fn run_scratchpad_preview(
    font_name: &str,
    config: &Config,
    palette: &Palette,
    config_path: &str,
) -> io::Result<bool> {
    use super::widgets::FontSamples;

    let mut terminal = init()?;
    let theme = FlavorTheme::from_config(config, palette);

    // Track font size - use config's mono_size as initial and set it explicitly
    let initial_size = config.fonts.mono_size as f32;
    let mut current_size = initial_size;
    // Set the font size immediately to ensure kitty matches our tracked state
    set_kitty_font_size(current_size);

    // Track if we saved
    let mut saved = false;

    // Build sections based on font capabilities (detect from name)
    let has_ligatures = font_name.contains("Fira")
        || font_name.contains("JetBrains")
        || font_name.contains("Cascadia")
        || font_name.contains("Iosevka")
        || font_name.contains("Victor")
        || font_name.contains("Hasklug");
    let is_nerd_font = font_name.contains("Nerd");

    let mut sections: Vec<ScratchpadSection> = vec![
        ScratchpadSection::Divider("Variants"),
        ScratchpadSection::Variants,
        ScratchpadSection::Divider("Character Sets"),
        ScratchpadSection::CharacterSet {
            label: "Lowercase",
            chars: FontSamples::LOWERCASE,
        },
        ScratchpadSection::CharacterSet {
            label: "Uppercase",
            chars: FontSamples::UPPERCASE,
        },
        ScratchpadSection::CharacterSet {
            label: "Digits",
            chars: FontSamples::DIGITS,
        },
        ScratchpadSection::CharacterSet {
            label: "Symbols",
            chars: FontSamples::SYMBOLS,
        },
    ];

    if has_ligatures {
        sections.push(ScratchpadSection::Divider("Ligatures"));
        sections.push(ScratchpadSection::CharacterSet {
            label: "Common",
            chars: FontSamples::LIGATURES,
        });
    }

    if is_nerd_font {
        sections.push(ScratchpadSection::Divider("Nerd Font Icons"));
        sections.push(ScratchpadSection::CharacterSet {
            label: "Icons",
            chars: FontSamples::NERD_GLYPHS,
        });
    }

    // Scroll state for left pane
    let mut left_scroll: u16 = 0;
    let mut left_height: u16 = 0;
    // Scroll state for right pane
    let mut right_scroll: u16 = 0;
    let mut right_height: u16 = 0;
    // Which pane has focus (for scrolling)
    let mut focus_right = false;

    loop {
        terminal.draw(|frame| {
            let area = frame.area();

            // Background
            frame.render_widget(
                Block::default().style(Style::default().bg(theme.base)),
                area,
            );

            // Main layout: header, content, footer
            let outer = Layout::default()
                .direction(Direction::Vertical)
                .constraints([
                    Constraint::Length(2),
                    Constraint::Min(0),
                    Constraint::Length(1),
                ])
                .split(area);

            // Header: font name and size
            let header = Line::from(vec![
                Span::styled(
                    format!(" {}", font_name),
                    Style::default()
                        .fg(theme.accent)
                        .add_modifier(Modifier::BOLD),
                ),
                Span::styled(
                    format!(" [{:.0}pt]", current_size),
                    Style::default().fg(theme.subtext0),
                ),
            ]);
            frame.render_widget(Paragraph::new(header), outer[0]);

            // Two-pane layout for content
            let panes = Layout::default()
                .direction(Direction::Horizontal)
                .constraints([Constraint::Percentage(55), Constraint::Percentage(45)])
                .split(outer[1]);

            // Left pane: character samples
            let left_block = Block::default()
                .borders(Borders::RIGHT)
                .border_style(Style::default().fg(theme.surface1));
            let left_inner = left_block.inner(panes[0]);
            frame.render_widget(left_block, panes[0]);

            let mut left_lines: Vec<Line> = Vec::new();
            for section in &sections {
                match section {
                    ScratchpadSection::Divider(label) => {
                        left_lines.push(Line::from(""));
                        left_lines.push(Line::from(Span::styled(
                            format!("─── {} ───", label),
                            Style::default()
                                .fg(theme.subtext0)
                                .add_modifier(Modifier::BOLD),
                        )));
                        left_lines.push(Line::from(""));
                    }
                    ScratchpadSection::Variants => {
                        let sample = FontSamples::PANGRAM;
                        left_lines.push(Line::from(vec![
                            Span::styled("Regular:     ", Style::default().fg(theme.subtext0)),
                            Span::styled(sample, Style::default().fg(theme.text)),
                        ]));
                        left_lines.push(Line::from(vec![
                            Span::styled("Bold:        ", Style::default().fg(theme.subtext0)),
                            Span::styled(
                                sample,
                                Style::default().fg(theme.text).add_modifier(Modifier::BOLD),
                            ),
                        ]));
                        left_lines.push(Line::from(vec![
                            Span::styled("Italic:      ", Style::default().fg(theme.subtext0)),
                            Span::styled(
                                sample,
                                Style::default()
                                    .fg(theme.text)
                                    .add_modifier(Modifier::ITALIC),
                            ),
                        ]));
                        left_lines.push(Line::from(vec![
                            Span::styled("Bold Italic: ", Style::default().fg(theme.subtext0)),
                            Span::styled(
                                sample,
                                Style::default()
                                    .fg(theme.text)
                                    .add_modifier(Modifier::BOLD)
                                    .add_modifier(Modifier::ITALIC),
                            ),
                        ]));
                        left_lines.push(Line::from(""));
                    }
                    ScratchpadSection::CharacterSet { label, chars } => {
                        left_lines.push(Line::from(Span::styled(
                            format!("{}: ", label),
                            Style::default().fg(theme.subtext0),
                        )));
                        left_lines.push(Line::from(Span::styled(
                            format!("  {}", chars),
                            Style::default().fg(theme.text),
                        )));
                        left_lines.push(Line::from(""));
                    }
                }
            }

            left_height = left_lines.len() as u16;
            let left_max_scroll = left_height.saturating_sub(left_inner.height);
            left_scroll = left_scroll.min(left_max_scroll);

            let visible_left: Vec<Line> = left_lines
                .into_iter()
                .skip(left_scroll as usize)
                .take(left_inner.height as usize)
                .collect();
            frame.render_widget(Paragraph::new(visible_left), left_inner);

            // Left scrollbar
            if left_height > left_inner.height {
                let scrollbar = Scrollbar::new(ScrollbarOrientation::VerticalRight).style(
                    Style::default().fg(if focus_right {
                        theme.surface0
                    } else {
                        theme.surface1
                    }),
                );
                let mut state =
                    ScrollbarState::new(left_height as usize).position(left_scroll as usize);
                frame.render_stateful_widget(scrollbar, left_inner, &mut state);
            }

            // Right pane: syntax samples
            let right_inner = panes[1];
            let mut right_lines: Vec<Line> = Vec::new();

            right_lines.push(Line::from(Span::styled(
                "─── Syntax Highlighting ───",
                Style::default()
                    .fg(theme.subtext0)
                    .add_modifier(Modifier::BOLD),
            )));
            right_lines.push(Line::from(""));

            for sample in SYNTAX_SAMPLES {
                right_lines.extend(render_syntax_sample(sample, &theme));
            }

            right_height = right_lines.len() as u16;
            let right_max_scroll = right_height.saturating_sub(right_inner.height);
            right_scroll = right_scroll.min(right_max_scroll);

            let visible_right: Vec<Line> = right_lines
                .into_iter()
                .skip(right_scroll as usize)
                .take(right_inner.height as usize)
                .collect();
            frame.render_widget(Paragraph::new(visible_right), right_inner);

            // Right scrollbar
            if right_height > right_inner.height {
                let scrollbar = Scrollbar::new(ScrollbarOrientation::VerticalRight).style(
                    Style::default().fg(if focus_right {
                        theme.surface1
                    } else {
                        theme.surface0
                    }),
                );
                let mut state =
                    ScrollbarState::new(right_height as usize).position(right_scroll as usize);
                frame.render_stateful_widget(scrollbar, right_inner, &mut state);
            }

            // Footer
            let footer = Line::from(vec![
                Span::styled("+/-", Style::default().fg(theme.accent)),
                Span::styled(" size  ", Style::default().fg(theme.subtext0)),
                Span::styled("0", Style::default().fg(theme.accent)),
                Span::styled(" reset  ", Style::default().fg(theme.subtext0)),
                Span::styled("Tab", Style::default().fg(theme.accent)),
                Span::styled(" pane  ", Style::default().fg(theme.subtext0)),
                Span::styled("Enter", Style::default().fg(theme.green)),
                Span::styled(" save  ", Style::default().fg(theme.subtext0)),
                Span::styled("q", Style::default().fg(theme.accent)),
                Span::styled("/", Style::default().fg(theme.subtext0)),
                Span::styled("Esc", Style::default().fg(theme.accent)),
                Span::styled(" close", Style::default().fg(theme.subtext0)),
            ]);
            frame.render_widget(Paragraph::new(footer).centered(), outer[2]);
        })?;

        // Handle input
        if event::poll(std::time::Duration::from_millis(100))? {
            let (scroll, height) = if focus_right {
                (&mut right_scroll, right_height)
            } else {
                (&mut left_scroll, left_height)
            };
            let visible = terminal.size()?.height.saturating_sub(4);
            let max_scroll = height.saturating_sub(visible);

            match event::read()? {
                Event::Key(key) if key.kind == KeyEventKind::Press => match key.code {
                    KeyCode::Char('q') | KeyCode::Esc => break,
                    KeyCode::Tab => {
                        focus_right = !focus_right;
                    }
                    KeyCode::Enter => {
                        // Save font and size to config
                        let mut cfg = config.clone();
                        cfg.fonts.mono = font_name.to_string();
                        cfg.fonts.mono_size = current_size as u32;
                        if cfg.save(config_path).is_ok() {
                            saved = true;
                            break;
                        }
                    }
                    KeyCode::Char('+') | KeyCode::Char('=') => {
                        current_size += 1.0;
                        set_kitty_font_size(current_size);
                        resize_kitty_window(40, 45);
                    }
                    KeyCode::Char('-') | KeyCode::Char('_') => {
                        if current_size > 6.0 {
                            current_size -= 1.0;
                            set_kitty_font_size(current_size);
                            resize_kitty_window(-40, -45);
                        }
                    }
                    KeyCode::Char('0') => {
                        let delta = (current_size - initial_size) as i32;
                        current_size = initial_size;
                        set_kitty_font_size(current_size);
                        resize_kitty_window(-delta * 40, -delta * 45);
                    }
                    KeyCode::Char('j') | KeyCode::Down => {
                        *scroll = (*scroll + 1).min(max_scroll);
                    }
                    KeyCode::Char('k') | KeyCode::Up => {
                        *scroll = scroll.saturating_sub(1);
                    }
                    KeyCode::Char('g') => {
                        *scroll = 0;
                    }
                    KeyCode::Char('G') => {
                        *scroll = max_scroll;
                    }
                    KeyCode::Char('d') if key.modifiers.contains(KeyModifiers::CONTROL) => {
                        *scroll = (*scroll + visible / 2).min(max_scroll);
                    }
                    KeyCode::Char('u') if key.modifiers.contains(KeyModifiers::CONTROL) => {
                        *scroll = scroll.saturating_sub(visible / 2);
                    }
                    _ => {}
                },
                Event::Mouse(mouse) => match mouse.kind {
                    MouseEventKind::ScrollDown => {
                        *scroll = (*scroll + 3).min(max_scroll);
                    }
                    MouseEventKind::ScrollUp => {
                        *scroll = scroll.saturating_sub(3);
                    }
                    _ => {}
                },
                _ => {}
            }
        }
    }

    restore()?;

    if saved {
        // Print confirmation before window closes
        println!("Saved: {} @ {:.0}pt", font_name, current_size);

        // Run cfg update to apply changes to apps that use the mono font
        // Use current_exe to get the path to cfg binary
        if let Ok(exe) = std::env::current_exe() {
            let _ = std::process::Command::new(exe).arg("update").status(); // wait for completion
        }
    }

    // Kill the scratchpad window so pypr spawns fresh next time
    let _ = std::process::Command::new("hyprctl")
        .args(["dispatch", "killwindow", "class:fonts_scratch"])
        .spawn();

    Ok(saved)
}
