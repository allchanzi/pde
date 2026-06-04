impl CreateProjectState {
    fn handle_confirm_key(&mut self, key: KeyCode) -> Effect {
        match key {
            KeyCode::Enter => self.submit(),
            KeyCode::Esc => {
                self.confirm = ConfirmState::Editing;
                Effect::None
            }
            _ => Effect::None,
        }
    }

    fn next_field(&mut self) -> Effect {
        self.field = match self.field {
            Field::Name => Field::Type,
            Field::Type => Field::Path,
            Field::Path => Field::BaseBranch,
            Field::BaseBranch => Field::Layout,
            Field::Layout => return self.request_confirmation(),
        };
        Effect::None
    }

    fn previous_field(&mut self) {
        self.field = match self.field {
            Field::Name => Field::Name,
            Field::Type => Field::Name,
            Field::Path => Field::Type,
            Field::BaseBranch => Field::Path,
            Field::Layout => Field::BaseBranch,
        };
    }

    fn request_confirmation(&mut self) -> Effect {
        if self.name.trim().is_empty() {
            return Effect::Message("Project name is required".into());
        }
        if self.path.trim().is_empty() {
            return Effect::Message("Project path is required".into());
        }
        self.confirm = ConfirmState::ConfirmCreate;
        Effect::None
    }

    fn submit(&self) -> Effect {
        Effect::CreateProjectSubmit(CreateProjectSpec {
            name: self.name.trim().into(),
            project_type: self.project_type,
            path: self.path.trim().into(),
            base_branch: self.base_branch.trim().into(),
            layout: self.layout.clone(),
        })
    }

    fn handle_pending_n(&mut self, key: KeyCode) -> Effect {
        if self.field != Field::Layout {
            return Effect::None;
        }
        match key {
            KeyCode::Char('w') => {
                self.add_window();
                Effect::Message("Added window/tab".into())
            }
            KeyCode::Char('r') => {
                self.add_row();
                Effect::Message("Added row".into())
            }
            KeyCode::Char('p') => self.open_new_pane_picker(),
            _ => Effect::None,
        }
    }

    fn handle_new_pane_picker_key(&mut self, key: KeyCode) -> Effect {
        match key {
            KeyCode::Esc => {
                self.new_pane_picker = None;
                Effect::None
            }
            KeyCode::Char('j') | KeyCode::Down => {
                self.move_new_pane_picker(1);
                Effect::None
            }
            KeyCode::Char('k') | KeyCode::Up => {
                self.move_new_pane_picker(-1);
                Effect::None
            }
            KeyCode::Enter => self.apply_new_pane_picker_choice(),
            KeyCode::Char('e') => self.apply_new_pane_choice(NewPaneChoice::EditorTab),
            KeyCode::Char('i') => self.apply_new_pane_choice(NewPaneChoice::IdeTab),
            KeyCode::Char('g') => self.apply_new_pane_choice(NewPaneChoice::GitTab),
            KeyCode::Char('d') => self.apply_new_pane_choice(NewPaneChoice::DockerTab),
            KeyCode::Char('K') => self.apply_new_pane_choice(NewPaneChoice::K9sTab),
            KeyCode::Char('m') => self.apply_new_pane_choice(NewPaneChoice::MonitorTab),
            KeyCode::Char(' ') | KeyCode::Char('p') => {
                self.apply_new_pane_choice(NewPaneChoice::EmptyPane)
            }
            _ => Effect::None,
        }
    }

    fn move_new_pane_picker(&mut self, delta: i16) {
        let Some(picker) = &mut self.new_pane_picker else {
            return;
        };
        let max_index = NEW_PANE_CHOICES.len() - 1;
        picker.selected = if delta < 0 {
            picker.selected.saturating_sub(1)
        } else {
            (picker.selected + 1).min(max_index)
        };
    }

    fn apply_new_pane_picker_choice(&mut self) -> Effect {
        let selected = self
            .new_pane_picker
            .map(|picker| picker.selected)
            .unwrap_or_default();
        self.apply_new_pane_choice(NEW_PANE_CHOICES[selected])
    }

    fn apply_new_pane_choice(&mut self, choice: NewPaneChoice) -> Effect {
        self.new_pane_picker = None;
        match choice {
            NewPaneChoice::EmptyPane => {
                self.add_pane();
                Effect::Message("Added empty pane/cell".into())
            }
            NewPaneChoice::EditorTab => self.add_preset_tab(editor_tab()),
            NewPaneChoice::IdeTab => self.add_preset_tab(ide_tab()),
            NewPaneChoice::GitTab => self.add_preset_tab(command_tab("git", "lazygit")),
            NewPaneChoice::DockerTab => self.add_preset_tab(command_tab("docker", "lazydocker")),
            NewPaneChoice::K9sTab => self.add_preset_tab(command_tab("k9s", "k9s")),
            NewPaneChoice::MonitorTab => self.add_preset_tab(monitor_tab()),
        }
    }

    fn open_new_pane_picker(&mut self) -> Effect {
        self.new_pane_picker = Some(NewPanePickerState { selected: 0 });
        Effect::None
    }

    fn handle_pending_preset(&mut self, key: KeyCode) -> Effect {
        if self.field != Field::Layout {
            return Effect::None;
        }
        match key {
            KeyCode::Char('e') => self.add_preset_tab(editor_tab()),
            KeyCode::Char('i') => self.add_preset_tab(ide_tab()),
            KeyCode::Char('g') => self.add_preset_tab(command_tab("git", "lazygit")),
            KeyCode::Char('d') => self.add_preset_tab(command_tab("docker", "lazydocker")),
            KeyCode::Char('k') => self.add_preset_tab(command_tab("k9s", "k9s")),
            KeyCode::Char('m') => self.add_preset_tab(monitor_tab()),
            _ => Effect::None,
        }
    }

    fn handle_layout_edit_key(&mut self, key: KeyCode) -> Effect {
        match key {
            KeyCode::Esc => {
                self.layout_mode = LayoutEditMode::Navigate;
                Effect::None
            }
            KeyCode::Backspace => {
                self.current_pane_mut().command.pop();
                Effect::None
            }
            KeyCode::Enter => {
                self.layout_mode = LayoutEditMode::Navigate;
                Effect::None
            }
            KeyCode::Char(character) => {
                self.current_pane_mut().command.push(character);
                Effect::None
            }
            _ => Effect::None,
        }
    }

    fn push_char(&mut self, character: char) {
        match self.field {
            Field::Name => self.name.push(character),
            Field::Path => self.path.push(character),
            Field::BaseBranch => self.base_branch.push(character),
            Field::Layout => self.current_pane_mut().command.push(character),
            Field::Type => {}
        }
        self.update_default_path();
    }

    fn backspace(&mut self) {
        match self.field {
            Field::Name => {
                self.name.pop();
            }
            Field::Path => {
                self.path.pop();
            }
            Field::BaseBranch => {
                self.base_branch.pop();
            }
            Field::Layout => {}
            Field::Type => {}
        }
        self.update_default_path();
    }

    fn update_default_path(&mut self) {
        if self.field == Field::Name
            && (self.path.is_empty() || self.path == default_path("project"))
        {
            self.path = default_path(if self.name.trim().is_empty() {
                "project"
            } else {
                &self.name
            });
        }
    }

    fn add_window(&mut self) {
        let index = self.layout.len() + 1;
        self.layout.push(LayoutTab {
            name: format!("window{index}"),
            rows: vec![LayoutRow {
                ratio: 1,
                panes: vec![LayoutPane {
                    ratio: 1,
                    command: String::new(),
                }],
            }],
            preset: None,
        });
        self.selected_tab = self.layout.len() - 1;
        self.selected_row = 0;
        self.selected_pane = 0;
    }

    fn add_row(&mut self) {
        self.current_tab_mut().rows.push(LayoutRow {
            ratio: 1,
            panes: vec![LayoutPane {
                ratio: 1,
                command: String::new(),
            }],
        });
        self.selected_row = self.current_tab().rows.len() - 1;
        self.selected_pane = 0;
    }

    fn add_pane(&mut self) {
        self.current_row_mut().panes.push(LayoutPane {
            ratio: 1,
            command: String::new(),
        });
        self.selected_pane = self.current_row().panes.len() - 1;
    }

    fn add_preset_tab(&mut self, tab: LayoutTab) -> Effect {
        let name = tab.name.clone();
        self.layout.push(tab);
        self.selected_tab = self.layout.len() - 1;
        self.selected_row = 0;
        self.selected_pane = 0;
        Effect::Message(format!("Added preset tab: {name}"))
    }
}
