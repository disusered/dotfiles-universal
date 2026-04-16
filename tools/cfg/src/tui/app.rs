use std::io;

use crossterm::event::{self, Event, KeyCode, KeyEventKind, MouseEventKind};
use ratatui::{
    layout::{Constraint, Direction, Layout, Rect},
    style::{Color, Modifier, Style},
    text::{Line, Span},
    widgets::{Block, Clear, Tabs},
    Frame,
};

use crate::config::Config;
use crate::palette::Palette;

use super::colors::ColorPicker;
use super::fonts::FontPicker;
use super::update::UpdatePicker;
use super::wallpapers::WallpaperPicker;
use super::{init, restore};

/// Which pickers committed an apply. Lets the caller dispatch only to the
/// affected subsystems — e.g. a wallpaper-tab commit shouldn't re-render
/// every template in `templates.toml`.
#[derive(Debug, Clone, Copy, Default, PartialEq, Eq)]
pub struct ApplyScope {
    pub colors: bool,
    pub fonts: bool,
    pub wallpaper: bool,
}

impl ApplyScope {
    pub fn any(&self) -> bool {
        self.colors || self.fonts || self.wallpaper
    }
}

/// Result of a TUI session.
#[derive(Debug, Clone, Copy)]
pub enum Outcome {
    /// At least one picker committed with apply requested.
    Apply(ApplyScope),
    /// At least one picker saved but none requested apply.
    SavedOnly,
    /// Quit without saving anything.
    Cancelled,
}

#[derive(Debug, Clone, Copy, PartialEq, Default)]
pub enum Tab {
    #[default]
    Colors,
    Fonts,
    Wallpapers,
    Update,
}

impl Tab {
    fn index(self) -> usize {
        match self {
            Tab::Colors => 0,
            Tab::Fonts => 1,
            Tab::Wallpapers => 2,
            Tab::Update => 3,
        }
    }

    fn next(self) -> Self {
        match self {
            Tab::Colors => Tab::Fonts,
            Tab::Fonts => Tab::Wallpapers,
            Tab::Wallpapers => Tab::Update,
            Tab::Update => Tab::Colors,
        }
    }
}

/// Theme colors for the tab bar
struct TabTheme {
    base: Color,
    subtext0: Color,
    accent: Color,
}

impl TabTheme {
    fn from_config(config: &Config, palette: &Palette) -> Self {
        let get_color = |name: &str| -> Color {
            palette
                .get(name)
                .map(|c| Color::Rgb(c.r, c.g, c.b))
                .unwrap_or(Color::White)
        };

        Self {
            base: get_color("base"),
            subtext0: get_color("subtext0"),
            accent: get_color(&config.primary),
        }
    }
}

pub struct App {
    active_tab: Tab,
    color_picker: ColorPicker,
    font_picker: FontPicker,
    wallpaper_picker: Option<WallpaperPicker>,
    wallpaper_init_error: Option<String>,
    update_picker: UpdatePicker,
    theme: TabTheme,
    should_apply: bool,
    /// Tab bar area for mouse click detection
    tab_bar_area: Rect,
}

impl App {
    pub fn new(
        config: Config,
        palette: &Palette,
        config_path: String,
        cfg_dir: String,
        dotfiles_dir: String,
    ) -> Self {
        let theme = TabTheme::from_config(&config, palette);
        let color_picker = ColorPicker::new(config.clone(), palette, config_path.clone());
        let font_picker = FontPicker::new(config.clone(), palette, config_path.clone());

        let update_picker = UpdatePicker::new(
            palette,
            &config.primary,
            cfg_dir.clone(),
            dotfiles_dir,
        );

        let (wallpaper_picker, wallpaper_init_error) = match WallpaperPicker::new(
            config.clone(),
            palette,
            config_path,
            cfg_dir,
        ) {
            Ok(p) => (Some(p), None),
            Err(e) => (None, Some(e)),
        };

        Self {
            active_tab: Tab::default(),
            color_picker,
            font_picker,
            wallpaper_picker,
            wallpaper_init_error,
            update_picker,
            theme,
            should_apply: false,
            tab_bar_area: Rect::default(),
        }
    }

    fn render(&mut self, frame: &mut Frame) {
        let area = frame.area();

        // Clear background
        frame.render_widget(Clear, area);
        frame.render_widget(
            Block::default().style(Style::default().bg(self.theme.base)),
            area,
        );

        // Split into tab bar + content
        let chunks = Layout::default()
            .direction(Direction::Vertical)
            .constraints([Constraint::Length(2), Constraint::Min(10)])
            .split(area);

        self.tab_bar_area = chunks[0];
        self.render_tabs(frame, chunks[0]);

        // Render active picker
        match self.active_tab {
            Tab::Colors => self.color_picker.render_in_area(frame, chunks[1]),
            Tab::Fonts => self.font_picker.render_in_area(frame, chunks[1]),
            Tab::Wallpapers => {
                if let Some(p) = self.wallpaper_picker.as_mut() {
                    p.render_in_area(frame, chunks[1]);
                } else {
                    let msg = self
                        .wallpaper_init_error
                        .clone()
                        .unwrap_or_else(|| "wallpaper picker unavailable".to_string());
                    let para = ratatui::widgets::Paragraph::new(msg)
                        .style(Style::default().fg(self.theme.subtext0));
                    frame.render_widget(para, chunks[1]);
                }
            }
            Tab::Update => self.update_picker.render_in_area(frame, chunks[1]),
        }
    }

    fn render_tabs(&self, frame: &mut Frame, area: Rect) {
        // Nerd font icons:  (palette),  (font),  (image)
        let titles: Vec<Line> = vec![
            Line::from(vec![
                Span::styled("1", Style::default().fg(self.theme.subtext0).add_modifier(Modifier::DIM)),
                Span::raw(" \u{f0e22} Colors"),  //  palette icon
            ]),
            Line::from(vec![
                Span::styled("2", Style::default().fg(self.theme.subtext0).add_modifier(Modifier::DIM)),
                Span::raw(" \u{f031} Fonts"),  //  font icon
            ]),
            Line::from(vec![
                Span::styled("3", Style::default().fg(self.theme.subtext0).add_modifier(Modifier::DIM)),
                Span::raw(" \u{f03e} Wallpapers"),  //  image icon
            ]),
            Line::from(vec![
                Span::styled("4", Style::default().fg(self.theme.subtext0).add_modifier(Modifier::DIM)),
                Span::raw(" \u{f0e4e} Update"),  // 󰑓 reload icon
            ]),
        ];

        let tabs = Tabs::new(titles)
            .select(self.active_tab.index())
            .style(Style::default().fg(self.theme.subtext0))
            .highlight_style(
                Style::default()
                    .fg(self.theme.accent)
                    .add_modifier(Modifier::BOLD),
            )
            .divider("  ");

        frame.render_widget(tabs, area);
    }

    fn handle_event(&mut self, event: Event) -> io::Result<bool> {
        // Handle mouse clicks on tab bar
        if let Event::Mouse(mouse) = &event {
            if let MouseEventKind::Down(crossterm::event::MouseButton::Left) = mouse.kind {
                // Check if click is in tab bar area
                if mouse.row < self.tab_bar_area.height {
                    // Tab layout: "1  Colors  2  Fonts  3  Wallpapers  4  Update"
                    // Approximate column regions
                    if mouse.column < 13 {
                        self.active_tab = Tab::Colors;
                    } else if mouse.column < 23 {
                        self.active_tab = Tab::Fonts;
                    } else if mouse.column < 39 {
                        self.active_tab = Tab::Wallpapers;
                    } else {
                        self.active_tab = Tab::Update;
                    }
                    return Ok(true);
                }
            }
        }

        // Global tab switching (only in normal mode)
        if let Event::Key(key) = &event {
            if key.kind == KeyEventKind::Press {
                // Check if active picker is in search mode
                let in_search = match self.active_tab {
                    Tab::Colors => self.color_picker.is_in_search(),
                    Tab::Fonts => self.font_picker.is_in_search(),
                    Tab::Wallpapers => self
                        .wallpaper_picker
                        .as_ref()
                        .map(|p| p.is_in_search())
                        .unwrap_or(false),
                    Tab::Update => self.update_picker.is_in_search(),
                };

                if !in_search {
                    match key.code {
                        KeyCode::Char('1') => {
                            self.active_tab = Tab::Colors;
                            return Ok(true);
                        }
                        KeyCode::Char('2') => {
                            self.active_tab = Tab::Fonts;
                            return Ok(true);
                        }
                        KeyCode::Char('3') => {
                            self.active_tab = Tab::Wallpapers;
                            return Ok(true);
                        }
                        KeyCode::Char('4') => {
                            self.active_tab = Tab::Update;
                            return Ok(true);
                        }
                        KeyCode::BackTab => {
                            // Shift+Tab switches between tabs
                            self.active_tab = self.active_tab.next();
                            return Ok(true);
                        }
                        _ => {}
                    }
                }
            }
        }

        // Delegate to active picker
        let continue_running = match self.active_tab {
            Tab::Colors => self.color_picker.handle_event(event)?,
            Tab::Fonts => self.font_picker.handle_event(event)?,
            Tab::Wallpapers => match self.wallpaper_picker.as_mut() {
                Some(p) => p.handle_event(event)?,
                None => {
                    // No picker available — only handle quit keys to avoid trapping user
                    if let Event::Key(k) = event {
                        if k.kind == KeyEventKind::Press
                            && matches!(k.code, KeyCode::Char('q') | KeyCode::Esc)
                        {
                            false
                        } else {
                            true
                        }
                    } else {
                        true
                    }
                }
            },
            Tab::Update => self.update_picker.handle_event(event)?,
        };

        // Check if picker wants to apply
        if !continue_running {
            self.should_apply = match self.active_tab {
                Tab::Colors => self.color_picker.wants_apply(),
                Tab::Fonts => self.font_picker.wants_apply(),
                Tab::Wallpapers => self
                    .wallpaper_picker
                    .as_ref()
                    .map(|p| p.wants_apply())
                    .unwrap_or(false),
                Tab::Update => false, // Update tab handles its own updates
            };
        }

        Ok(continue_running)
    }

    pub fn run(mut self) -> io::Result<Outcome> {
        let mut terminal = init()?;

        loop {
            // Refresh font picker config (in case scratchpad changed it)
            self.font_picker.refresh_config();

            terminal.draw(|f| self.render(f))?;

            if event::poll(std::time::Duration::from_millis(100))? {
                let event = event::read()?;
                if !self.handle_event(event)? {
                    break;
                }
            }
        }

        restore()?;

        // Revert any leftover desktop preview before returning
        if let Some(p) = self.wallpaper_picker.as_mut() {
            // no-op if not active
            let _ = p;
        }

        // Check if any picker has pending apply
        let colors_apply = self.color_picker.wants_apply();
        let fonts_apply = self.font_picker.wants_apply();
        let wallpaper_apply = self
            .wallpaper_picker
            .as_ref()
            .map(|p| p.wants_apply())
            .unwrap_or(false);
        let wallpaper_saved = self
            .wallpaper_picker
            .as_ref()
            .map(|p| p.was_saved())
            .unwrap_or(false);

        let scope = ApplyScope {
            colors: colors_apply,
            fonts: fonts_apply,
            wallpaper: wallpaper_apply,
        };
        if scope.any() {
            Ok(Outcome::Apply(scope))
        } else if self.color_picker.was_saved() || self.font_picker.was_saved() || wallpaper_saved {
            Ok(Outcome::SavedOnly)
        } else {
            Ok(Outcome::Cancelled)
        }
    }
}

/// Run the unified settings TUI
pub fn run(
    config: &Config,
    palette: &Palette,
    config_path: &str,
    cfg_dir: &str,
    dotfiles_dir: &str,
) -> io::Result<Outcome> {
    let app = App::new(
        config.clone(),
        palette,
        config_path.to_string(),
        cfg_dir.to_string(),
        dotfiles_dir.to_string(),
    );
    app.run()
}
