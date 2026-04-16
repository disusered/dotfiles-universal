use std::io;

use crossterm::event::{Event, KeyCode, KeyEventKind};
use ratatui::{
    layout::{Constraint, Direction, Layout, Margin, Rect},
    style::{Color, Modifier, Style},
    text::{Line, Span},
    widgets::{Block, Borders, List, ListItem, ListState, Paragraph, Scrollbar, ScrollbarOrientation, ScrollbarState},
    Frame,
};

use crate::palette::Palette;
use crate::templates::{run_update, ReloadResult, RenderResult, TemplatesFile};

use super::widgets::{FuzzyInput, FuzzyInputState};

#[derive(Debug, Clone)]
struct UnitEntry {
    name: String,
    has_reload: bool,
    selected: bool,
}

#[derive(Debug, Clone, Copy, PartialEq)]
enum Mode {
    Normal,
    Search,
    Results,
}

struct Theme {
    base: Color,
    text: Color,
    subtext0: Color,
    surface0: Color,
    surface1: Color,
    overlay1: Color,
    green: Color,
    red: Color,
    accent: Color,
}

impl Theme {
    fn from_palette(palette: &Palette, primary: &str) -> Self {
        let get = |name: &str| -> Color {
            palette
                .get(name)
                .map(|c| Color::Rgb(c.r, c.g, c.b))
                .unwrap_or(Color::White)
        };
        Self {
            base: get("base"),
            text: get("text"),
            subtext0: get("subtext0"),
            surface0: get("surface0"),
            surface1: get("surface1"),
            overlay1: get("overlay1"),
            green: get("green"),
            red: get("red"),
            accent: get(primary),
        }
    }
}

pub struct UpdatePicker {
    units: Vec<UnitEntry>,
    list_state: ListState,
    search: FuzzyInputState,
    filtered: Vec<usize>,
    selected: usize,
    mode: Mode,
    theme: Theme,
    cfg_dir: String,
    dotfiles_dir: String,
    render_results: Vec<RenderResult>,
    reload_results: Vec<ReloadResult>,
    results_scroll: u16,
}

impl UpdatePicker {
    pub fn new(
        palette: &Palette,
        primary: &str,
        cfg_dir: String,
        dotfiles_dir: String,
    ) -> Self {
        let theme = Theme::from_palette(palette, primary);

        let templates_path = format!("{}/templates.toml", cfg_dir);
        let templates = TemplatesFile::load(&templates_path).unwrap_or_else(|_| {
            TemplatesFile { templates: std::collections::HashMap::new() }
        });

        let mut units: Vec<UnitEntry> = templates
            .templates
            .iter()
            .map(|(name, config)| UnitEntry {
                name: name.clone(),
                has_reload: config.reload.is_some(),
                selected: false,
            })
            .collect();
        units.sort_by(|a, b| a.name.cmp(&b.name));

        let filtered: Vec<usize> = (0..units.len()).collect();

        Self {
            units,
            list_state: ListState::default().with_selected(Some(0)),
            search: FuzzyInputState::new(),
            filtered,
            selected: 0,
            mode: Mode::Normal,
            theme,
            cfg_dir,
            dotfiles_dir,
            render_results: Vec::new(),
            reload_results: Vec::new(),
            results_scroll: 0,
        }
    }

    fn refilter(&mut self) {
        self.filtered = self
            .search
            .filter(&self.units, |u| &u.name)
            .into_iter()
            .map(|(idx, _)| idx)
            .collect();

        self.selected = 0;
        self.list_state.select(if self.filtered.is_empty() { None } else { Some(0) });
    }

    fn selected_unit_index(&self) -> Option<usize> {
        self.filtered.get(self.selected).copied()
    }

    fn toggle_selected(&mut self) {
        if let Some(idx) = self.selected_unit_index() {
            self.units[idx].selected = !self.units[idx].selected;
        }
    }

    fn toggle_all(&mut self) {
        let all_selected = self.filtered.iter().all(|&i| self.units[i].selected);
        for &i in &self.filtered {
            self.units[i].selected = !all_selected;
        }
    }

    fn selected_names(&self) -> Vec<String> {
        self.units
            .iter()
            .filter(|u| u.selected)
            .map(|u| u.name.clone())
            .collect()
    }

    fn run_update(&mut self) {
        let names = self.selected_names();
        if names.is_empty() {
            return;
        }

        match run_update(&self.cfg_dir, &self.dotfiles_dir, &names) {
            Ok(result) => {
                self.render_results = result.rendered;
                self.reload_results = result.reloaded;
            }
            Err(e) => {
                self.render_results = vec![RenderResult {
                    name: "error".to_string(),
                    output: Err(e),
                }];
                self.reload_results = Vec::new();
            }
        }

        self.results_scroll = 0;
        self.mode = Mode::Results;
    }

    // ── Rendering ──────────────────────────────────────────────────────

    pub fn render_in_area(&mut self, frame: &mut Frame, area: Rect) {
        frame.render_widget(
            Block::default().style(Style::default().bg(self.theme.base)),
            area,
        );

        match self.mode {
            Mode::Results => self.render_results_view(frame, area),
            _ => {
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
            }
        }
    }

    fn render_header(&mut self, frame: &mut Frame, area: Rect) {
        let selected_count = self.units.iter().filter(|u| u.selected).count();
        let title = if selected_count > 0 {
            format!(" cfg update  {} selected ", selected_count)
        } else {
            " cfg update ".to_string()
        };

        let block = Block::default()
            .borders(Borders::ALL)
            .border_style(Style::default().fg(self.theme.surface1))
            .title(Span::styled(
                title,
                Style::default()
                    .fg(self.theme.accent)
                    .add_modifier(Modifier::BOLD),
            ));

        let inner = block.inner(area);
        frame.render_widget(block, area);

        let search_widget = FuzzyInput::default()
            .style(Style::default().fg(self.theme.text))
            .cursor_style(Style::default().fg(self.theme.base).bg(self.theme.text))
            .border_style(Style::default().fg(self.theme.overlay1));

        frame.render_stateful_widget(search_widget, inner, &mut self.search);
    }

    fn render_content(&mut self, frame: &mut Frame, area: Rect) {
        let block = Block::default()
            .borders(Borders::ALL)
            .border_style(Style::default().fg(self.theme.surface1))
            .title(Span::styled(
                " Templates ",
                Style::default().fg(self.theme.overlay1),
            ))
            .title_bottom(Line::from(vec![
                Span::styled(" 󰑓", Style::default().fg(self.theme.overlay1)),
                Span::styled(" has reload ", Style::default().fg(self.theme.surface1)),
            ]));

        let inner = block.inner(area);
        frame.render_widget(block, area);

        let items: Vec<ListItem> = self
            .filtered
            .iter()
            .enumerate()
            .map(|(vis_idx, &unit_idx)| {
                let unit = &self.units[unit_idx];
                let is_selected = vis_idx == self.selected;

                let mut spans = vec![Span::raw("  ")];

                // Checkbox
                if unit.selected {
                    spans.push(Span::styled("✓ ", Style::default().fg(self.theme.green)));
                } else {
                    spans.push(Span::styled("  ", Style::default()));
                }

                // Name with fuzzy highlight
                let name_style = if unit.selected {
                    Style::default().fg(self.theme.text)
                } else {
                    Style::default().fg(self.theme.subtext0)
                };

                if self.search.is_empty() {
                    spans.push(Span::styled(
                        format!("{:<30}", unit.name),
                        name_style,
                    ));
                } else {
                    let highlight_style = name_style
                        .fg(self.theme.accent)
                        .add_modifier(Modifier::BOLD);
                    let highlighted = self.search.highlight(&unit.name, name_style, highlight_style);
                    for span in highlighted.spans {
                        spans.push(span);
                    }
                    let padding = 30usize.saturating_sub(unit.name.len());
                    spans.push(Span::raw(" ".repeat(padding)));
                }

                // Reload indicator
                if unit.has_reload {
                    spans.push(Span::styled("󰑓", Style::default().fg(self.theme.overlay1)));
                }

                let style = if is_selected {
                    Style::default().bg(self.theme.surface0)
                } else {
                    Style::default()
                };

                ListItem::new(Line::from(spans)).style(style)
            })
            .collect();

        let list = List::new(items);
        frame.render_stateful_widget(list, inner, &mut self.list_state);

        // Scrollbar
        if self.filtered.len() > inner.height as usize {
            let scrollbar = Scrollbar::new(ScrollbarOrientation::VerticalRight)
                .style(Style::default().fg(self.theme.surface1));
            let mut scrollbar_state =
                ScrollbarState::new(self.filtered.len()).position(self.selected);
            frame.render_stateful_widget(
                scrollbar,
                area.inner(Margin { horizontal: 0, vertical: 1 }),
                &mut scrollbar_state,
            );
        }
    }

    fn render_footer(&self, frame: &mut Frame, area: Rect) {
        let selected_count = self.units.iter().filter(|u| u.selected).count();
        let enter_label = if selected_count > 0 {
            format!("update ({})", selected_count)
        } else {
            "update".to_string()
        };

        let hints: Vec<(&str, String)> = vec![
            ("j/k", "navigate".to_string()),
            ("Space", "toggle".to_string()),
            ("a", "all".to_string()),
            ("Enter", enter_label),
            ("/", "search".to_string()),
            ("q/Esc", "quit".to_string()),
        ];

        let spans: Vec<Span> = hints
            .iter()
            .enumerate()
            .flat_map(|(i, (key, desc))| {
                let mut s = vec![
                    Span::styled(*key, Style::default().fg(self.theme.accent)),
                    Span::styled(format!(" {} ", desc), Style::default().fg(self.theme.overlay1)),
                ];
                if i < hints.len() - 1 {
                    s.push(Span::raw(" "));
                }
                s
            })
            .collect();

        frame.render_widget(Paragraph::new(Line::from(spans)), area);
    }

    fn render_results_view(&self, frame: &mut Frame, area: Rect) {
        let chunks = Layout::default()
            .direction(Direction::Vertical)
            .constraints([
                Constraint::Length(3),
                Constraint::Min(10),
                Constraint::Length(1),
            ])
            .split(area);

        // Header
        let ok_count = self.render_results.iter().filter(|r| r.output.is_ok()).count();
        let fail_count = self.render_results.iter().filter(|r| r.output.is_err()).count();
        let title = if fail_count > 0 {
            format!(" cfg update  {} ok, {} failed ", ok_count, fail_count)
        } else {
            format!(" cfg update  {} ok ", ok_count)
        };

        let header_block = Block::default()
            .borders(Borders::ALL)
            .border_style(Style::default().fg(self.theme.surface1))
            .title(Span::styled(
                title,
                Style::default()
                    .fg(if fail_count > 0 { self.theme.red } else { self.theme.green })
                    .add_modifier(Modifier::BOLD),
            ));
        frame.render_widget(header_block, chunks[0]);

        // Content
        let content_block = Block::default()
            .borders(Borders::ALL)
            .border_style(Style::default().fg(self.theme.surface1));
        let inner = content_block.inner(chunks[1]);
        frame.render_widget(content_block, chunks[1]);

        let mut lines: Vec<Line> = Vec::new();

        for r in &self.render_results {
            let (icon, style) = match &r.output {
                Ok(_) => ("✓", Style::default().fg(self.theme.green)),
                Err(_) => ("✗", Style::default().fg(self.theme.red)),
            };
            let detail = match &r.output {
                Ok(path) => format!("  →  {}", path.display()),
                Err(e) => format!("  {}", e),
            };
            lines.push(Line::from(vec![
                Span::styled(format!("  {} ", icon), style),
                Span::styled(&r.name, Style::default().fg(self.theme.text)),
                Span::styled(detail, Style::default().fg(self.theme.subtext0)),
            ]));
        }

        if !self.reload_results.is_empty() {
            lines.push(Line::from(""));
            lines.push(Line::from(Span::styled(
                "  Reloaded",
                Style::default()
                    .fg(self.theme.overlay1)
                    .add_modifier(Modifier::BOLD),
            )));
            for r in &self.reload_results {
                let label = r.names.join(", ");
                let (icon, style) = match &r.result {
                    Ok(()) => ("✓", Style::default().fg(self.theme.green)),
                    Err(_) => ("✗", Style::default().fg(self.theme.red)),
                };
                let detail = match &r.result {
                    Ok(()) => String::new(),
                    Err(e) => format!("  {}", e),
                };
                lines.push(Line::from(vec![
                    Span::styled(format!("  {} ", icon), style),
                    Span::styled(label, Style::default().fg(self.theme.text)),
                    Span::styled(detail, Style::default().fg(self.theme.red)),
                ]));
            }
        }

        let content = Paragraph::new(lines).scroll((self.results_scroll, 0));
        frame.render_widget(content, inner);

        // Footer
        let footer = Line::from(vec![
            Span::styled("any key", Style::default().fg(self.theme.accent)),
            Span::styled(" return ", Style::default().fg(self.theme.overlay1)),
        ]);
        frame.render_widget(Paragraph::new(footer), chunks[2]);
    }

    // ── Event handling ─────────────────────────────────────────────────

    pub fn handle_event(&mut self, event: Event) -> io::Result<bool> {
        match self.mode {
            Mode::Results => self.handle_results_event(event),
            Mode::Search => self.handle_search_event(event),
            Mode::Normal => self.handle_normal_event(event),
        }
    }

    fn handle_results_event(&mut self, event: Event) -> io::Result<bool> {
        if let Event::Key(key) = event {
            if key.kind == KeyEventKind::Press {
                self.mode = Mode::Normal;
                for unit in &mut self.units {
                    unit.selected = false;
                }
            }
        }
        Ok(true)
    }

    fn handle_search_event(&mut self, event: Event) -> io::Result<bool> {
        if let Event::Key(key) = event {
            if key.kind == KeyEventKind::Press {
                match key.code {
                    KeyCode::Esc => {
                        self.search.clear();
                        self.refilter();
                        self.mode = Mode::Normal;
                    }
                    KeyCode::Enter => {
                        self.mode = Mode::Normal;
                    }
                    KeyCode::Backspace => {
                        self.search.backspace();
                        self.refilter();
                    }
                    KeyCode::Delete => {
                        self.search.delete();
                        self.refilter();
                    }
                    KeyCode::Left => self.search.move_left(),
                    KeyCode::Right => self.search.move_right(),
                    KeyCode::Home => self.search.move_start(),
                    KeyCode::End => self.search.move_end(),
                    KeyCode::Char(c) => {
                        self.search.insert(c);
                        self.refilter();
                    }
                    _ => {}
                }
            }
        }
        Ok(true)
    }

    fn handle_normal_event(&mut self, event: Event) -> io::Result<bool> {
        if let Event::Key(key) = event {
            if key.kind == KeyEventKind::Press {
                match key.code {
                    KeyCode::Char('q') | KeyCode::Esc => return Ok(false),
                    KeyCode::Char('/') => {
                        self.mode = Mode::Search;
                    }
                    KeyCode::Char(' ') => {
                        self.toggle_selected();
                        self.move_down();
                    }
                    KeyCode::Char('a') => {
                        self.toggle_all();
                    }
                    KeyCode::Enter => {
                        self.run_update();
                    }
                    KeyCode::Char('j') | KeyCode::Down => {
                        self.move_down();
                    }
                    KeyCode::Char('k') | KeyCode::Up => {
                        self.move_up();
                    }
                    KeyCode::Char('g') => {
                        if !self.filtered.is_empty() {
                            self.selected = 0;
                            self.list_state.select(Some(0));
                        }
                    }
                    KeyCode::Char('G') => {
                        if !self.filtered.is_empty() {
                            self.selected = self.filtered.len() - 1;
                            self.list_state.select(Some(self.selected));
                        }
                    }
                    _ => {}
                }
            }
        }
        Ok(true)
    }

    fn move_down(&mut self) {
        if self.selected + 1 < self.filtered.len() {
            self.selected += 1;
            self.list_state.select(Some(self.selected));
        }
    }

    fn move_up(&mut self) {
        if self.selected > 0 {
            self.selected -= 1;
            self.list_state.select(Some(self.selected));
        }
    }

    pub fn is_in_search(&self) -> bool {
        self.mode == Mode::Search
    }

    #[allow(dead_code)]
    pub fn wants_apply(&self) -> bool {
        false
    }

    #[allow(dead_code)]
    pub fn was_saved(&self) -> bool {
        false
    }
}
