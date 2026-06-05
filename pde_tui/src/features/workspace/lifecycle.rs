impl WorkspaceState {
    pub fn load(root: PathBuf) -> Result<Self> {
        let projects = load_projects()?;
        let mut state = Self {
            root,
            projects,
            detail: None,
            global_sessions: load_global_sessions(),
            project_sessions: vec![],
            focus: FocusPane::Projects,
            project_list: ListState::default(),
            workspace_list: ListState::default(),
            global_session_list: ListState::default(),
            project_session_list: ListState::default(),
            pending_g: false,
        };
        selection::select_first_when_present(&mut state.project_list, state.projects.len());
        selection::select_first_when_present(
            &mut state.global_session_list,
            state.global_sessions.len(),
        );
        state.refresh_detail()?;
        Ok(state)
    }

    pub fn help() -> &'static str {
        HELP
    }

    pub fn root(&self) -> &Path {
        &self.root
    }

    pub fn active_help_lines(&self, theme: &UiTheme) -> Vec<Line<'static>> {
        let title = format!("{} shortcuts", self.focus_title());
        let pane_lines: Vec<Line<'static>> = match self.focus {
            FocusPane::Projects => vec![
                Line::from("Enter/o Open selected project"),
                Line::from("a      [a]dd/register project"),
                Line::from("d      [d]elete selected project registration"),
                Line::from("j/k    Vim down/up: move selection"),
                Line::from("gg/G   First/last item"),
                Line::from("C-d/u  Page down/up"),
            ],
            FocusPane::GlobalSessions => vec![
                Line::from("Enter/o Attach selected tmux/zellij session"),
                Line::from("d      [d]elete/kill selected session"),
                Line::from("j/k    Vim down/up: move selection"),
            ],
            FocusPane::Workspaces => vec![
                Line::from("Enter/o Open selected workspace/worktree"),
                Line::from("a      [a]dd new worktree"),
                Line::from("d      [d]elete selected worktree"),
                Line::from("j/k    Vim down/up: move selection"),
            ],
            FocusPane::ProjectSessions => vec![
                Line::from("Enter/o Attach selected project session"),
                Line::from("d      [d]elete/kill selected session"),
                Line::from("j/k    Vim down/up: move selection"),
            ],
        };

        [
            vec![
                Line::from(Span::styled(title, theme.help_title())),
                Line::from(""),
            ],
            pane_lines,
            vec![
                Line::from(""),
                Line::from(Span::styled("Global shortcuts", theme.title())),
                Line::from("?                 Help toggle"),
                Line::from("Tab               Next pane"),
                Line::from("h/l or Alt+h/l    Vim left/right: focus left/right"),
                Line::from("Alt+j/k or Alt+s/w Vim/WASD: focus down/up"),
                Line::from("gg / G            Vim: first / last item"),
                Line::from("Ctrl+d / Ctrl+u   Vim: page down / up"),
                Line::from("r                 [r]efresh"),
                Line::from("q / Esc           [q]uit / escape"),
            ],
        ]
        .into_iter()
        .flatten()
        .collect()
    }

}
