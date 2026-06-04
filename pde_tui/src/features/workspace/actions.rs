impl WorkspaceState {
    pub fn refresh_from_external(&mut self) -> Result<()> {
        self.projects = load_projects()?;
        self.global_sessions = load_global_sessions();
        selection::clamp_selection(&mut self.project_list, self.projects.len());
        selection::clamp_selection(&mut self.global_session_list, self.global_sessions.len());
        self.refresh_detail()?;
        Ok(())
    }

    fn refresh_all(&mut self) -> Result<Effect> {
        self.refresh_from_external()?;
        Ok(Effect::Message(
            "Refreshed projects, workspaces and sessions".into(),
        ))
    }

    fn refresh_detail(&mut self) -> Result<()> {
        self.detail = self
            .selected_project()
            .map(|project| inspect_project(&self.root, &project.slug))
            .transpose()?;
        let workspace_len = self.workspace_rows().len();
        selection::clamp_selection(&mut self.workspace_list, workspace_len);
        self.project_sessions = self
            .detail
            .as_ref()
            .map(active_project_sessions)
            .unwrap_or_default();
        selection::clamp_selection(&mut self.project_session_list, self.project_sessions.len());
        Ok(())
    }

    fn add_action(&self) -> Effect {
        match self.focus {
            FocusPane::Projects => Effect::OpenCreateProject,
            FocusPane::Workspaces => self
                .selected_project()
                .map(|project| {
                    Effect::Suspend(ExternalCommand::CorePdeWorktree(vec![
                        "new".into(),
                        "--project".into(),
                        project.slug.clone(),
                    ]))
                })
                .unwrap_or(Effect::None),
            FocusPane::GlobalSessions | FocusPane::ProjectSessions => {
                Effect::Message("Sessions: Enter attaches, d kills selected session".into())
            }
        }
    }

    fn delete_action(&self) -> Effect {
        match self.focus {
            FocusPane::Projects => self
                .selected_project()
                .map(|project| {
                    Effect::Suspend(ExternalCommand::Projects(vec![
                        "delete".into(),
                        project.slug.clone(),
                        "--yes".into(),
                    ]))
                })
                .unwrap_or(Effect::None),
            FocusPane::Workspaces => self
                .selected_workspace()
                .and_then(|row| row.branch.as_ref().map(|branch| (row, branch)))
                .map(|(_, branch)| {
                    Effect::Suspend(ExternalCommand::Projects(vec![
                        "open".into(),
                        self.selected_project()
                            .map(|project| project.slug.clone())
                            .unwrap_or_default(),
                        "--delete-worktree".into(),
                        "-b".into(),
                        branch.clone(),
                    ]))
                })
                .unwrap_or_else(|| Effect::Message("Main workspace cannot be deleted".into())),
            FocusPane::GlobalSessions => self.kill_session_action(SessionPane::Global),
            FocusPane::ProjectSessions => self.kill_session_action(SessionPane::Project),
        }
    }

    fn open_action(&self) -> Effect {
        match self.focus {
            FocusPane::Projects => self
                .selected_project()
                .map(|project| ExternalCommand::Projects(vec!["open".into(), project.slug.clone()]))
                .map(Effect::Exec)
                .unwrap_or(Effect::None),
            FocusPane::Workspaces => self.open_workspace_action(),
            FocusPane::GlobalSessions => self.attach_session_action(SessionPane::Global),
            FocusPane::ProjectSessions => self.attach_session_action(SessionPane::Project),
        }
    }

    fn open_workspace_action(&self) -> Effect {
        self.selected_workspace()
            .and_then(|row| {
                self.selected_project()
                    .map(|project| match row.branch.as_ref() {
                        Some(branch) => ExternalCommand::Projects(vec![
                            "open".into(),
                            project.slug.clone(),
                            "-b".into(),
                            branch.clone(),
                        ]),
                        None => {
                            ExternalCommand::Projects(vec!["open".into(), project.slug.clone()])
                        }
                    })
            })
            .map(Effect::Exec)
            .unwrap_or(Effect::None)
    }

    fn attach_session_action(&self, pane: SessionPane) -> Effect {
        self.selected_session(pane)
            .map(|session| match session.backend {
                SessionBackend::Tmux => ExternalCommand::Program {
                    program: "tmux".into(),
                    args: vec![
                        "attach-session".into(),
                        "-t".into(),
                        session.session.clone(),
                    ],
                },
                SessionBackend::Zellij => ExternalCommand::Program {
                    program: "zellij".into(),
                    args: vec!["attach".into(), session.session.clone()],
                },
            })
            .map(Effect::Exec)
            .unwrap_or_else(|| Effect::Message("No active session selected".into()))
    }

    fn kill_session_action(&self, pane: SessionPane) -> Effect {
        self.selected_session(pane)
            .map(|session| match session.backend {
                SessionBackend::Tmux => ExternalCommand::Program {
                    program: "tmux".into(),
                    args: vec!["kill-session".into(), "-t".into(), session.session.clone()],
                },
                SessionBackend::Zellij => ExternalCommand::Program {
                    program: "zellij".into(),
                    args: vec![
                        "delete-session".into(),
                        "--force".into(),
                        session.session.clone(),
                    ],
                },
            })
            .map(Effect::Suspend)
            .unwrap_or_else(|| Effect::Message("No active session selected".into()))
    }

}
