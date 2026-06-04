impl WorkspaceState {
    fn selected_project(&self) -> Option<&Project> {
        self.project_list
            .selected()
            .and_then(|index| self.projects.get(index))
    }

    fn selected_workspace(&self) -> Option<&WorkspaceRow> {
        self.workspace_list
            .selected()
            .and_then(|index| self.workspace_rows().get(index))
    }

    fn selected_session(&self, pane: SessionPane) -> Option<&SessionRow> {
        match pane {
            SessionPane::Global => self
                .global_session_list
                .selected()
                .and_then(|index| self.global_sessions.get(index)),
            SessionPane::Project => self
                .project_session_list
                .selected()
                .and_then(|index| self.project_sessions.get(index)),
        }
    }

    fn workspace_rows(&self) -> &[WorkspaceRow] {
        self.detail
            .as_ref()
            .map(|detail| detail.rows.as_slice())
            .unwrap_or(&[])
    }

    fn focus_title(&self) -> &'static str {
        match self.focus {
            FocusPane::Projects => "Projects",
            FocusPane::GlobalSessions => "Global sessions",
            FocusPane::Workspaces => "Workspaces",
            FocusPane::ProjectSessions => "Project sessions",
        }
    }
}

#[derive(Debug, Clone, Copy)]
enum SessionPane {
    Global,
    Project,
}

#[derive(Debug, Clone, Copy)]
enum PageDirection {
    Down,
    Up,
}
