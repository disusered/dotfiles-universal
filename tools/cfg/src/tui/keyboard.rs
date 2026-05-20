use std::io;

use crossterm::event::{Event, KeyCode, KeyEventKind, KeyModifiers, MouseEventKind};
use ratatui::{
    layout::{Constraint, Direction, Layout, Rect},
    style::{Color as TuiColor, Modifier, Style},
    text::{Line, Span},
    widgets::{Block, Borders, List, ListItem, ListState, Paragraph},
    Frame,
};

use crate::config::Config;
use crate::leds::{self, HsvColor, LedEffect, LedStatus, LedValues, SUPPORTED_EFFECTS};
use crate::palette::Palette;

use super::widgets::{FuzzyInput, FuzzyInputState, Toast};

#[derive(Debug, Clone)]
struct EffectEntry {
    effect: &'static LedEffect,
    search_text: String,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
enum Mode {
    Normal,
    Search,
    Preview,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
enum Focus {
    Effects,
    Brightness,
    Speed,
}

impl Focus {
    fn next(self) -> Self {
        match self {
            Focus::Effects => Focus::Brightness,
            Focus::Brightness => Focus::Speed,
            Focus::Speed => Focus::Effects,
        }
    }
}

struct Theme {
    base: TuiColor,
    text: TuiColor,
    subtext0: TuiColor,
    surface1: TuiColor,
    overlay1: TuiColor,
    green: TuiColor,
    yellow: TuiColor,
    red: TuiColor,
    accent: TuiColor,
}

impl Theme {
    fn from_config(config: &Config, palette: &Palette) -> Self {
        let get = |name: &str| -> TuiColor {
            palette
                .get(name)
                .map(|c| TuiColor::Rgb(c.r, c.g, c.b))
                .unwrap_or(TuiColor::White)
        };

        Self {
            base: get("base"),
            text: get("text"),
            subtext0: get("subtext0"),
            surface1: get("surface1"),
            overlay1: get("overlay1"),
            green: get("green"),
            yellow: get("yellow"),
            red: get("red"),
            accent: get(&config.primary),
        }
    }
}

pub struct KeyboardPicker {
    config: Config,
    original_config: Config,
    config_path: String,
    theme: Theme,
    color: HsvColor,
    effects: Vec<EffectEntry>,
    filtered: Vec<usize>,
    selected: usize,
    list_state: ListState,
    search: FuzzyInputState,
    mode: Mode,
    focus: Focus,
    original_statuses: Option<Vec<LedStatus>>,
    preview_touched: bool,
    should_apply: bool,
    saved: bool,
    toast: Option<Toast>,
    content_area: Rect,
}

impl KeyboardPicker {
    pub fn new(config: Config, palette: &Palette, config_path: String) -> Self {
        let theme = Theme::from_config(&config, palette);
        let color = palette
            .get(&config.primary)
            .copied()
            .map(leds::rgb_to_hsv)
            .unwrap_or(HsvColor { h: 0, s: 0 });
        let effects = SUPPORTED_EFFECTS
            .iter()
            .map(|effect| EffectEntry {
                effect,
                search_text: if effect.aliases.is_empty() {
                    effect.name.to_string()
                } else {
                    format!("{} {}", effect.name, effect.aliases.join(" "))
                },
            })
            .collect::<Vec<_>>();
        let selected_effect = leds::resolve_effect(&config.leds.effect).unwrap_or(0);
        let selected = effects
            .iter()
            .position(|entry| entry.effect.id == selected_effect)
            .unwrap_or(0);
        let filtered = (0..effects.len()).collect::<Vec<_>>();

        Self {
            config: config.clone(),
            original_config: config,
            config_path,
            theme,
            color,
            effects,
            filtered,
            selected,
            list_state: ListState::default().with_selected(Some(selected)),
            search: FuzzyInputState::new(),
            mode: Mode::Normal,
            focus: Focus::Effects,
            original_statuses: None,
            preview_touched: false,
            should_apply: false,
            saved: false,
            toast: None,
            content_area: Rect::default(),
        }
    }

    pub fn captures_input(&self) -> bool {
        self.mode != Mode::Normal
    }

    pub fn wants_apply(&self) -> bool {
        self.should_apply
    }

    pub fn was_saved(&self) -> bool {
        self.saved
    }

    pub fn selected_effect_name(&self) -> Option<&'static str> {
        self.selected_effect().map(|effect| effect.name)
    }

    fn active_effect_id(&self) -> Option<u8> {
        leds::resolve_effect(&self.original_config.leds.effect).ok()
    }

    #[cfg(test)]
    fn brightness(&self) -> u8 {
        self.config.leds.brightness
    }

    #[cfg(test)]
    fn speed(&self) -> u8 {
        self.config.leds.speed
    }

    fn selected_effect(&self) -> Option<&'static LedEffect> {
        self.filtered
            .get(self.selected)
            .and_then(|&idx| self.effects.get(idx))
            .map(|entry| entry.effect)
    }

    fn update_filter(&mut self) {
        self.filtered = self
            .search
            .filter(&self.effects, |entry| &entry.search_text)
            .into_iter()
            .map(|(idx, _)| idx)
            .collect();
        self.selected = 0;
        self.list_state.select(if self.filtered.is_empty() {
            None
        } else {
            Some(0)
        });
    }

    fn move_selection(&mut self, delta: isize) {
        if self.filtered.is_empty() {
            return;
        }

        let len = self.filtered.len() as isize;
        self.selected = (self.selected as isize + delta).rem_euclid(len) as usize;
        self.list_state.select(Some(self.selected));
    }

    fn adjust_brightness(&mut self, delta: i16) {
        self.config.leds.brightness = clamp_u8(self.config.leds.brightness, delta);
    }

    fn adjust_speed(&mut self, delta: i16) {
        self.config.leds.speed = clamp_u8(self.config.leds.speed, delta);
    }

    fn values(&self) -> Option<LedValues> {
        self.selected_effect().map(|effect| LedValues {
            brightness: self.config.leds.brightness,
            effect: effect.id,
            speed: self.config.leds.speed,
            color: self.color,
        })
    }

    fn capture_original_statuses(&mut self) {
        if self.original_statuses.is_some() {
            return;
        }

        match leds::read_status(&self.original_config, None, None) {
            Ok(statuses) => {
                self.original_statuses = Some(statuses);
            }
            Err(e) => {
                self.original_statuses = Some(Vec::new());
                self.toast = Some(
                    Toast::new(format!("read failed: {}", e))
                        .style(Style::default().fg(self.theme.yellow))
                        .border_style(Style::default().fg(self.theme.yellow)),
                );
            }
        }
    }

    fn preview_current(&mut self) {
        let Some(values) = self.values() else {
            return;
        };

        self.capture_original_statuses();
        match leds::apply_values(&self.config, &values, false, None, None) {
            Ok(statuses) => {
                if statuses.is_empty() {
                    self.toast = Some(
                        Toast::new("no configured keyboard connected")
                            .style(Style::default().fg(self.theme.yellow))
                            .border_style(Style::default().fg(self.theme.yellow)),
                    );
                } else {
                    self.preview_touched = true;
                    self.toast = Some(
                        Toast::new(format!(
                            "preview: {}",
                            self.selected_effect_name().unwrap_or("unknown")
                        ))
                        .style(Style::default().fg(self.theme.green))
                        .border_style(Style::default().fg(self.theme.green)),
                    );
                }
            }
            Err(e) => {
                self.toast = Some(
                    Toast::new(format!("preview failed: {}", e))
                        .style(Style::default().fg(self.theme.red))
                        .border_style(Style::default().fg(self.theme.red)),
                );
            }
        }
    }

    fn restore_preview(&mut self, reset_config: bool) {
        if !self.preview_touched {
            if reset_config {
                self.config = self.original_config.clone();
            }
            return;
        }

        if let Some(statuses) = &self.original_statuses {
            let _ = leds::restore_statuses(statuses, false);
        }
        if reset_config {
            self.config = self.original_config.clone();
        }
        self.preview_touched = false;
    }

    fn commit(&mut self) -> io::Result<bool> {
        let Some(effect) = self.selected_effect() else {
            return Ok(true);
        };

        self.config.leds.effect = effect.name.to_string();
        if let Err(e) = self.config.save(&self.config_path) {
            self.toast = Some(
                Toast::new(format!("save failed: {}", e))
                    .style(Style::default().fg(self.theme.red))
                    .border_style(Style::default().fg(self.theme.red)),
            );
            return Ok(true);
        }

        self.saved = true;
        self.should_apply = true;
        self.original_config = self.config.clone();
        Ok(false)
    }

    pub fn handle_event(&mut self, event: Event) -> io::Result<bool> {
        if let Some(ref toast) = self.toast {
            if toast.is_expired() {
                self.toast = None;
            }
        }

        match event {
            Event::Key(key) if key.kind == KeyEventKind::Press => match self.mode {
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
                    KeyCode::Down | KeyCode::Char('j') => self.move_selection(1),
                    KeyCode::Up | KeyCode::Char('k') => self.move_selection(-1),
                    KeyCode::Char(c) if !key.modifiers.contains(KeyModifiers::CONTROL) => {
                        self.search.insert(c);
                        self.update_filter();
                    }
                    _ => {}
                },
                Mode::Normal => match key.code {
                    KeyCode::Char('q') | KeyCode::Esc => {
                        self.restore_preview(true);
                        return Ok(false);
                    }
                    KeyCode::Char('/') => {
                        self.mode = Mode::Search;
                    }
                    KeyCode::Char('p') => {
                        self.preview_current();
                        if self.preview_touched {
                            self.mode = Mode::Preview;
                        }
                    }
                    KeyCode::Tab => {
                        self.focus = self.focus.next();
                    }
                    KeyCode::Enter => return self.commit(),
                    KeyCode::Down | KeyCode::Char('j') => self.move_selection(1),
                    KeyCode::Up | KeyCode::Char('k') => self.move_selection(-1),
                    KeyCode::Left | KeyCode::Char('h') => match self.focus {
                        Focus::Effects => self.move_selection(-1),
                        Focus::Brightness => self.adjust_brightness(-8),
                        Focus::Speed => self.adjust_speed(-8),
                    },
                    KeyCode::Right | KeyCode::Char('l') => match self.focus {
                        Focus::Effects => self.move_selection(1),
                        Focus::Brightness => self.adjust_brightness(8),
                        Focus::Speed => self.adjust_speed(8),
                    },
                    KeyCode::Char('-') => match self.focus {
                        Focus::Effects => {}
                        Focus::Brightness => self.adjust_brightness(-1),
                        Focus::Speed => self.adjust_speed(-1),
                    },
                    KeyCode::Char('+') | KeyCode::Char('=') => match self.focus {
                        Focus::Effects => {}
                        Focus::Brightness => self.adjust_brightness(1),
                        Focus::Speed => self.adjust_speed(1),
                    },
                    KeyCode::Char(c) if !key.modifiers.contains(KeyModifiers::CONTROL) => {
                        self.mode = Mode::Search;
                        self.search.insert(c);
                        self.update_filter();
                    }
                    _ => {}
                },
                Mode::Preview => match key.code {
                    KeyCode::Char('q') | KeyCode::Esc => {
                        self.restore_preview(true);
                        return Ok(false);
                    }
                    KeyCode::Char('r') => {
                        self.restore_preview(false);
                        self.mode = Mode::Normal;
                    }
                    KeyCode::Enter => return self.commit(),
                    _ => {}
                },
            },
            Event::Mouse(mouse) => match mouse.kind {
                MouseEventKind::ScrollDown => self.move_selection(1),
                MouseEventKind::ScrollUp => self.move_selection(-1),
                MouseEventKind::Down(crossterm::event::MouseButton::Left) => {
                    let inner = self.content_area.inner(ratatui::layout::Margin {
                        horizontal: 1,
                        vertical: 1,
                    });
                    if mouse.row >= inner.y && mouse.row < inner.y + inner.height {
                        let clicked = (mouse.row - inner.y) as usize;
                        if clicked < self.filtered.len() {
                            self.selected = clicked;
                            self.list_state.select(Some(self.selected));
                            self.focus = Focus::Effects;
                        }
                    }
                }
                _ => {}
            },
            _ => {}
        }

        Ok(true)
    }

    pub fn render_in_area(&mut self, frame: &mut Frame, area: Rect) {
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
    }

    fn render_header(&mut self, frame: &mut Frame, area: Rect) {
        let block = Block::default()
            .borders(Borders::BOTTOM)
            .border_style(Style::default().fg(self.theme.surface1));
        let inner = block.inner(area);
        frame.render_widget(block, area);

        if self.mode == Mode::Search {
            let input = FuzzyInput::default()
                .style(Style::default().fg(self.theme.text))
                .cursor_style(Style::default().fg(self.theme.base).bg(self.theme.accent))
                .border_style(Style::default().fg(self.theme.accent));
            frame.render_stateful_widget(input, inner, &mut self.search);
            return;
        }

        frame.render_widget(Paragraph::new(vec![self.header_line()]), inner);
    }

    fn header_line(&self) -> Line<'static> {
        Line::from(vec![
            Span::styled(
                "Keyboard",
                Style::default()
                    .fg(self.theme.accent)
                    .add_modifier(Modifier::BOLD),
            ),
            Span::styled(
                "  primary color follows cfg theme",
                Style::default().fg(self.theme.overlay1),
            ),
        ])
    }

    fn render_content(&mut self, frame: &mut Frame, area: Rect) {
        let chunks = Layout::default()
            .direction(Direction::Horizontal)
            .constraints([Constraint::Percentage(62), Constraint::Percentage(38)])
            .split(area);

        self.render_effects(frame, chunks[0]);
        self.render_controls(frame, chunks[1]);
    }

    fn render_effects(&mut self, frame: &mut Frame, area: Rect) {
        let items = self
            .filtered
            .iter()
            .map(|&idx| ListItem::new(self.effect_line(idx)))
            .collect::<Vec<_>>();

        let title = if self.focus == Focus::Effects {
            " Effects "
        } else {
            " Effects "
        };
        let border_style = if self.focus == Focus::Effects {
            Style::default().fg(self.theme.accent)
        } else {
            Style::default().fg(self.theme.surface1)
        };
        let list = List::new(items)
            .block(
                Block::default()
                    .borders(Borders::ALL)
                    .title(Span::styled(title, Style::default().fg(self.theme.accent)))
                    .border_style(border_style),
            )
            .highlight_style(Style::default().bg(self.theme.surface1));
        frame.render_stateful_widget(list, area, &mut self.list_state);
    }

    fn effect_line(&self, idx: usize) -> Line<'static> {
        let entry = &self.effects[idx];
        let selected = self.selected_effect().map(|e| e.id) == Some(entry.effect.id);
        let active = self.active_effect_id() == Some(entry.effect.id);
        let marker = if selected { "> " } else { "  " };
        let aliases = if entry.effect.aliases.is_empty() {
            String::new()
        } else {
            format!("  {}", entry.effect.aliases.join(", "))
        };
        let mut spans = vec![
            Span::styled(marker, Style::default().fg(self.theme.accent)),
            Span::styled(
                format!("{:<2} ", entry.effect.id),
                Style::default().fg(self.theme.overlay1),
            ),
            Span::styled(
                entry.effect.name.to_string(),
                Style::default().fg(self.theme.text),
            ),
            Span::styled(aliases, Style::default().fg(self.theme.subtext0)),
        ];

        if active {
            spans.push(Span::styled(
                " ← active",
                Style::default().fg(self.theme.overlay1),
            ));
        }

        Line::from(spans)
    }

    fn render_controls(&self, frame: &mut Frame, area: Rect) {
        let block = Block::default()
            .borders(Borders::ALL)
            .title(Span::styled(
                " Controls ",
                Style::default().fg(self.theme.accent),
            ))
            .border_style(if self.focus == Focus::Effects {
                Style::default().fg(self.theme.surface1)
            } else {
                Style::default().fg(self.theme.accent)
            });
        let inner = block.inner(area);
        frame.render_widget(block, area);

        let brightness_style = if self.focus == Focus::Brightness {
            Style::default()
                .fg(self.theme.accent)
                .add_modifier(Modifier::BOLD)
        } else {
            Style::default().fg(self.theme.text)
        };
        let speed_style = if self.focus == Focus::Speed {
            Style::default()
                .fg(self.theme.accent)
                .add_modifier(Modifier::BOLD)
        } else {
            Style::default().fg(self.theme.text)
        };

        let lines = vec![
            Line::from(vec![
                Span::styled("Brightness ", Style::default().fg(self.theme.subtext0)),
                Span::styled(
                    format!("{:>3}", self.config.leds.brightness),
                    brightness_style,
                ),
            ]),
            render_slider(
                self.config.leds.brightness,
                self.focus == Focus::Brightness,
                self.theme.accent,
                self.theme.overlay1,
                self.theme.surface1,
            ),
            Line::from(""),
            Line::from(vec![
                Span::styled("Speed      ", Style::default().fg(self.theme.subtext0)),
                Span::styled(format!("{:>3}", self.config.leds.speed), speed_style),
            ]),
            render_slider(
                self.config.leds.speed,
                self.focus == Focus::Speed,
                self.theme.green,
                self.theme.overlay1,
                self.theme.surface1,
            ),
            Line::from(""),
            Line::from(vec![
                Span::styled("Tab", Style::default().fg(self.theme.accent)),
                Span::styled(" focus  ", Style::default().fg(self.theme.subtext0)),
                Span::styled("h/l", Style::default().fg(self.theme.accent)),
                Span::styled(" adjust", Style::default().fg(self.theme.subtext0)),
            ]),
        ];
        frame.render_widget(Paragraph::new(lines), inner);
    }

    fn render_footer(&self, frame: &mut Frame, area: Rect) {
        let text = match self.mode {
            Mode::Normal => {
                "j/k nav  / search  Tab focus  h/l adjust  p preview  Enter save+apply  q/Esc cancel"
            }
            Mode::Search => "type to search  j/k nav  Enter accept search  Esc clear",
            Mode::Preview => "typing captured for LED preview  r revert  Enter keep+apply  q/Esc cancel",
        };
        frame.render_widget(
            Paragraph::new(text).style(Style::default().fg(self.theme.subtext0)),
            area,
        );
    }
}

fn render_slider(
    value: u8,
    focused: bool,
    knob: TuiColor,
    filled: TuiColor,
    empty: TuiColor,
) -> Line<'static> {
    let width = 15usize;
    let pos = (value as usize * (width - 1) / u8::MAX as usize).min(width - 1);
    let mut spans = vec![Span::raw(" ")];

    for idx in 0..width {
        let marker = if idx == pos { "●" } else { "─" };
        let style = if idx == pos {
            if focused {
                Style::default().fg(knob).add_modifier(Modifier::BOLD)
            } else {
                Style::default().fg(knob)
            }
        } else if idx <= pos {
            Style::default().fg(filled)
        } else {
            Style::default().fg(empty)
        };
        spans.push(Span::styled(marker, style));
    }

    Line::from(spans)
}

fn clamp_u8(value: u8, delta: i16) -> u8 {
    (value as i16 + delta).clamp(0, 255) as u8
}

#[cfg(test)]
mod tests {
    use std::collections::HashMap;

    use crossterm::event::KeyEvent;

    use crate::color::Color;
    use crate::config::{Config, LedConfig};
    use crate::palette::Palette;

    use super::*;

    fn test_palette() -> Palette {
        Palette {
            colors: HashMap::from([
                (
                    "base".to_string(),
                    Color {
                        r: 30,
                        g: 30,
                        b: 46,
                    },
                ),
                (
                    "text".to_string(),
                    Color {
                        r: 205,
                        g: 214,
                        b: 244,
                    },
                ),
                (
                    "subtext0".to_string(),
                    Color {
                        r: 166,
                        g: 173,
                        b: 200,
                    },
                ),
                (
                    "surface0".to_string(),
                    Color {
                        r: 49,
                        g: 50,
                        b: 68,
                    },
                ),
                (
                    "surface1".to_string(),
                    Color {
                        r: 69,
                        g: 71,
                        b: 90,
                    },
                ),
                (
                    "overlay1".to_string(),
                    Color {
                        r: 127,
                        g: 132,
                        b: 156,
                    },
                ),
                (
                    "green".to_string(),
                    Color {
                        r: 166,
                        g: 227,
                        b: 161,
                    },
                ),
                (
                    "yellow".to_string(),
                    Color {
                        r: 249,
                        g: 226,
                        b: 175,
                    },
                ),
                (
                    "red".to_string(),
                    Color {
                        r: 243,
                        g: 139,
                        b: 168,
                    },
                ),
                (
                    "blue".to_string(),
                    Color {
                        r: 137,
                        g: 180,
                        b: 250,
                    },
                ),
            ]),
        }
    }

    fn test_config(effect: &str) -> Config {
        Config {
            leds: LedConfig {
                effect: effect.to_string(),
                brightness: 223,
                speed: 175,
                ..LedConfig::default()
            },
            ..Config::default()
        }
    }

    fn key_event(code: KeyCode) -> Event {
        Event::Key(KeyEvent::new(code, KeyModifiers::NONE))
    }

    #[test]
    fn initializes_selected_effect_from_config() {
        let palette = test_palette();
        let picker = KeyboardPicker::new(
            test_config("solid"),
            &palette,
            "/tmp/cfg-keyboard-test.toml".to_string(),
        );

        assert_eq!(picker.selected_effect_name(), Some("solid"));
    }

    #[test]
    fn brightness_and_speed_adjustments_clamp_to_u8_range() {
        let palette = test_palette();
        let mut picker = KeyboardPicker::new(
            test_config("solid"),
            &palette,
            "/tmp/cfg-keyboard-test.toml".to_string(),
        );

        picker.adjust_brightness(-300);
        picker.adjust_speed(300);

        assert_eq!(picker.brightness(), 0);
        assert_eq!(picker.speed(), 255);
    }

    #[test]
    fn moving_selection_does_not_start_hardware_preview() {
        let palette = test_palette();
        let mut picker = KeyboardPicker::new(
            test_config("solid"),
            &palette,
            "/tmp/cfg-keyboard-test.toml".to_string(),
        );

        picker.move_selection(1);

        assert!(picker.original_statuses.is_none());
        assert!(!picker.preview_touched);
    }

    #[test]
    fn adjusting_values_does_not_start_hardware_preview() {
        let palette = test_palette();
        let mut picker = KeyboardPicker::new(
            test_config("solid"),
            &palette,
            "/tmp/cfg-keyboard-test.toml".to_string(),
        );

        picker.adjust_brightness(8);
        picker.adjust_speed(-8);

        assert_eq!(picker.brightness(), 231);
        assert_eq!(picker.speed(), 167);
        assert!(picker.original_statuses.is_none());
        assert!(!picker.preview_touched);
    }

    #[test]
    fn header_does_not_repeat_effect_state() {
        let palette = test_palette();
        let picker = KeyboardPicker::new(
            test_config("solid"),
            &palette,
            "/tmp/cfg-keyboard-test.toml".to_string(),
        );

        let text = picker
            .header_line()
            .spans
            .iter()
            .map(|span| span.content.as_ref())
            .collect::<String>();

        assert!(!text.contains("active="));
        assert!(!text.contains("selected="));
    }

    #[test]
    fn active_effect_indicator_is_inline_on_effect_row() {
        let palette = test_palette();
        let mut picker = KeyboardPicker::new(
            test_config("solid"),
            &palette,
            "/tmp/cfg-keyboard-test.toml".to_string(),
        );

        picker.move_selection(1);
        let active_line = picker.effect_line(1);
        let selected_line = picker.effect_line(2);
        let active_text = active_line
            .spans
            .iter()
            .map(|span| span.content.as_ref())
            .collect::<String>();
        let selected_text = selected_line
            .spans
            .iter()
            .map(|span| span.content.as_ref())
            .collect::<String>();

        assert!(active_text.contains("← active"));
        assert_ne!(picker.selected_effect_name(), Some("solid"));
        assert!(!selected_text.contains("← active"));
    }

    #[test]
    fn slider_uses_color_picker_shape() {
        let line = render_slider(128, false, TuiColor::Red, TuiColor::Blue, TuiColor::Green);
        let text = line
            .spans
            .iter()
            .map(|span| span.content.as_ref())
            .collect::<String>();

        assert!(text.starts_with(' '));
        assert!(text.contains('●'));
        assert!(text.contains('─'));
        assert!(!text.contains('█'));
    }

    #[test]
    fn preview_mode_captures_typing_without_searching() {
        let palette = test_palette();
        let mut picker = KeyboardPicker::new(
            test_config("solid"),
            &palette,
            "/tmp/cfg-keyboard-test.toml".to_string(),
        );
        picker.mode = Mode::Preview;

        picker.handle_event(key_event(KeyCode::Char('a'))).unwrap();

        assert_eq!(picker.mode, Mode::Preview);
        assert!(picker.search.is_empty());
    }

    #[test]
    fn revert_from_preview_mode_returns_to_normal() {
        let palette = test_palette();
        let mut picker = KeyboardPicker::new(
            test_config("solid"),
            &palette,
            "/tmp/cfg-keyboard-test.toml".to_string(),
        );
        picker.mode = Mode::Preview;

        picker.handle_event(key_event(KeyCode::Char('r'))).unwrap();

        assert_eq!(picker.mode, Mode::Normal);
    }

    #[test]
    fn revert_from_preview_mode_keeps_pending_adjustments() {
        let palette = test_palette();
        let mut picker = KeyboardPicker::new(
            test_config("solid"),
            &palette,
            "/tmp/cfg-keyboard-test.toml".to_string(),
        );
        picker.mode = Mode::Preview;
        picker.preview_touched = true;
        picker.original_statuses = Some(Vec::new());
        picker.adjust_brightness(8);

        picker.handle_event(key_event(KeyCode::Char('r'))).unwrap();

        assert_eq!(picker.mode, Mode::Normal);
        assert_eq!(picker.brightness(), 231);
        assert!(!picker.preview_touched);
    }
}
