use super::*;

fn project(slug: &str) -> Project {
    Project {
        slug: slug.into(),
        name: slug.into(),
        path: format!("/projects/{slug}"),
        base_branch: None,
        layout_variant: None,
    }
}

fn detail(slug: &str) -> ProjectInspect {
    serde_json::from_value(serde_json::json!({
        "project": { "slug": slug, "name": slug, "path": format!("/projects/{slug}") },
        "rows": [{
            "kind": "main", "label": "main workspace", "branch": null,
            "path": format!("/projects/{slug}"), "session_name": slug,
            "zellij_session_name": slug, "zellij_active": true
        }],
        "sessions": {"tmux": [], "zellij": [slug]}
    }))
    .unwrap()
}

fn request(generation: u64, slug: Option<&str>, refresh_sessions: bool) -> LoadRequest {
    LoadRequest {
        id: 0,
        generation,
        slug: slug.map(str::to_string),
        refresh_sessions,
    }
}

fn result(generation: u64, slug: &str) -> LoadResult {
    let detail = detail(slug);
    let sessions = detail.sessions.as_ref().map(inspect_sessions);
    LoadResult {
        id: 0,
        generation,
        slug: Some(slug.into()),
        detail: Ok(Some(detail)),
        sessions,
    }
}

fn state() -> WorkspaceState {
    let mut state = WorkspaceState::fixture();
    state.projects = vec![project("alpha"), project("beta"), project("gamma")];
    state.focus = FocusPane::Projects;
    state.project_list.select(Some(0));
    state
}

#[test]
fn navigation_stays_responsive_while_worker_is_blocked_and_skips_queued_projects() {
    let (started, running) = mpsc::channel();
    let (release, gate) = mpsc::channel();
    let mut state = state();
    state.loader = BackgroundLoader::start_with(move |request| {
        let slug = request.slug.as_deref().unwrap();
        started.send(slug.to_string()).unwrap();
        gate.recv_timeout(Duration::from_secs(2)).unwrap();
        let mut result = result(request.generation, slug);
        result.id = request.id;
        result
    })
    .unwrap();
    state.refresh_detail(false);
    assert_eq!(
        running.recv_timeout(Duration::from_secs(2)).unwrap(),
        "alpha"
    );

    let before = Instant::now();
    for _ in 0..2 {
        state
            .handle_key(KeyEvent::new(KeyCode::Char('j'), KeyModifiers::NONE))
            .unwrap();
    }
    assert!(before.elapsed() < Duration::from_millis(100));
    assert_eq!(state.selected_project().unwrap().slug, "gamma");
    assert!(state.detail.is_none());
    assert_eq!(state.detail_status(), Some("Loading…"));

    release.send(()).unwrap();
    assert_eq!(
        running.recv_timeout(Duration::from_secs(2)).unwrap(),
        "gamma"
    );
    state.poll_background();
    assert!(state.detail.is_none(), "alpha must not overwrite gamma");
    assert!(state.detail_cache.contains_key("alpha"));
    release.send(()).unwrap();
    let deadline = Instant::now() + Duration::from_secs(2);
    while state.background_pending() && Instant::now() < deadline {
        state.poll_background();
        thread::yield_now();
    }
    assert!(!state.background_pending());
    assert_eq!(state.detail.as_ref().unwrap().project.slug, "gamma");
    assert!(running.try_recv().is_err(), "beta must never be inspected");
}

#[test]
fn cache_hit_is_immediate_and_expired_cache_stays_visible_while_refreshing() {
    let mut state = state();
    let (requests, queued) = mpsc::channel();
    state.loader.requests = requests;
    state.accept_background(result(0, "beta"));
    state.select_in_focus(1).unwrap();
    assert_eq!(state.detail.as_ref().unwrap().project.slug, "beta");
    assert!(!state.detail_loading);
    assert!(
        queued.try_recv().unwrap().slug.is_none(),
        "a fresh cache hit must not inspect"
    );
    assert_eq!(state.project_sessions[0].session, "beta");

    state.detail_cache.get_mut("beta").unwrap().loaded_at =
        Instant::now() - DETAIL_CACHE_TTL - Duration::from_secs(1);
    state.refresh_detail(false);
    assert_eq!(state.detail.as_ref().unwrap().project.slug, "beta");
    assert!(state.detail_loading);
    assert_eq!(queued.try_recv().unwrap().slug.as_deref(), Some("beta"));
}

#[test]
fn switching_to_an_uncached_project_clears_old_rows_and_actions() {
    let mut state = state();
    state.accept_background(result(0, "alpha"));
    assert!(!state.project_sessions.is_empty());
    state.select_in_focus(1).unwrap();
    assert!(state.workspace_rows().is_empty());
    assert!(state.project_sessions.is_empty());
    assert_eq!(state.open_workspace_action(), Effect::None);
    assert!(
        matches!(state.open_action(), Effect::Suspend(ExternalCommand::Projects(args))
        if args == ["open", "beta"])
    );
}

#[test]
fn refresh_generation_rejects_old_details_and_session_snapshots() {
    let mut state = state();
    state.accept_background(result(0, "alpha"));
    let sessions_before = state.global_sessions[0].session.clone();
    state.replace_projects(vec![project("alpha"), project("beta")]);
    state.accept_background(result(0, "beta"));
    assert!(state.detail.is_none());
    assert!(state.detail_cache.is_empty());
    assert!(state.detail_loading);
    assert_eq!(state.global_sessions[0].session, sessions_before);
    state.accept_background(result(1, "alpha"));
    assert_eq!(state.detail.as_ref().unwrap().project.slug, "alpha");
}

#[test]
fn background_errors_are_visible_and_recoverable_without_losing_selection() {
    let mut state = state();
    let mut failed = result(0, "alpha");
    failed.detail = Err(anyhow::anyhow!("cannot inspect alpha"));
    failed.sessions = None;
    assert_eq!(
        state.accept_background(failed).as_deref(),
        Some("cannot inspect alpha")
    );
    assert_eq!(state.detail_status(), Some("cannot inspect alpha"));
    assert_eq!(state.selected_project().unwrap().slug, "alpha");
    state.accept_background(result(0, "alpha"));
    assert!(state.detail_status().is_none());
    assert_eq!(state.workspace_rows().len(), 1);
}

#[test]
fn coalescing_preserves_refresh_but_cache_hits_cancel_queued_inspection() {
    let latest = latest_request(
        request(1, Some("alpha"), true),
        [request(1, Some("beta"), false), request(1, None, false)].into_iter(),
    );
    assert!(latest.slug.is_none());
    assert!(latest.refresh_sessions);
    let latest = latest_request(
        request(1, Some("alpha"), true),
        [request(2, Some("gamma"), false)].into_iter(),
    );
    assert_eq!(latest.slug.as_deref(), Some("gamma"));
    assert!(!latest.refresh_sessions);
}

#[test]
fn session_snapshot_contains_both_backends_and_supports_an_empty_registry() {
    let snapshot = InspectSessions {
        tmux: vec!["one".into()],
        zellij: vec!["two".into()],
    };
    let sessions = inspect_sessions(&snapshot);
    assert_eq!(sessions[0].backend, SessionBackend::Tmux);
    assert_eq!(sessions[1].backend, SessionBackend::Zellij);
    let mut state = state();
    state.projects.clear();
    let (requests, queued) = mpsc::channel();
    state.loader.requests = requests;
    state.refresh_detail(true);
    let queued = queued.try_recv().unwrap();
    assert!(queued.slug.is_none());
    assert!(queued.refresh_sessions);
    state.accept_background(LoadResult {
        id: 0,
        generation: 0,
        slug: None,
        detail: Ok(None),
        sessions: Some(sessions),
    });
    assert_eq!(state.global_sessions.len(), 2);
    assert_eq!(state.global_session_list.selected(), Some(0));
}
