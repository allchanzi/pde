impl CreateProjectState {
    pub fn new() -> Self {
        Self {
            field: Field::Name,
            name: String::new(),
            path: default_path("project"),
            base_branch: "main".into(),
            layout: vec![LayoutTab {
                name: "terminal".into(),
                rows: vec![LayoutRow {
                    ratio: 1,
                    panes: vec![LayoutPane {
                        ratio: 1,
                        command: String::new(),
                    }],
                }],
                preset: None,
            }],
            selected_tab: 0,
            selected_row: 0,
            selected_pane: 0,
            pending_n: false,
            pending_delete: false,
            new_pane_picker: None,
            layout_mode: LayoutEditMode::Navigate,
            confirm: ConfirmState::Editing,
        }
    }

    pub fn handle_key(&mut self, key: KeyEvent) -> Result<Effect> {
        if self.confirm == ConfirmState::ConfirmCreate {
            return Ok(self.handle_confirm_key(key.code));
        }
        if self.new_pane_picker.is_some() {
            return Ok(self.handle_new_pane_picker_key(key.code));
        }
        if self.field == Field::Layout && self.layout_mode == LayoutEditMode::EditCommand {
            return Ok(self.handle_layout_edit_key(key.code));
        }
        if self.pending_n {
            self.pending_n = false;
            return Ok(self.handle_pending_n(key.code));
        }
        if self.pending_delete {
            self.pending_delete = false;
            return Ok(self.handle_pending_delete(key.code));
        }

        Ok(match key.code {
            KeyCode::Char('?') => Effect::ToggleHelp,
            KeyCode::Esc => Effect::CloseCreateProject,
            KeyCode::Enter if self.field == Field::Layout => self.request_confirmation(),
            KeyCode::Enter | KeyCode::Tab => self.next_field(),
            KeyCode::BackTab => {
                self.previous_field();
                Effect::None
            }
            KeyCode::Backspace => {
                self.backspace();
                Effect::None
            }
            KeyCode::Char('h') | KeyCode::Left if self.field == Field::Layout => {
                self.move_pane_left();
                Effect::None
            }
            KeyCode::Char('l') | KeyCode::Right if self.field == Field::Layout => {
                self.move_pane_right();
                Effect::None
            }
            KeyCode::Char('j') | KeyCode::Down if self.field == Field::Layout => {
                self.move_row_down();
                Effect::None
            }
            KeyCode::Char('k') | KeyCode::Up if self.field == Field::Layout => {
                self.move_row_up();
                Effect::None
            }
            KeyCode::Char('[') if self.field == Field::Layout => {
                self.previous_tab();
                Effect::None
            }
            KeyCode::Char(']') if self.field == Field::Layout => {
                self.next_tab();
                Effect::None
            }
            KeyCode::Char('+') if self.field == Field::Layout => {
                self.adjust_pane_ratio(1);
                Effect::None
            }
            KeyCode::Char('-') if self.field == Field::Layout => {
                self.adjust_pane_ratio(-1);
                Effect::None
            }
            KeyCode::Char('}') if self.field == Field::Layout => {
                self.adjust_row_ratio(1);
                Effect::None
            }
            KeyCode::Char('{') if self.field == Field::Layout => {
                self.adjust_row_ratio(-1);
                Effect::None
            }
            KeyCode::Char('i') if self.field == Field::Layout => {
                self.layout_mode = LayoutEditMode::EditCommand;
                Effect::Message(
                    "Layout command edit mode: type command, Esc returns to navigation".into(),
                )
            }
            KeyCode::Char('p') if self.field == Field::Layout => self.open_new_pane_picker(),
            KeyCode::Char('n') if self.field == Field::Layout => {
                self.pending_n = true;
                Effect::Message("Layout: n p=new pane, n r=new row, n w=window preset popup".into())
            }
            KeyCode::Char('d') if self.field == Field::Layout => {
                self.pending_delete = true;
                Effect::Message("Layout delete: d p=pane, d r=row, d w=window/tab".into())
            }
            KeyCode::Char(character) if self.field != Field::Layout => {
                self.push_char(character);
                Effect::None
            }
            _ => Effect::None,
        })
    }

}
