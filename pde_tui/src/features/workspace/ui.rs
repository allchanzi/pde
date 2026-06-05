pub fn render(
    frame: &mut ratatui::Frame<'_>,
    area: Rect,
    state: &mut WorkspaceState,
    theme: &UiTheme,
) {
    let [left, right] = Layout::default()
        .direction(Direction::Horizontal)
        .constraints([Constraint::Percentage(50), Constraint::Percentage(50)])
        .areas(area);
    let [projects, global_sessions] = Layout::default()
        .direction(Direction::Vertical)
        .constraints([Constraint::Percentage(70), Constraint::Percentage(30)])
        .areas(left);
    let [workspaces, project_sessions] = Layout::default()
        .direction(Direction::Vertical)
        .constraints([Constraint::Percentage(70), Constraint::Percentage(30)])
        .areas(right);

    render_projects(frame, projects, state, theme);
    render_global_sessions(frame, global_sessions, state, theme);
    render_workspaces(frame, workspaces, state, theme);
    render_project_sessions(frame, project_sessions, state, theme);
}

fn render_projects(
    frame: &mut ratatui::Frame<'_>,
    area: Rect,
    state: &mut WorkspaceState,
    theme: &UiTheme,
) {
    let items = state
        .projects
        .iter()
        .map(|project| project_item(project, theme))
        .collect::<Vec<_>>();
    let list = List::new(items)
        .block(theme.panel_block("Global / Projects", state.focus == FocusPane::Projects))
        .highlight_style(theme.selected())
        .highlight_symbol("> ");
    frame.render_stateful_widget(list, area, &mut state.project_list);
}

fn render_workspaces(
    frame: &mut ratatui::Frame<'_>,
    area: Rect,
    state: &mut WorkspaceState,
    theme: &UiTheme,
) {
    let title = state
        .detail
        .as_ref()
        .map(workspaces_title)
        .unwrap_or_else(|| "Selected / Workspaces".into());
    let rows = state
        .workspace_rows()
        .iter()
        .map(|row| workspace_item(row, theme))
        .collect::<Vec<_>>();
    let list = List::new(rows)
        .block(theme.panel_block(title, state.focus == FocusPane::Workspaces))
        .highlight_style(theme.selected())
        .highlight_symbol("> ");
    frame.render_stateful_widget(list, area, &mut state.workspace_list);
}

fn render_global_sessions(
    frame: &mut ratatui::Frame<'_>,
    area: Rect,
    state: &mut WorkspaceState,
    theme: &UiTheme,
) {
    render_session_panel(
        frame,
        area,
        "Global / Sessions",
        state.focus == FocusPane::GlobalSessions,
        &state.global_sessions,
        &mut state.global_session_list,
        "No active global tmux/zellij sessions.",
        theme,
    );
}

fn render_project_sessions(
    frame: &mut ratatui::Frame<'_>,
    area: Rect,
    state: &mut WorkspaceState,
    theme: &UiTheme,
) {
    let title = state
        .detail
        .as_ref()
        .map(|detail| format!("Selected / Sessions for {}", detail.project.slug))
        .unwrap_or_else(|| "Selected / Sessions".into());
    render_session_panel(
        frame,
        area,
        title,
        state.focus == FocusPane::ProjectSessions,
        &state.project_sessions,
        &mut state.project_session_list,
        "No active tmux/zellij sessions for selected project.",
        theme,
    );
}

fn render_session_panel(
    frame: &mut ratatui::Frame<'_>,
    area: Rect,
    title: impl Into<String>,
    focused: bool,
    sessions: &[SessionRow],
    list_state: &mut ListState,
    empty_text: &'static str,
    theme: &UiTheme,
) {
    let title = title.into();
    if sessions.is_empty() {
        let empty = Paragraph::new(empty_text)
            .block(theme.panel_block(title, focused))
            .wrap(Wrap { trim: true });
        frame.render_widget(empty, area);
        return;
    }

    let rows = sessions
        .iter()
        .map(|session| session_item(session, theme))
        .collect::<Vec<_>>();
    let list = List::new(rows)
        .block(theme.panel_block(title, focused))
        .highlight_style(theme.selected())
        .highlight_symbol("> ");
    frame.render_stateful_widget(list, area, list_state);
}

fn workspaces_title(detail: &ProjectInspect) -> String {
    let branch = detail.project.base_branch.as_deref().unwrap_or("-");
    let layout = detail.project.layout_variant.as_deref().unwrap_or("-");
    format!(
        "Selected / Workspaces  {} ({}) branch:{branch} layout:{layout} path:{}",
        detail.project.name, detail.project.slug, detail.project.path
    )
}

fn project_item(project: &Project, theme: &UiTheme) -> ListItem<'static> {
    let branch = project.base_branch.as_deref().unwrap_or("-");
    let layout = project.layout_variant.as_deref().unwrap_or("-");
    ListItem::new(vec![
        Line::from(vec![
            Span::styled(project.name.clone(), theme.title()),
            Span::raw(format!(" ({})", project.slug)),
        ]),
        Line::from(format!(
            "    branch: {branch}  layout: {layout}  path: {}",
            project.path
        )),
    ])
}

fn workspace_item(row: &WorkspaceRow, theme: &UiTheme) -> ListItem<'static> {
    let marker = if row.kind == "main" {
        "main"
    } else {
        "worktree"
    };
    let sessions = [
        row.tmux_active.then_some("tmux"),
        row.zellij_active.then_some("zellij"),
    ]
    .into_iter()
    .flatten()
    .collect::<Vec<_>>()
    .join(",");
    let sessions = if sessions.is_empty() {
        "-".into()
    } else {
        sessions
    };

    ListItem::new(vec![
        Line::from(vec![
            Span::styled(row.label.clone(), theme.title()),
            Span::styled(format!("  [{marker}]"), theme.kind()),
            Span::raw(format!("  sessions: {sessions}")),
        ]),
        Line::from(format!("    {}", row.path)),
    ])
}

fn session_item(row: &SessionRow, theme: &UiTheme) -> ListItem<'static> {
    let backend = match row.backend {
        SessionBackend::Tmux => "tmux",
        SessionBackend::Zellij => "zellij",
    };
    ListItem::new(Line::from(vec![
        Span::styled(backend, theme.runner_backend()),
        Span::raw(format!("  {}", row.label)),
        Span::raw(format!("\n    {}", row.session)),
    ]))
}
