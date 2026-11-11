impl WorkspaceState {
    pub fn shortcuts(&self) -> &'static str {
        match self.focus {
            FocusPane::Projects => "[Enter/o] open • [e]dit • [a]dd • [b]ranch • [d]elete",
            FocusPane::Workspaces => "[Enter/o] open • [e]dit • [a]dd • [b]ranch • [d]elete",
            FocusPane::GlobalSessions | FocusPane::ProjectSessions => "[Enter/o] attach • [d]elete session",
        }
    }

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

    pub fn focus_title(&self) -> &'static str {
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

impl WorkspaceState {
    pub fn details(&self, tab: usize) -> Vec<String> {
        match tab {
            0 => self.selected_project().map(|p| vec![
                format!("Name: {}", p.name), format!("Slug: {}", p.slug),
                format!("Path: {}", p.path),
                format!("Base branch: {}", p.base_branch.as_deref().unwrap_or("main")),
                format!("Layout: {}", p.layout_variant.as_deref().unwrap_or("default")),
            ]).unwrap_or_else(|| vec!["No project selected.".into()]),
            1 => self.workspace_rows().iter().flat_map(|r| [
                format!("{} ({})", r.label, r.kind), format!("Branch: {}", r.branch.as_deref().unwrap_or("-")),
                format!("Path: {}", r.path), format!("tmux: {} / zellij: {}", r.tmux_active, r.zellij_active), String::new(),
            ]).collect(),
            2 | 3 => {
                let sessions = if tab == 2 { &self.global_sessions } else { &self.project_sessions };
                sessions.iter().map(|s| format!("{:?}: {} ({})", s.backend, s.label, s.session)).collect()
            }
            _ => vec![format!("Focus: {}", self.focus_title()), format!("Projects: {}", self.projects.len()),
                format!("Workspaces: {}", self.workspace_rows().len()),
                format!("PDE root: {}", self.root.display()),
                "Sessions open externally in tmux/zellij; there is no embedded terminal.".into()],
        }
    }
}
