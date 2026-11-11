impl WorkspaceState {
    fn apply_nav(&mut self, nav: Nav) -> Result<Effect> {
        let page = self.page_rows;
        let workspace_len = self.workspace_rows().len();
        let (list, len) = match self.focus {
            FocusPane::Projects => (&mut self.project_list, self.projects.len()),
            FocusPane::GlobalSessions => (&mut self.global_session_list, self.global_sessions.len()),
            FocusPane::Workspaces => (&mut self.workspace_list, workspace_len),
            FocusPane::ProjectSessions => {
                (&mut self.project_session_list, self.project_sessions.len())
            }
        };
        if len == 0 {
            return Ok(Effect::None);
        }
        let next = nav.apply(list.selected().unwrap_or(0), len, page);
        self.select_in_focus(next)
    }

    fn select_in_focus(&mut self, index: usize) -> Result<Effect> {
        match self.focus {
            FocusPane::Projects => {
                let before = self.project_list.selected();
                self.project_list.select(Some(index));
                if before != Some(index) {
                    self.refresh_detail()?;
                }
            }
            FocusPane::GlobalSessions => self.global_session_list.select(Some(index)),
            FocusPane::Workspaces => self.workspace_list.select(Some(index)),
            FocusPane::ProjectSessions => self.project_session_list.select(Some(index)),
        }
        Ok(Effect::None)
    }

    fn focused_labels(&self) -> Vec<String> {
        match self.focus {
            FocusPane::Projects => self
                .projects
                .iter()
                .map(|project| format!("{} {}", project.name, project.slug))
                .collect(),
            FocusPane::GlobalSessions => self.global_sessions.iter().map(|s| s.label.clone()).collect(),
            FocusPane::Workspaces => self
                .workspace_rows()
                .iter()
                .map(|row| format!("{} {}", row.label, row.branch.as_deref().unwrap_or("")))
                .collect(),
            FocusPane::ProjectSessions => {
                self.project_sessions.iter().map(|s| s.label.clone()).collect()
            }
        }
    }

    fn focused_selection(&self) -> usize {
        match self.focus {
            FocusPane::Projects => self.project_list.selected(),
            FocusPane::GlobalSessions => self.global_session_list.selected(),
            FocusPane::Workspaces => self.workspace_list.selected(),
            FocusPane::ProjectSessions => self.project_session_list.selected(),
        }
        .unwrap_or(0)
    }

    pub fn start_search(&mut self) {
        self.search_input = Some(String::new());
    }

    pub fn cancel_search(&mut self) {
        self.search_input = None;
        self.nav = NavKeys::default();
    }

    pub fn search_input(&self) -> Option<&str> {
        self.search_input.as_deref()
    }

    pub fn nav_pending(&self) -> bool {
        self.nav.is_pending()
    }

    fn search_key(&mut self, key: KeyEvent) -> Result<Effect> {
        let Some(input) = self.search_input.as_mut() else {
            return Ok(Effect::None);
        };
        match key.code {
            KeyCode::Esc => self.search_input = None,
            KeyCode::Enter => {
                self.search_query = self.search_input.take().unwrap_or_default();
                return self.jump_to_match(false);
            }
            KeyCode::Backspace => {
                input.pop();
            }
            KeyCode::Char(character)
                if !key.modifiers.intersects(KeyModifiers::CONTROL | KeyModifiers::ALT) =>
            {
                input.push(character);
            }
            _ => {}
        }
        Ok(Effect::None)
    }

    fn jump_to_match(&mut self, backwards: bool) -> Result<Effect> {
        if self.search_query.is_empty() {
            return Ok(Effect::Message("Nothing to repeat; search with [/] first".into()));
        }
        let labels = self.focused_labels();
        let query = self.search_query.clone();
        let found = next_match(labels.len(), self.focused_selection(), backwards, |index| {
            smart_contains(&labels[index], &query)
        });
        match found {
            Some(index) => self.select_in_focus(index),
            None => Ok(Effect::Message(format!("No match for \"{query}\""))),
        }
    }
}
