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

use crate::config::Config;
use crate::palette::Palette;
use crate::wallpaper;

use super::widgets::{FuzzyInput, FuzzyInputState};
use super::{init, restore};

#[derive(Debug, Clone, Copy, PartialEq)]
enum Mode {
    Normal,
    Search,
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
    all: Vec<PathBuf>,
    names: Vec<String>,
    filtered: Vec<usize>,
    selected: usize,
    list_state: ListState,
    search: FuzzyInputState,
    mode: Mode,
    picker: Option<Picker>,
    protocols: HashMap<PathBuf, StatefulProtocol>,
    decode_failures: HashMap<PathBuf, String>,
    original_path: String,
    desktop_preview_active: bool,
    should_apply: bool,
    config: Config,
    config_path: String,
    cfg_dir: String,
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
        let all = enumerate_wallpapers(&expanded)?;
        if all.is_empty() {
            return Err(format!("no wallpapers in {}", expanded));
        }

        let names: Vec<String> = all
            .iter()
            .map(|p| {
                p.file_name()
                    .and_then(|s| s.to_str())
                    .unwrap_or("?")
                    .to_string()
            })
            .collect();

        let filtered: Vec<usize> = (0..all.len()).collect();
        let mut list_state = ListState::default();
        list_state.select(Some(0));

        let picker = Picker::from_query_stdio().ok();
        let theme = FlavorTheme::from_config(&config, palette);
        let original_path = config.wallpaper.path.clone();

        Ok(Self {
            all,
            names,
            filtered,
            selected: 0,
            list_state,
            search: FuzzyInputState::new(),
            mode: Mode::Normal,
            picker,
            protocols: HashMap::new(),
            decode_failures: HashMap::new(),
            original_path,
            desktop_preview_active: false,
            should_apply: false,
            config,
            config_path,
            cfg_dir,
            theme,
            flash: None,
        })
    }

    fn selected_path(&self) -> Option<&Path> {
        self.filtered
            .get(self.selected)
            .and_then(|&i| self.all.get(i))
            .map(|p| p.as_path())
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
        let ranked = self.search.filter(&self.names, |n| n.as_str());
        self.filtered = ranked.into_iter().map(|(i, _)| i).collect();
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

        // Footer (1 line) + body
        let vchunks = Layout::default()
            .direction(Direction::Vertical)
            .constraints([Constraint::Min(1), Constraint::Length(1)])
            .split(inner);

        let body = vchunks[0];
        let footer = vchunks[1];

        let hchunks = Layout::default()
            .direction(Direction::Horizontal)
            .constraints([Constraint::Percentage(40), Constraint::Percentage(60)])
            .split(body);

        let list_area = hchunks[0];
        let preview_area = hchunks[1];

        self.render_list(f, list_area);
        self.render_preview(f, preview_area);
        self.render_footer(f, footer);
    }

    fn title(&self) -> String {
        let count = self.filtered.len();
        let total = self.all.len();
        let preview_tag = if self.desktop_preview_active {
            " · DESKTOP PREVIEW"
        } else {
            ""
        };
        format!(" cfg wallpaper -i · {}/{}{} ", count, total, preview_tag)
    }

    fn render_list(&mut self, f: &mut Frame, area: Rect) {
        let items: Vec<ListItem> = self
            .filtered
            .iter()
            .filter_map(|&i| self.all.get(i))
            .map(|p| {
                let name = p
                    .file_name()
                    .and_then(|s| s.to_str())
                    .unwrap_or("?")
                    .to_string();
                let is_current = p.to_string_lossy() == expand_tilde(&self.original_path);
                let marker = if is_current { "● " } else { "  " };
                let style = if is_current {
                    Style::default().fg(self.theme.accent).add_modifier(Modifier::BOLD)
                } else {
                    Style::default().fg(self.theme.text)
                };
                ListItem::new(Line::from(vec![
                    Span::styled(marker, Style::default().fg(self.theme.accent)),
                    Span::styled(name, style),
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
            "↑/↓ navigate  p scratchpad  d desktop-preview  / search  enter apply  q quit".to_string()
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

    fn toggle_desktop_preview(&mut self, path: &Path) {
        if self.desktop_preview_active {
            self.revert_desktop_preview();
        } else {
            self.apply_desktop_preview(path);
        }
    }

    fn apply_desktop_preview(&mut self, path: &Path) {
        let mut tmp = self.config.clone();
        tmp.wallpaper.path = path.to_string_lossy().into_owned();
        match wallpaper::apply(&tmp, &self.cfg_dir) {
            Ok(()) => {
                self.desktop_preview_active = true;
                self.flash = Some("desktop preview: press d to revert, enter to keep".into());
            }
            Err(e) => {
                self.flash = Some(format!("preview failed: {}", e));
            }
        }
    }

    fn revert_desktop_preview(&mut self) {
        if !self.desktop_preview_active {
            return;
        }
        let mut revert = self.config.clone();
        revert.wallpaper.path = self.original_path.clone();
        let _ = wallpaper::apply(&revert, &self.cfg_dir);
        self.desktop_preview_active = false;
        self.flash = Some("reverted".into());
    }

    fn commit_selection(&mut self, path: &Path) -> Result<(), String> {
        self.config.wallpaper.path = path.to_string_lossy().into_owned();
        self.config
            .save(&self.config_path)
            .map_err(|e| format!("save config: {}", e))?;
        self.should_apply = true;
        Ok(())
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

    if picker.desktop_preview_active {
        picker.revert_desktop_preview();
    }
    match outcome {
        Ok(()) => {
            if picker.should_apply {
                Ok(Some(true))
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
        match ev {
            Event::Key(k) if k.kind == KeyEventKind::Press => match (picker.mode, k.code) {
                (Mode::Search, KeyCode::Esc) => {
                    picker.mode = Mode::Normal;
                    picker.search.clear();
                    picker.update_filter();
                }
                (Mode::Search, KeyCode::Enter) => {
                    picker.mode = Mode::Normal;
                }
                (Mode::Search, KeyCode::Backspace) => {
                    picker.search.backspace();
                    picker.update_filter();
                }
                (Mode::Search, KeyCode::Char(c)) => {
                    picker.search.insert(c);
                    picker.update_filter();
                }
                (Mode::Normal, KeyCode::Char('q') | KeyCode::Esc) => return Ok(()),
                (Mode::Normal, KeyCode::Char('/')) => {
                    picker.mode = Mode::Search;
                    picker.flash = None;
                }
                (Mode::Normal, KeyCode::Up | KeyCode::Char('k')) => {
                    picker.flash = None;
                    picker.move_selection(-1);
                }
                (Mode::Normal, KeyCode::Down | KeyCode::Char('j')) => {
                    picker.flash = None;
                    picker.move_selection(1);
                }
                (Mode::Normal, KeyCode::Char('p')) => {
                    if let Some(p) = picker.selected_path().map(|p| p.to_path_buf()) {
                        picker.open_scratchpad(&p);
                    }
                }
                (Mode::Normal, KeyCode::Char('d')) => {
                    if let Some(p) = picker.selected_path().map(|p| p.to_path_buf()) {
                        picker.toggle_desktop_preview(&p);
                    }
                }
                (Mode::Normal, KeyCode::Enter) => {
                    if let Some(p) = picker.selected_path().map(|p| p.to_path_buf()) {
                        match picker.commit_selection(&p) {
                            Ok(()) => return Ok(()),
                            Err(e) => picker.flash = Some(format!("save failed: {}", e)),
                        }
                    }
                }
                _ => {}
            },
            _ => {}
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
