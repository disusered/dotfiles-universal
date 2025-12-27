use std::time::{Duration, Instant};

use ratatui::{
    buffer::Buffer,
    layout::{Alignment, Rect},
    style::Style,
    text::Text,
    widgets::{Block, Borders, Clear, Paragraph, Widget},
};

#[derive(Debug, Clone)]
pub struct Toast {
    message: String,
    created_at: Instant,
    duration: Duration,
    style: Style,
    border_style: Style,
}

impl Toast {
    pub fn new(message: impl Into<String>) -> Self {
        Self {
            message: message.into(),
            created_at: Instant::now(),
            duration: Duration::from_secs(2),
            style: Style::default(),
            border_style: Style::default(),
        }
    }

    pub fn duration(mut self, duration: Duration) -> Self {
        self.duration = duration;
        self
    }

    pub fn style(mut self, style: Style) -> Self {
        self.style = style;
        self
    }

    pub fn border_style(mut self, style: Style) -> Self {
        self.border_style = style;
        self
    }

    pub fn is_expired(&self) -> bool {
        self.created_at.elapsed() >= self.duration
    }

    pub fn message(&self) -> &str {
        &self.message
    }
}

impl Widget for Toast {
    fn render(self, area: Rect, buf: &mut Buffer) {
        // Calculate centered position
        let width = (self.message.len() + 4).min(area.width as usize) as u16;
        let height = 3u16;
        let x = area.x + (area.width.saturating_sub(width)) / 2;
        let y = area.y + (area.height.saturating_sub(height)) / 2;

        let toast_area = Rect::new(x, y, width, height);

        // Clear the area first
        Clear.render(toast_area, buf);

        // Render the toast
        let block = Block::default()
            .borders(Borders::ALL)
            .border_style(self.border_style);

        Paragraph::new(Text::from(self.message))
            .alignment(Alignment::Center)
            .style(self.style)
            .block(block)
            .render(toast_area, buf);
    }
}

/// Convenience function to create a "Copied!" toast with success styling
pub fn copied_toast(style: Style, border_style: Style) -> Toast {
    Toast::new("Copied!")
        .style(style)
        .border_style(border_style)
}
