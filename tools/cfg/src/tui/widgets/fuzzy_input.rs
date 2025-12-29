use nucleo::{
    pattern::{CaseMatching, Normalization, Pattern},
    Matcher, Utf32Str,
};
use ratatui::{
    buffer::Buffer,
    layout::Rect,
    style::{Modifier, Style},
    text::{Line, Span},
    widgets::{Paragraph, StatefulWidget, Widget},
};

pub struct FuzzyInput {
    style: Style,
    cursor_style: Style,
    border_style: Style,
}

impl Default for FuzzyInput {
    fn default() -> Self {
        Self {
            style: Style::default(),
            cursor_style: Style::default().add_modifier(Modifier::REVERSED),
            border_style: Style::default(),
        }
    }
}

impl FuzzyInput {
    pub fn style(mut self, style: Style) -> Self {
        self.style = style;
        self
    }

    pub fn cursor_style(mut self, style: Style) -> Self {
        self.cursor_style = style;
        self
    }

    pub fn border_style(mut self, style: Style) -> Self {
        self.border_style = style;
        self
    }
}

#[derive(Debug, Default)]
pub struct FuzzyInputState {
    query: String,
    cursor: usize,
    matcher: Matcher,
}

impl FuzzyInputState {
    pub fn new() -> Self {
        Self {
            query: String::new(),
            cursor: 0,
            matcher: Matcher::new(nucleo::Config::DEFAULT),
        }
    }

    pub fn is_empty(&self) -> bool {
        self.query.is_empty()
    }

    pub fn insert(&mut self, c: char) {
        self.query.insert(self.cursor, c);
        self.cursor += c.len_utf8();
    }

    pub fn backspace(&mut self) {
        if self.cursor > 0 {
            let prev = self.query[..self.cursor]
                .chars()
                .last()
                .map(|c| c.len_utf8())
                .unwrap_or(0);
            self.cursor -= prev;
            self.query.remove(self.cursor);
        }
    }

    pub fn delete(&mut self) {
        if self.cursor < self.query.len() {
            self.query.remove(self.cursor);
        }
    }

    pub fn clear(&mut self) {
        self.query.clear();
        self.cursor = 0;
    }

    pub fn move_left(&mut self) {
        if self.cursor > 0 {
            self.cursor -= self.query[..self.cursor]
                .chars()
                .last()
                .map(|c| c.len_utf8())
                .unwrap_or(0);
        }
    }

    pub fn move_right(&mut self) {
        if self.cursor < self.query.len() {
            self.cursor += self.query[self.cursor..]
                .chars()
                .next()
                .map(|c| c.len_utf8())
                .unwrap_or(0);
        }
    }

    pub fn move_start(&mut self) {
        self.cursor = 0;
    }

    pub fn move_end(&mut self) {
        self.cursor = self.query.len();
    }

    /// Filter items using fuzzy matching, returns indices sorted by score (best first)
    pub fn filter<T, F>(&mut self, items: &[T], extract: F) -> Vec<(usize, u32)>
    where
        F: Fn(&T) -> &str,
    {
        if self.query.is_empty() {
            return items.iter().enumerate().map(|(i, _)| (i, 0)).collect();
        }

        let pattern = Pattern::parse(&self.query, CaseMatching::Smart, Normalization::Smart);

        let mut results: Vec<(usize, u32)> = items
            .iter()
            .enumerate()
            .filter_map(|(i, item)| {
                let text = extract(item);
                let mut buf = Vec::new();
                let haystack = Utf32Str::new(text, &mut buf);
                pattern
                    .score(haystack, &mut self.matcher)
                    .map(|score| (i, score))
            })
            .collect();

        // Sort by score descending (best matches first)
        results.sort_by(|a, b| b.1.cmp(&a.1));
        results
    }

    /// Get highlighted spans for a matched string
    pub fn highlight<'a>(
        &mut self,
        text: &'a str,
        normal_style: Style,
        highlight_style: Style,
    ) -> Line<'a> {
        if self.query.is_empty() {
            return Line::from(Span::styled(text.to_string(), normal_style));
        }

        let pattern = Pattern::parse(&self.query, CaseMatching::Smart, Normalization::Smart);
        let mut buf = Vec::new();
        let haystack = Utf32Str::new(text, &mut buf);

        let mut indices = Vec::new();
        if pattern.indices(haystack, &mut self.matcher, &mut indices).is_some() {
            // Convert u32 indices to char positions
            let mut spans = Vec::new();
            let chars: Vec<char> = text.chars().collect();
            let mut last = 0;

            // Sort indices
            indices.sort();

            for &idx in &indices {
                let idx = idx as usize;
                if idx > last {
                    // Add non-highlighted text
                    let s: String = chars[last..idx].iter().collect();
                    spans.push(Span::styled(s, normal_style));
                }
                // Add highlighted char
                if idx < chars.len() {
                    spans.push(Span::styled(chars[idx].to_string(), highlight_style));
                    last = idx + 1;
                }
            }

            // Add remaining text
            if last < chars.len() {
                let s: String = chars[last..].iter().collect();
                spans.push(Span::styled(s, normal_style));
            }

            Line::from(spans)
        } else {
            Line::from(Span::styled(text.to_string(), normal_style))
        }
    }
}

impl StatefulWidget for FuzzyInput {
    type State = FuzzyInputState;

    fn render(self, area: Rect, buf: &mut Buffer, state: &mut Self::State) {
        // Create the input display with cursor
        let (before, after) = state.query.split_at(state.cursor);
        let cursor_char = after.chars().next().unwrap_or(' ');
        let after = if after.is_empty() { "" } else { &after[cursor_char.len_utf8()..] };

        let spans = vec![
            Span::styled("/ ", self.border_style),
            Span::styled(before.to_string(), self.style),
            Span::styled(cursor_char.to_string(), self.cursor_style),
            Span::styled(after.to_string(), self.style),
        ];

        Paragraph::new(Line::from(spans)).render(area, buf);
    }
}
