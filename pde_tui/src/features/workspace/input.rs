impl WorkspaceState {
    pub fn handle_key(&mut self, key: KeyEvent) -> Result<Effect> {
        if key.modifiers.contains(KeyModifiers::ALT) {
            self.pending_g = false;
            return Ok(self.move_focus_by_key(key.code));
        }

        if key.modifiers.contains(KeyModifiers::CONTROL) {
            self.pending_g = false;
            return self.handle_control_key(key.code);
        }

        if self.pending_g {
            self.pending_g = false;
            if matches!(key.code, KeyCode::Char('g')) {
                return self.move_first();
            }
        }

        Ok(match key.code {
            KeyCode::Char('?') => Effect::ToggleHelp,
            KeyCode::Char('q') | KeyCode::Esc => Effect::Quit,
            KeyCode::Tab => self.cycle_focus(),
            KeyCode::Char('r') => self.refresh_all()?,
            KeyCode::Char('h') | KeyCode::Left => self.move_focus_left(),
            KeyCode::Char('l') | KeyCode::Right => self.move_focus_right(),
            KeyCode::Down | KeyCode::Char('j') => self.move_down()?,
            KeyCode::Up | KeyCode::Char('k') => self.move_up()?,
            KeyCode::Char('g') => {
                self.pending_g = true;
                Effect::None
            }
            KeyCode::Char('G') => self.move_last()?,
            KeyCode::Char('a') => self.add_action(),
            KeyCode::Char('d') => self.delete_action(),
            KeyCode::Char('o') | KeyCode::Enter => self.open_action(),
            _ => Effect::None,
        })
    }

    fn handle_control_key(&mut self, key: KeyCode) -> Result<Effect> {
        Ok(match key {
            KeyCode::Char('d') => self.page_down()?,
            KeyCode::Char('u') => self.page_up()?,
            _ => Effect::None,
        })
    }

    fn move_focus_by_key(&mut self, key: KeyCode) -> Effect {
        let next_focus = match key {
            KeyCode::Char('h') | KeyCode::Char('a') => self.focus_left(),
            KeyCode::Char('l') | KeyCode::Char('d') => self.focus_right(),
            KeyCode::Char('k') | KeyCode::Char('w') => self.focus_up(),
            KeyCode::Char('j') | KeyCode::Char('s') => self.focus_down(),
            _ => self.focus,
        };
        self.focus = next_focus;
        Effect::Message(format!("Focus: {}", self.focus_title()))
    }

    fn focus_left(&self) -> FocusPane {
        match self.focus {
            FocusPane::Workspaces => FocusPane::Projects,
            FocusPane::ProjectSessions => FocusPane::GlobalSessions,
            current => current,
        }
    }

    fn focus_right(&self) -> FocusPane {
        match self.focus {
            FocusPane::Projects => FocusPane::Workspaces,
            FocusPane::GlobalSessions => FocusPane::ProjectSessions,
            current => current,
        }
    }

    fn focus_up(&self) -> FocusPane {
        match self.focus {
            FocusPane::GlobalSessions => FocusPane::Projects,
            FocusPane::ProjectSessions => FocusPane::Workspaces,
            current => current,
        }
    }

    fn focus_down(&self) -> FocusPane {
        match self.focus {
            FocusPane::Projects => FocusPane::GlobalSessions,
            FocusPane::Workspaces => FocusPane::ProjectSessions,
            current => current,
        }
    }

    fn move_focus_left(&mut self) -> Effect {
        self.focus = self.focus_left();
        Effect::Message(format!("Focus: {}", self.focus_title()))
    }

    fn move_focus_right(&mut self) -> Effect {
        self.focus = self.focus_right();
        Effect::Message(format!("Focus: {}", self.focus_title()))
    }

    fn cycle_focus(&mut self) -> Effect {
        self.focus = self.focus.next();
        Effect::Message(format!("Focus: {}", self.focus_title()))
    }

}
