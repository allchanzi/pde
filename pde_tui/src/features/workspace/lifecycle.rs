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
                theme.shortcut_line("[Enter] / [o]pen selected project"),
                theme.shortcut_line("[e]dit project details"),
                theme.shortcut_line("[a]dd/register project"),
                theme.shortcut_line("[b]ranch picker: open branch in worktree"),
                theme.shortcut_line("[d]elete selected project registration"),
            ],
            FocusPane::GlobalSessions => vec![
                theme.shortcut_line("[Enter/o] attach selected tmux/zellij session"),
                theme.shortcut_line("[d]elete/kill selected session"),
            ],
            FocusPane::Workspaces => vec![
                theme.shortcut_line("[Enter] / [o]pen selected workspace/worktree"),
                theme.shortcut_line("[e]dit project details"),
                theme.shortcut_line("[a]dd new worktree"),
                theme.shortcut_line("[b]ranch picker: open branch in worktree"),
                theme.shortcut_line("[d]elete selected worktree"),
            ],
            FocusPane::ProjectSessions => vec![
                theme.shortcut_line("[Enter/o] attach selected project session"),
                theme.shortcut_line("[d]elete/kill selected session"),
            ],
        };

        [
            vec![
                Line::from(Span::styled(title, theme.help_title())),
                theme.shortcut_line(""),
            ],
            pane_lines,
            vec![
                theme.shortcut_line(""),
                Line::from(Span::styled("Global shortcuts", theme.title())),
                theme.shortcut_line("[?] toggle help"),
                theme.shortcut_line("[Tab/Shift+Tab] next/previous pane"),
                theme.shortcut_line("[j/k] / [↓/↑] select next/previous item"),
                theme.shortcut_line("[h/l] / [Alt+h/l] focus left/right"),
                theme.shortcut_line("[Alt+j/k] / [Alt+s/w] focus down/up"),
                theme.shortcut_line("[gg/G] / [Home/End] first/last item"),
                theme.shortcut_line("[PgDn/PgUp] / [Ctrl+d/u] / []/[] page down/up"),
                theme.shortcut_line("[r]efresh"),
                theme.shortcut_line("[u]pdate PDE, rtui and pantsui"),
                theme.shortcut_line("[q]uit / [Esc] quit"),
            ],
        ]
        .into_iter()
        .flatten()
        .collect()
    }

}
