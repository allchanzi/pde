use crossterm::event::KeyCode;
use ratatui::{
    Frame,
    layout::Rect,
    style::Style,
    text::Line,
    widgets::{ListState, Paragraph},
};
use tuikit::{next_match, smart_contains};

/// Search within a picker without changing its rows or their action indices.
#[derive(Debug, Clone, Default)]
pub struct PickerSearch {
    input: Option<String>,
    query: String,
    message: String,
}

impl PickerSearch {
    pub fn input(&self) -> Option<&str> {
        self.input.as_deref()
    }

    /// Returns true when the key belongs to search rather than picker actions.
    pub fn handle_key(&mut self, key: KeyCode, selected: &mut usize, labels: &[String]) -> bool {
        if let Some(input) = &mut self.input {
            match key {
                KeyCode::Esc => self.input = None,
                KeyCode::Enter => {
                    self.query = self.input.take().unwrap_or_default();
                    self.jump(selected, labels, false);
                }
                KeyCode::Backspace => {
                    input.pop();
                }
                KeyCode::Char(character) => input.push(character),
                _ => {}
            }
            return true;
        }
        match key {
            KeyCode::Char('/') => {
                self.input = Some(String::new());
                self.message.clear();
            }
            KeyCode::Char('n' | 'N') => self.jump(selected, labels, key == KeyCode::Char('N')),
            _ => return false,
        }
        true
    }

    fn jump(&mut self, selected: &mut usize, labels: &[String], backwards: bool) {
        self.message.clear();
        if self.query.is_empty() {
            self.message = "Nothing to repeat; search with [/] first".into();
            return;
        }
        match next_match(labels.len(), *selected, backwards, |index| {
            smart_contains(&labels[index], &self.query)
        }) {
            Some(index) => *selected = index,
            None => self.message = format!("No match for \"{}\"", self.query),
        }
    }

    fn status(&self) -> String {
        if let Some(input) = &self.input {
            format!("/{input}")
        } else if !self.message.is_empty() {
            self.message.clone()
        } else if !self.query.is_empty() {
            format!("/{}", self.query)
        } else {
            String::new()
        }
    }

    pub fn render(&self, frame: &mut Frame<'_>, area: Rect, style: Style, cursor: bool) {
        if area.width == 0 || area.height == 0 {
            return;
        }
        let line = Line::from(self.status());
        let width = line.width();
        let editing = self.input.is_some();
        let offset = if editing {
            width.saturating_sub(usize::from(area.width - 1))
        } else {
            0
        };
        frame.render_widget(
            Paragraph::new(line).style(style).scroll((0, offset as u16)),
            area,
        );
        if cursor && editing {
            frame.set_cursor_position((
                area.x + width.min(usize::from(area.width - 1)) as u16,
                area.y,
            ));
        }
    }
}

pub fn select_first_when_present(state: &mut ListState, len: usize) {
    state.select((len > 0).then_some(0));
}

pub fn clamp_selection(state: &mut ListState, len: usize) {
    state.select(match (len, state.selected()) {
        (0, _) => None,
        (size, Some(index)) => Some(index.min(size - 1)),
        (_, None) => Some(0),
    });
}

#[cfg(test)]
mod tests {
    use super::*;

    fn search(picker: &mut PickerSearch, selected: &mut usize, labels: &[String], query: &str) {
        picker.handle_key(KeyCode::Char('/'), selected, labels);
        for character in query.chars() {
            picker.handle_key(KeyCode::Char(character), selected, labels);
        }
        picker.handle_key(KeyCode::Enter, selected, labels);
    }

    #[test]
    fn matches_wrap_in_both_directions_and_respect_smartcase() {
        let labels = vec!["main".into(), "feature/one".into(), "Feature/Two".into()];
        let mut picker = PickerSearch::default();
        let mut selected = 0;
        search(&mut picker, &mut selected, &labels, "feature");
        assert_eq!(selected, 1);
        picker.handle_key(KeyCode::Char('n'), &mut selected, &labels);
        assert_eq!(selected, 2);
        picker.handle_key(KeyCode::Char('n'), &mut selected, &labels);
        assert_eq!(selected, 1);
        picker.handle_key(KeyCode::Char('N'), &mut selected, &labels);
        assert_eq!(selected, 2);
        search(&mut picker, &mut selected, &labels, "Feature");
        assert_eq!(selected, 2);
        search(&mut picker, &mut selected, &labels, "FEATURE");
        assert_eq!(selected, 2);
        assert_eq!(picker.status(), "No match for \"FEATURE\"");
    }

    #[test]
    fn cancelled_input_preserves_the_previous_query_and_selection() {
        let labels = vec!["main".into(), "feature/one".into(), "feature/two".into()];
        let mut picker = PickerSearch::default();
        let mut selected = 0;
        search(&mut picker, &mut selected, &labels, "feature");
        picker.handle_key(KeyCode::Char('/'), &mut selected, &labels);
        for character in "jq? /ž".chars() {
            assert!(picker.handle_key(KeyCode::Char(character), &mut selected, &labels));
        }
        picker.handle_key(KeyCode::Backspace, &mut selected, &labels);
        assert_eq!(picker.input(), Some("jq? /"));
        assert_eq!(selected, 1);
        assert!(picker.handle_key(KeyCode::Esc, &mut selected, &labels));
        assert_eq!(picker.input(), None);
        picker.handle_key(KeyCode::Char('n'), &mut selected, &labels);
        assert_eq!(selected, 2);
        assert!(!picker.handle_key(KeyCode::Esc, &mut selected, &labels));
    }

    #[test]
    fn missing_and_empty_queries_leave_the_selection_unchanged() {
        let mut picker = PickerSearch::default();
        let mut selected = 0;
        let labels = vec!["main".into()];
        picker.handle_key(KeyCode::Char('n'), &mut selected, &labels);
        assert!(picker.status().contains("Nothing to repeat"));
        search(&mut picker, &mut selected, &labels, "missing");
        assert_eq!(selected, 0);
        assert!(picker.status().contains("No match"));
        search(&mut picker, &mut selected, &[], "main");
        assert_eq!(selected, 0);
        search(&mut picker, &mut selected, &labels, "");
        assert_eq!(selected, 0);
    }

    #[test]
    fn long_search_input_scrolls_and_keeps_the_cursor_inside_its_row() {
        let mut picker = PickerSearch::default();
        let mut selected = 0;
        picker.handle_key(KeyCode::Char('/'), &mut selected, &[]);
        for character in "feature/very-long-branch/界".chars() {
            picker.handle_key(KeyCode::Char(character), &mut selected, &[]);
        }
        let mut terminal =
            ratatui::Terminal::new(ratatui::backend::TestBackend::new(20, 4)).unwrap();
        let row = Rect::new(2, 1, 9, 1);
        terminal
            .draw(|frame| picker.render(frame, row, Style::default(), true))
            .unwrap();
        assert_eq!(terminal.get_cursor_position().unwrap(), (10, 1).into());
        let text = terminal
            .backend()
            .buffer()
            .content
            .iter()
            .map(|cell| cell.symbol())
            .collect::<String>();
        assert!(text.contains("ranch/界"), "{text}");
    }
}
