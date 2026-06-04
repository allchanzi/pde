impl WorkspaceState {
    fn move_down(&mut self) -> Result<Effect> {
        match self.focus {
            FocusPane::Projects => {
                let before = self.project_list.selected();
                selection::next(&mut self.project_list, self.projects.len());
                if self.project_list.selected() != before {
                    self.refresh_detail()?;
                }
            }
            FocusPane::GlobalSessions => {
                selection::next(&mut self.global_session_list, self.global_sessions.len())
            }
            FocusPane::Workspaces => {
                let workspace_len = self.workspace_rows().len();
                selection::next(&mut self.workspace_list, workspace_len)
            }
            FocusPane::ProjectSessions => {
                selection::next(&mut self.project_session_list, self.project_sessions.len())
            }
        }
        Ok(Effect::None)
    }

    fn move_up(&mut self) -> Result<Effect> {
        match self.focus {
            FocusPane::Projects => {
                let before = self.project_list.selected();
                selection::previous(&mut self.project_list, self.projects.len());
                if self.project_list.selected() != before {
                    self.refresh_detail()?;
                }
            }
            FocusPane::GlobalSessions => {
                selection::previous(&mut self.global_session_list, self.global_sessions.len())
            }
            FocusPane::Workspaces => {
                let workspace_len = self.workspace_rows().len();
                selection::previous(&mut self.workspace_list, workspace_len)
            }
            FocusPane::ProjectSessions => {
                selection::previous(&mut self.project_session_list, self.project_sessions.len())
            }
        }
        Ok(Effect::None)
    }

    fn move_first(&mut self) -> Result<Effect> {
        match self.focus {
            FocusPane::Projects => {
                let before = self.project_list.selected();
                selection::first(&mut self.project_list, self.projects.len());
                if self.project_list.selected() != before {
                    self.refresh_detail()?;
                }
            }
            FocusPane::GlobalSessions => {
                selection::first(&mut self.global_session_list, self.global_sessions.len())
            }
            FocusPane::Workspaces => {
                let workspace_len = self.workspace_rows().len();
                selection::first(&mut self.workspace_list, workspace_len)
            }
            FocusPane::ProjectSessions => {
                selection::first(&mut self.project_session_list, self.project_sessions.len())
            }
        }
        Ok(Effect::None)
    }

    fn move_last(&mut self) -> Result<Effect> {
        match self.focus {
            FocusPane::Projects => {
                let before = self.project_list.selected();
                selection::last(&mut self.project_list, self.projects.len());
                if self.project_list.selected() != before {
                    self.refresh_detail()?;
                }
            }
            FocusPane::GlobalSessions => {
                selection::last(&mut self.global_session_list, self.global_sessions.len())
            }
            FocusPane::Workspaces => {
                let workspace_len = self.workspace_rows().len();
                selection::last(&mut self.workspace_list, workspace_len)
            }
            FocusPane::ProjectSessions => {
                selection::last(&mut self.project_session_list, self.project_sessions.len())
            }
        }
        Ok(Effect::None)
    }

    fn page_down(&mut self) -> Result<Effect> {
        self.page_by(PageDirection::Down)
    }

    fn page_up(&mut self) -> Result<Effect> {
        self.page_by(PageDirection::Up)
    }

    fn page_by(&mut self, direction: PageDirection) -> Result<Effect> {
        const PAGE_SIZE: usize = 8;
        match self.focus {
            FocusPane::Projects => {
                let before = self.project_list.selected();
                match direction {
                    PageDirection::Down => {
                        selection::page_down(&mut self.project_list, self.projects.len(), PAGE_SIZE)
                    }
                    PageDirection::Up => {
                        selection::page_up(&mut self.project_list, self.projects.len(), PAGE_SIZE)
                    }
                }
                if self.project_list.selected() != before {
                    self.refresh_detail()?;
                }
            }
            FocusPane::GlobalSessions => match direction {
                PageDirection::Down => selection::page_down(
                    &mut self.global_session_list,
                    self.global_sessions.len(),
                    PAGE_SIZE,
                ),
                PageDirection::Up => selection::page_up(
                    &mut self.global_session_list,
                    self.global_sessions.len(),
                    PAGE_SIZE,
                ),
            },
            FocusPane::Workspaces => {
                let workspace_len = self.workspace_rows().len();
                match direction {
                    PageDirection::Down => {
                        selection::page_down(&mut self.workspace_list, workspace_len, PAGE_SIZE)
                    }
                    PageDirection::Up => {
                        selection::page_up(&mut self.workspace_list, workspace_len, PAGE_SIZE)
                    }
                }
            }
            FocusPane::ProjectSessions => match direction {
                PageDirection::Down => selection::page_down(
                    &mut self.project_session_list,
                    self.project_sessions.len(),
                    PAGE_SIZE,
                ),
                PageDirection::Up => selection::page_up(
                    &mut self.project_session_list,
                    self.project_sessions.len(),
                    PAGE_SIZE,
                ),
            },
        }
        Ok(Effect::None)
    }

}
