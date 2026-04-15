use std::collections::HashMap;
use std::io;
use std::path::{Path, PathBuf};
use std::process::Command;

use crossterm::event::{self, Event, KeyCode, KeyEventKind};
use image::ImageReader;
use ratatui::{
    layout::{Constraint, Direction, Layout, Rect},
    style::{Color, Modifier, Style},
    text::{Line, Span},
    widgets::{Block, Borders, List, ListItem, ListState, Paragraph},
    Frame,
};
use ratatui_image::{picker::Picker, protocol::StatefulProtocol, Resize, StatefulImage};

use crate::color::Color as RgbColor;
use crate::config::Config;
use crate::palette::Palette;
use crate::wallpaper;
use crate::wallpaper::picker::MATCH_THRESHOLD;
use crate::wallpaper::tags::TagCache;

use super::widgets::{FuzzyInput, FuzzyInputState};
use super::{init, restore};

#[derive(Debug, Clone, Copy, PartialEq)]
enum Mode {
    Normal,
    Search,
}

struct Entry {
    path: PathBuf,
    name: String,
    score: Option<f32>,
    best_dominant: Option<RgbColor>,
}

struct FlavorTheme {
    base: Color,
    surface0: Color,
    text: Color,
    subtext0: Color,
    accent: Color,
}

impl FlavorTheme {
    fn from_config(config: &Config, palette: &Palette) -> Self {
        let get = |name: &str| -> Color {
            palette
                .get(name)
                .map(|c| Color::Rgb(c.r, c.g, c.b))
                .unwrap_or(Color::White)
        };
        Self {
            base: get("base"),
            surface0: get("surface0"),
            text: get("text"),
            subtext0: get("subtext0"),
            accent: get(&config.primary),
        }
    }
}

pub struct WallpaperPicker {
    entries: Vec<Entry>,
    filtered: Vec<usize>,
    selected: usize,
    list_state: ListState,
    search: FuzzyInputState,
    mode: Mode,
    match_only: bool,
    picker: Option<Picker>,
    protocols: HashMap<PathBuf, StatefulProtocol>,
    decode_failures: HashMap<PathBuf, String>,
    original_path: String,
    previewed_path: Option<PathBuf>,
    should_apply: bool,
    saved: bool,
    config: Config,
    config_path: String,
    cfg_dir: String,
    primary_color: Option<RgbColor>,
    theme: FlavorTheme,
    flash: Option<String>,
}

impl WallpaperPicker {
    pub fn new(
        config: Config,
        palette: &Palette,
        config_path: String,
        cfg_dir: String,
    ) -> Result<Self, String> {
        let source_dir = config.wallpaper.source_dir.trim().to_string();
        if source_dir.is_empty() {
            return Err(
                "wallpaper.source_dir not set; run: cfg wallpaper --set source_dir=<dir>"
                    .to_string(),
            );
        }
        let expanded = expand_tilde(&source_dir);
        let files = enumerate_wallpapers(&expanded)?;
        if files.is_empty() {
            return Err(format!("no wallpapers in {}", expanded));
        }

        let primary_color = palette.get(&config.primary).copied();
        let cache_dir = wallpaper::resolve_cache_dir(&config.wallpaper);
        let tags_path = format!("{}/tags.json", cache_dir);
        let cache = TagCache::load(&tags_path).unwrap_or_default();

        let mut entries: Vec<Entry> = files
            .into_iter()
            .map(|path| {
                let name = path
                    .file_name()
                    .and_then(|s| s.to_str())
                    .unwrap_or("?")
                    .to_string();
                let path_str = path.to_string_lossy().into_owned();
                let (score, best_dominant) = match (&primary_color, cache.get_fresh(&path_str)) {
                    (Some(target), Some(entry)) => {
                        let mut best: Option<(RgbColor, f32)> = None;
                        for d in &entry.dominants {
                            let dist = color_distance(&d.color, target);
                            if best.map(|(_, b)| dist < b).unwrap_or(true) {
                                best = Some((d.color, dist));
                            }
                        }
                        match best {
                            Some((c, d)) => (Some(d), Some(c)),
                            None => (None, None),
                        }
                    }
                    _ => (None, None),
                };
                Entry { path, name, score, best_dominant }
            })
            .collect();

        entries.sort_by(|a, b| match (a.score, b.score) {
            (Some(x), Some(y)) => x.partial_cmp(&y).unwrap_or(std::cmp::Ordering::Equal),
            (Some(_), None) => std::cmp::Ordering::Less,
            (None, Some(_)) => std::cmp::Ordering::Greater,
            (None, None) => a.name.cmp(&b.name),
        });

        let filtered: Vec<usize> = (0..entries.len()).collect();
        let mut list_state = ListState::default();
        list_state.select(Some(0));

        let picker = Picker::from_query_stdio().ok();
        let theme = FlavorTheme::from_config(&config, palette);
        let original_path = config.wallpaper.path.clone();

        Ok(Self {
            entries,
            filtered,
            selected: 0,
            list_state,
            search: FuzzyInputState::new(),
            mode: Mode::Normal,
            match_only: false,
            picker,
            protocols: HashMap::new(),
            decode_failures: HashMap::new(),
            original_path,
            previewed_path: None,
            should_apply: false,
            saved: false,
            config,
            config_path,
            cfg_dir,
            primary_color,
            theme,
            flash: None,
        })
    }

    fn selected_path(&self) -> Option<&Path> {
        self.filtered
            .get(self.selected)
            .and_then(|&i| self.entries.get(i))
            .map(|e| e.path.as_path())
    }

    fn move_selection(&mut self, delta: i32) {
        if self.filtered.is_empty() {
            return;
        }
        let n = self.filtered.len() as i32;
        let next = ((self.selected as i32 + delta).rem_euclid(n)) as usize;
        self.selected = next;
        self.list_state.select(Some(next));
    }

    fn update_filter(&mut self) {
        let ranked = self.search.filter(&self.entries, |e| e.name.as_str());
        let indexes: Vec<usize> = if self.match_only {
            ranked
                .into_iter()
                .filter_map(|(i, _)| {
                    self.entries
                        .get(i)
                        .and_then(|e| e.score)
                        .filter(|s| *s < MATCH_THRESHOLD)
                        .map(|_| i)
                })
                .collect()
        } else {
            ranked.into_iter().map(|(i, _)| i).collect()
        };
        self.filtered = indexes;
        self.selected = 0;
        self.list_state
            .select(if self.filtered.is_empty() { None } else { Some(0) });
    }

    fn ensure_protocol(&mut self, path: &Path) {
        if self.protocols.contains_key(path) || self.decode_failures.contains_key(path) {
            return;
        }
        let picker = match &mut self.picker {
            Some(p) => p,
            None => {
                self.decode_failures
                    .insert(path.to_path_buf(), "terminal graphics not supported".into());
                return;
            }
        };
        let img = match ImageReader::open(path).and_then(|r| r.with_guessed_format()) {
            Ok(r) => match r.decode() {
                Ok(i) => i,
                Err(e) => {
                    self.decode_failures
                        .insert(path.to_path_buf(), format!("decode: {}", e));
                    return;
                }
            },
            Err(e) => {
                self.decode_failures
                    .insert(path.to_path_buf(), format!("open: {}", e));
                return;
            }
        };
        let protocol = picker.new_resize_protocol(img);
        self.protocols.insert(path.to_path_buf(), protocol);
    }

    fn ui(&mut self, f: &mut Frame) {
        let area = f.area();
        let outer = Block::default()
            .borders(Borders::ALL)
            .title(self.title())
            .style(Style::default().fg(self.theme.text).bg(self.theme.base));
        let inner = outer.inner(area);
        f.render_widget(outer, area);
        self.render_body(f, inner);
    }

    pub fn render_in_area(&mut self, f: &mut Frame, area: Rect) {
        f.render_widget(
            Block::default().style(Style::default().bg(self.theme.base)),
            area,
        );
        self.render_body(f, area);
    }

    fn render_body(&mut self, f: &mut Frame, area: Rect) {
        let vchunks = Layout::default()
            .direction(Direction::Vertical)
            .constraints([Constraint::Min(1), Constraint::Length(1)])
            .split(area);
        let body = vchunks[0];
        let footer = vchunks[1];

        let hchunks = Layout::default()
            .direction(Direction::Horizontal)
            .constraints([Constraint::Percentage(40), Constraint::Percentage(60)])
            .split(body);

        self.render_list(f, hchunks[0]);
        self.render_preview(f, hchunks[1]);
        self.render_footer(f, footer);
    }

    fn title(&self) -> String {
        let count = self.filtered.len();
        let total = self.entries.len();
        let preview_tag = if self.previewed_path.is_some() {
            " · DESKTOP PREVIEW"
        } else {
            ""
        };
        let match_tag = if self.match_only { " · MATCH ONLY" } else { "" };
        format!(
            " cfg wallpaper -i · {}/{}{}{} ",
            count, total, match_tag, preview_tag
        )
    }

    fn render_list(&mut self, f: &mut Frame, area: Rect) {
        let current_expanded = expand_tilde(&self.original_path);
        let items: Vec<ListItem> = self
            .filtered
            .iter()
            .filter_map(|&i| self.entries.get(i))
            .map(|e| {
                let is_current = e.path.to_string_lossy() == current_expanded;
                let marker = if is_current { "● " } else { "  " };

                // Color swatch + score badge
                let (swatch_color, badge_text) = match (e.best_dominant, e.score) {
                    (Some(c), Some(s)) => (
                        Color::Rgb(c.r, c.g, c.b),
                        format!("{:>3.0}", s),
                    ),
                    _ => (self.theme.subtext0, " — ".to_string()),
                };
                let matched = e.score.map(|s| s < MATCH_THRESHOLD).unwrap_or(false);
                let badge_style = if matched {
                    Style::default().fg(self.theme.accent).add_modifier(Modifier::BOLD)
                } else {
                    Style::default().fg(self.theme.subtext0)
                };

                let name_style = if is_current {
                    Style::default().fg(self.theme.accent).add_modifier(Modifier::BOLD)
                } else {
                    Style::default().fg(self.theme.text)
                };

                ListItem::new(Line::from(vec![
                    Span::styled(marker, Style::default().fg(self.theme.accent)),
                    Span::styled("● ", Style::default().fg(swatch_color)),
                    Span::styled(badge_text, badge_style),
                    Span::raw(" "),
                    Span::styled(e.name.clone(), name_style),
                ]))
            })
            .collect();

        let list = List::new(items)
            .block(
                Block::default()
                    .borders(Borders::ALL)
                    .title(" files ")
                    .style(Style::default().fg(self.theme.subtext0)),
            )
            .highlight_style(
                Style::default()
                    .bg(self.theme.surface0)
                    .add_modifier(Modifier::BOLD),
            )
            .highlight_symbol("▶ ");
        f.render_stateful_widget(list, area, &mut self.list_state);
    }

    fn render_preview(&mut self, f: &mut Frame, area: Rect) {
        let block = Block::default()
            .borders(Borders::ALL)
            .title(" preview ")
            .style(Style::default().fg(self.theme.subtext0));
        let inner = block.inner(area);
        f.render_widget(block, area);

        let path = match self.selected_path() {
            Some(p) => p.to_path_buf(),
            None => {
                let p = Paragraph::new("no selection").style(Style::default().fg(self.theme.subtext0));
                f.render_widget(p, inner);
                return;
            }
        };

        self.ensure_protocol(&path);
        if let Some(err) = self.decode_failures.get(&path) {
            let msg = format!("[{}]\n{}", path.display(), err);
            let p = Paragraph::new(msg).style(Style::default().fg(self.theme.subtext0));
            f.render_widget(p, inner);
            return;
        }
        if let Some(protocol) = self.protocols.get_mut(&path) {
            f.render_stateful_widget(StatefulImage::new().resize(Resize::Fit(None)), inner, protocol);
        }
    }

    fn render_footer(&mut self, f: &mut Frame, area: Rect) {
        if self.mode == Mode::Search {
            let input = FuzzyInput::default()
                .style(Style::default().fg(self.theme.text))
                .cursor_style(
                    Style::default()
                        .fg(self.theme.base)
                        .bg(self.theme.text),
                )
                .border_style(Style::default().fg(self.theme.subtext0));
            f.render_stateful_widget(input, area, &mut self.search);
            return;
        }
        let text = if let Some(msg) = &self.flash {
            msg.clone()
        } else {
            let primary = self
                .primary_color
                .map(|_| self.config.primary.as_str())
                .unwrap_or("—");
            format!(
                "↑/↓ nav  p preview  space scratchpad  r revert  m match-only  / search  enter apply  q quit  · primary={}",
                primary
            )
        };
        let style = Style::default().fg(self.theme.subtext0).bg(self.theme.surface0);
        let p = Paragraph::new(text).style(style);
        f.render_widget(p, area);
    }

    fn open_scratchpad(&mut self, path: &Path) {
        let _ = Command::new("hyprctl")
            .args(["dispatch", "killwindow", "class:cfg_wallpaper_scratch"])
            .output();
        let cfg_bin = std::env::current_exe()
            .map(|p| p.to_string_lossy().into_owned())
            .unwrap_or_else(|_| "cfg".to_string());
        let _ = Command::new("kitty")
            .args([
                "--class",
                "cfg_wallpaper_scratch",
                "--name",
                "cfg_wallpaper_scratch",
                &cfg_bin,
                "wallpaper",
                "--scratchpad",
                &path.to_string_lossy(),
            ])
            .spawn();
        self.flash = Some(format!("scratchpad: {}", path.display()));
    }

    fn preview_wallpaper(&mut self, path: &Path) {
        if self.previewed_path.as_deref() == Some(path) {
            return;
        }
        self.apply_desktop_preview(path);
    }

    fn apply_desktop_preview(&mut self, path: &Path) {
        let mut tmp = self.config.clone();
        tmp.wallpaper.path = path.to_string_lossy().into_owned();
        match wallpaper::apply(&tmp, &self.cfg_dir) {
            Ok(()) => {
                self.previewed_path = Some(path.to_path_buf());
                self.flash = Some("preview: r revert, esc/q exit, enter keep".into());
            }
            Err(e) => {
                self.flash = Some(format!("preview failed: {}", e));
            }
        }
    }

    fn revert_desktop_preview(&mut self) {
        if self.previewed_path.is_none() {
            return;
        }
        let mut revert = self.config.clone();
        revert.wallpaper.path = self.original_path.clone();
        let _ = wallpaper::apply(&revert, &self.cfg_dir);
        self.previewed_path = None;
        self.flash = Some("reverted".into());
    }

    fn commit_selection(&mut self, path: &Path) -> Result<(), String> {
        self.config.wallpaper.path = path.to_string_lossy().into_owned();
        self.config
            .save(&self.config_path)
            .map_err(|e| format!("save config: {}", e))?;
        self.saved = true;
        self.should_apply = true;
        Ok(())
    }

    pub fn is_in_search(&self) -> bool {
        self.mode == Mode::Search
    }

    pub fn wants_apply(&self) -> bool {
        self.should_apply
    }

    pub fn was_saved(&self) -> bool {
        self.saved
    }

    /// Handle one input event. Returns `Ok(false)` when the picker wants the
    /// caller to exit (Enter → commit; q/Esc → cancel).
    pub fn handle_event(&mut self, event: Event) -> io::Result<bool> {
        let Event::Key(k) = event else {
            return Ok(true);
        };
        if k.kind != KeyEventKind::Press {
            return Ok(true);
        }
        match (self.mode, k.code) {
            (Mode::Search, KeyCode::Esc) => {
                self.mode = Mode::Normal;
                self.search.clear();
                self.update_filter();
            }
            (Mode::Search, KeyCode::Enter) => {
                self.mode = Mode::Normal;
            }
            (Mode::Search, KeyCode::Backspace) => {
                self.search.backspace();
                self.update_filter();
            }
            (Mode::Search, KeyCode::Char(c)) => {
                self.search.insert(c);
                self.update_filter();
            }
            (Mode::Normal, KeyCode::Char('q') | KeyCode::Esc) => {
                if self.previewed_path.is_some() {
                    self.revert_desktop_preview();
                }
                return Ok(false);
            }
            (Mode::Normal, KeyCode::Char('/')) => {
                self.mode = Mode::Search;
                self.flash = None;
            }
            (Mode::Normal, KeyCode::Up | KeyCode::Char('k')) => {
                self.flash = None;
                self.move_selection(-1);
            }
            (Mode::Normal, KeyCode::Down | KeyCode::Char('j')) => {
                self.flash = None;
                self.move_selection(1);
            }
            (Mode::Normal, KeyCode::Char('m')) => {
                self.match_only = !self.match_only;
                self.update_filter();
                self.flash = None;
            }
            (Mode::Normal, KeyCode::Char('p')) => {
                if let Some(p) = self.selected_path().map(|p| p.to_path_buf()) {
                    self.preview_wallpaper(&p);
                }
            }
            (Mode::Normal, KeyCode::Char(' ')) => {
                if let Some(p) = self.selected_path().map(|p| p.to_path_buf()) {
                    self.open_scratchpad(&p);
                }
            }
            (Mode::Normal, KeyCode::Char('r')) => {
                self.revert_desktop_preview();
            }
            (Mode::Normal, KeyCode::Enter) => {
                if let Some(p) = self.selected_path().map(|p| p.to_path_buf()) {
                    match self.commit_selection(&p) {
                        Ok(()) => return Ok(false),
                        Err(e) => self.flash = Some(format!("save failed: {}", e)),
                    }
                }
            }
            _ => {}
        }
        Ok(true)
    }
}

pub fn run(
    config: &Config,
    palette: &Palette,
    config_path: &str,
    cfg_dir: &str,
) -> io::Result<Option<bool>> {
    let mut picker = match WallpaperPicker::new(
        config.clone(),
        palette,
        config_path.to_string(),
        cfg_dir.to_string(),
    ) {
        Ok(p) => p,
        Err(e) => {
            eprintln!("Error: {}", e);
            return Ok(None);
        }
    };

    let mut terminal = init()?;
    let outcome = event_loop(&mut terminal, &mut picker);
    let _ = restore();

    if picker.previewed_path.is_some() {
        picker.revert_desktop_preview();
    }
    match outcome {
        Ok(()) => {
            if picker.should_apply {
                Ok(Some(true))
            } else if picker.saved {
                Ok(Some(false))
            } else {
                Ok(None)
            }
        }
        Err(e) => Err(e),
    }
}

fn event_loop(terminal: &mut super::Tui, picker: &mut WallpaperPicker) -> io::Result<()> {
    loop {
        terminal.draw(|f| picker.ui(f))?;
        if !event::poll(std::time::Duration::from_millis(200))? {
            continue;
        }
        let ev = event::read()?;
        if !picker.handle_event(ev)? {
            return Ok(());
        }
    }
}

fn expand_tilde(s: &str) -> String {
    if let Some(rest) = s.strip_prefix("~/") {
        if let Ok(home) = std::env::var("HOME") {
            return format!("{}/{}", home, rest);
        }
    }
    if s == "~" {
        if let Ok(home) = std::env::var("HOME") {
            return home;
        }
    }
    s.to_string()
}

fn enumerate_wallpapers(dir: &str) -> Result<Vec<PathBuf>, String> {
    let entries = std::fs::read_dir(dir).map_err(|e| format!("read_dir({}): {}", dir, e))?;
    let mut out = Vec::new();
    for entry in entries.flatten() {
        let path = entry.path();
        if !path.is_file() {
            continue;
        }
        if let Some(ext) = path.extension().and_then(|e| e.to_str()) {
            let lc = ext.to_ascii_lowercase();
            if matches!(lc.as_str(), "jpg" | "jpeg" | "png") {
                out.push(path);
            }
        }
    }
    out.sort();
    Ok(out)
}

fn color_distance(a: &RgbColor, b: &RgbColor) -> f32 {
    let dr = a.r as f32 - b.r as f32;
    let dg = a.g as f32 - b.g as f32;
    let db = a.b as f32 - b.b as f32;
    (dr * dr + dg * dg + db * db).sqrt()
}
