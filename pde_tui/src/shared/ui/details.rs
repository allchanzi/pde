use crossterm::event::KeyCode;

#[derive(Debug, Default)]
pub struct Details {
    pub open: bool,
    pub tab: usize,
    pub scroll: usize,
}

impl Details {
    pub fn key(&mut self, code: KeyCode, max_scroll: usize) {
        match code {
            KeyCode::Esc | KeyCode::Char('v') => self.open = false,
            KeyCode::Char(c @ '1'..='5') => {
                self.tab = (c as u8 - b'1') as usize;
                self.scroll = 0;
            }
            KeyCode::Char('h') | KeyCode::Left => {
                self.tab = (self.tab + 4) % 5;
                self.scroll = 0;
            }
            KeyCode::Char('l') | KeyCode::Right => {
                self.tab = (self.tab + 1) % 5;
                self.scroll = 0;
            }
            KeyCode::Char('j') | KeyCode::Down => {
                self.scroll = self.scroll.saturating_add(1).min(max_scroll)
            }
            KeyCode::Char('k') | KeyCode::Up => self.scroll = self.scroll.saturating_sub(1),
            KeyCode::Char('g') | KeyCode::Home => self.scroll = 0,
            KeyCode::Char('G') | KeyCode::End => self.scroll = max_scroll,
            _ => {}
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    #[test]
    fn details_tabs_scroll_and_close() {
        let mut details = Details {
            open: true,
            ..Details::default()
        };
        details.key(KeyCode::Char('5'), 30);
        assert_eq!(details.tab, 4);
        details.key(KeyCode::Char('l'), 30);
        assert_eq!(details.tab, 0);
        details.key(KeyCode::Char('h'), 30);
        assert_eq!(details.tab, 4);
        details.key(KeyCode::Char('G'), 30);
        assert_eq!(details.scroll, 30);
        details.key(KeyCode::Char('j'), 30);
        assert_eq!(details.scroll, 30);
        details.key(KeyCode::Char('k'), 30);
        assert_eq!(details.scroll, 29);
        details.key(KeyCode::Char('g'), 30);
        assert_eq!(details.scroll, 0);
        details.key(KeyCode::Esc, 30);
        assert!(!details.open);
    }
}
