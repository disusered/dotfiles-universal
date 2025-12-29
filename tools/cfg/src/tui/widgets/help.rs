use ratatui::{
    buffer::Buffer,
    layout::Rect,
    style::Style,
    text::{Line, Span},
    widgets::{Block, Borders, Clear, Paragraph, Widget},
};

pub struct HelpPopup<'a> {
    title: &'a str,
    bindings: Vec<(&'a str, &'a str)>,
    style: Style,
    border_style: Style,
    key_style: Style,
    desc_style: Style,
}

impl<'a> HelpPopup<'a> {
    pub fn new(title: &'a str) -> Self {
        Self {
            title,
            bindings: Vec::new(),
            style: Style::default(),
            border_style: Style::default(),
            key_style: Style::default(),
            desc_style: Style::default(),
        }
    }

    pub fn bindings(mut self, bindings: Vec<(&'a str, &'a str)>) -> Self {
        self.bindings = bindings;
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

    pub fn key_style(mut self, style: Style) -> Self {
        self.key_style = style;
        self
    }

    pub fn desc_style(mut self, style: Style) -> Self {
        self.desc_style = style;
        self
    }
}

impl Widget for HelpPopup<'_> {
    fn render(self, area: Rect, buf: &mut Buffer) {
        // Calculate popup dimensions
        let max_key_len = self
            .bindings
            .iter()
            .map(|(k, _)| k.len())
            .max()
            .unwrap_or(0);
        let max_desc_len = self
            .bindings
            .iter()
            .map(|(_, d)| d.len())
            .max()
            .unwrap_or(0);

        let width = (max_key_len + max_desc_len + 7).min(area.width as usize - 4) as u16;
        let height = (self.bindings.len() + 4).min(area.height as usize - 2) as u16;

        let x = area.x + (area.width.saturating_sub(width)) / 2;
        let y = area.y + (area.height.saturating_sub(height)) / 2;

        let popup_area = Rect::new(x, y, width, height);

        // Clear the area first
        Clear.render(popup_area, buf);

        // Build lines
        let mut lines: Vec<Line> = Vec::new();
        lines.push(Line::from("")); // Padding

        for (key, desc) in &self.bindings {
            let padding = max_key_len - key.len();
            lines.push(Line::from(vec![
                Span::raw("  "),
                Span::styled(format!("{}{}", key, " ".repeat(padding)), self.key_style),
                Span::raw("  "),
                Span::styled(desc.to_string(), self.desc_style),
            ]));
        }

        lines.push(Line::from("")); // Padding
        lines.push(Line::from(Span::styled(
            "Press any key to close",
            self.desc_style,
        )));

        let block = Block::default()
            .title(format!(" {} ", self.title))
            .borders(Borders::ALL)
            .border_style(self.border_style);

        Paragraph::new(lines)
            .style(self.style)
            .block(block)
            .render(popup_area, buf);
    }
}

