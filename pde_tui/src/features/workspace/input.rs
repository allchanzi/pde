impl WorkspaceState {
    pub fn handle_key(&mut self, key: KeyEvent) -> Result<Effect> {
        if self.search_input.is_some() {
            return self.search_key(key);
        }
        // Alt belongs to the terminal multiplexer.
        if key.modifiers.intersects(KeyModifiers::ALT | KeyModifiers::SUPER) {
            self.nav = NavKeys::default();
            return Ok(Effect::None);
        }
        match self.nav.press(key) {
            NavStep::Move(nav) => return self.apply_nav(nav),
            NavStep::Pending => return Ok(Effect::None),
            NavStep::Other => {}
        }
        if key.modifiers.contains(KeyModifiers::CONTROL) {
            return Ok(self.move_focus_by_key(key.code));
        }

        Ok(match key.code {
            KeyCode::Char('?') => Effect::ToggleHelp,
            KeyCode::Char('q') => Effect::Quit,
            KeyCode::Char(c @ '1'..='4') => {
                self.focus = match c {
                    '1' => FocusPane::Projects,
                    '2' => FocusPane::GlobalSessions,
                    '3' => FocusPane::Workspaces,
                    _ => FocusPane::ProjectSessions,
                };
                Effect::Message(format!("Focus: {}", self.focus_title()))
            }
            KeyCode::Tab => self.cycle_focus(),
            KeyCode::BackTab => {
                self.focus = self.focus.next().next().next();
                Effect::Message(format!("Focus: {}", self.focus_title()))
            }
            KeyCode::Char('/') => {
                self.start_search();
                Effect::None
            }
            KeyCode::Char('n') => self.jump_to_match(false)?,
            KeyCode::Char('N') => self.jump_to_match(true)?,
            KeyCode::Char('r') => self.refresh_all()?,
            KeyCode::Char('u') => self.update_action(),
            KeyCode::Char('h') | KeyCode::Left => self.move_focus_left(),
            KeyCode::Char('l') | KeyCode::Right => self.move_focus_right(),
            KeyCode::Char('e') if matches!(self.focus, FocusPane::Projects | FocusPane::Workspaces) => self.selected_project().map(|project| Effect::OpenEditProject(project.slug.clone())).unwrap_or(Effect::None),
            KeyCode::Char('a') => self.add_action(),
            KeyCode::Char('b') => self.branches_action(),
            KeyCode::Char('d') => self.delete_action(),
            KeyCode::Char('o') | KeyCode::Enter => self.open_action(),
            _ => Effect::None,
        })
    }

    fn move_focus_by_key(&mut self, key: KeyCode) -> Effect {
        let next_focus = match key {
            KeyCode::Char('h') => self.focus_left(),
            KeyCode::Char('l') => self.focus_right(),
            KeyCode::Char('k') => self.focus_up(),
            KeyCode::Char('j') => self.focus_down(),
            _ => return Effect::None,
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
