use std::{env, fs, path::Path, path::PathBuf, process::Command};

use anyhow::{Context, Result};
use crossterm::event::{KeyCode, KeyEvent, KeyModifiers};
use ratatui::{
    layout::Rect,
    text::{Line, Span},
    widgets::{List, ListItem, ListState, Paragraph, Wrap},
};
use serde::Deserialize;

use crate::{
    app::Effect,
    shared::{process::ExternalCommand, root::home_dir, selection, ui::theme::UiTheme},
};

const HELP: &str = "[?] help • [j/k] select • [h/l/1-4] focus • [g/G] first/last • [Ctrl+u/d] half page • [Ctrl+b/f] full page • [Enter/o] open or attach • [a]dd • [b]ranch • [e]dit • [d]elete • [r]efresh • [u]pdate • [q]uit";

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum FocusPane {
    Projects,
    GlobalSessions,
    Workspaces,
    ProjectSessions,
}

impl FocusPane {
    fn next(self) -> Self {
        match self {
            Self::Projects => Self::GlobalSessions,
            Self::GlobalSessions => Self::Workspaces,
            Self::Workspaces => Self::ProjectSessions,
            Self::ProjectSessions => Self::Projects,
        }
    }
}

#[derive(Debug, Deserialize)]
struct Registry {
    #[serde(default)]
    projects: Vec<Project>,
}

#[derive(Debug, Deserialize, Clone)]
pub struct Project {
    pub slug: String,
    pub name: String,
    pub path: String,
    #[serde(default)]
    pub base_branch: Option<String>,
    #[serde(default)]
    pub layout_variant: Option<String>,
}

#[derive(Debug, Deserialize, Clone)]
struct ProjectInspect {
    project: InspectProject,
    #[serde(default)]
    rows: Vec<WorkspaceRow>,
}

#[derive(Debug, Deserialize, Clone)]
struct InspectProject {
    name: String,
    slug: String,
    path: String,
    #[serde(default)]
    base_branch: Option<String>,
    #[serde(default)]
    layout_variant: Option<String>,
}

#[derive(Debug, Deserialize, Clone)]
struct WorkspaceRow {
    kind: String,
    label: String,
    branch: Option<String>,
    path: String,
    session_name: String,
    #[serde(default)]
    tmux_active: bool,
    zellij_session_name: String,
    #[serde(default)]
    zellij_active: bool,
}

#[derive(Debug, Clone)]
struct SessionRow {
    backend: SessionBackend,
    label: String,
    session: String,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
enum SessionBackend {
    Tmux,
    Zellij,
}

#[derive(Debug)]
pub struct WorkspaceState {
    root: PathBuf,
    projects: Vec<Project>,
    detail: Option<ProjectInspect>,
    global_sessions: Vec<SessionRow>,
    project_sessions: Vec<SessionRow>,
    focus: FocusPane,
    project_list: ListState,
    workspace_list: ListState,
    global_session_list: ListState,
    project_session_list: ListState,
    pending_g: bool,
    page_rows: usize,
}

include!("lifecycle.rs");
include!("input.rs");
include!("selection.rs");
include!("actions.rs");
include!("accessors.rs");
include!("ui.rs");
include!("data.rs");

#[cfg(test)]
impl WorkspaceState {
    pub(crate) fn fixture() -> Self {
        Self {
            root: PathBuf::from(env!("CARGO_MANIFEST_DIR"))
                .parent()
                .unwrap()
                .into(),
            projects: vec![],
            detail: None,
            global_sessions: (0..60)
                .map(|i| SessionRow {
                    backend: SessionBackend::Tmux,
                    label: format!("session {i}"),
                    session: format!("session-{i}"),
                })
                .collect(),
            project_sessions: vec![],
            focus: FocusPane::GlobalSessions,
            project_list: ListState::default(),
            workspace_list: ListState::default(),
            global_session_list: ListState::default().with_selected(Some(0)),
            project_session_list: ListState::default(),
            pending_g: false,
            page_rows: 10,
        }
    }
}

#[cfg(test)]
mod vim_tests {
    use super::*;
    fn key(code: KeyCode) -> KeyEvent {
        KeyEvent::new(code, KeyModifiers::NONE)
    }

    #[test]
    fn navigation_uses_focused_viewport_and_clamps() {
        let mut state = WorkspaceState::fixture();
        for (code, expected) in [('d', 5), ('f', 15), ('u', 10), ('b', 0)] {
            state
                .handle_key(KeyEvent::new(KeyCode::Char(code), KeyModifiers::CONTROL))
                .unwrap();
            assert_eq!(state.global_session_list.selected(), Some(expected));
        }
        state.handle_key(key(KeyCode::Char('G'))).unwrap();
        assert_eq!(state.global_session_list.selected(), Some(59));
        state.handle_key(key(KeyCode::Char('g'))).unwrap();
        assert_eq!(state.global_session_list.selected(), Some(0));
        state.handle_key(key(KeyCode::Char('j'))).unwrap();
        assert_eq!(state.global_session_list.selected(), Some(1));
        state.handle_key(key(KeyCode::Char('k'))).unwrap();
        assert_eq!(state.global_session_list.selected(), Some(0));
        state.page_rows = 1;
        state
            .handle_key(KeyEvent::new(KeyCode::Char('d'), KeyModifiers::CONTROL))
            .unwrap();
        assert_eq!(state.global_session_list.selected(), Some(1));
    }

    #[test]
    fn focus_cycles_both_ways_and_moves_to_neighbor() {
        let mut state = WorkspaceState::fixture();
        for expected in [
            FocusPane::Workspaces,
            FocusPane::ProjectSessions,
            FocusPane::Projects,
            FocusPane::GlobalSessions,
        ] {
            state.handle_key(key(KeyCode::Tab)).unwrap();
            assert_eq!(state.focus, expected);
        }
        state.handle_key(key(KeyCode::BackTab)).unwrap();
        assert_eq!(state.focus, FocusPane::Projects);
        state.handle_key(key(KeyCode::Char('l'))).unwrap();
        assert_eq!(state.focus, FocusPane::Workspaces);
        state.handle_key(key(KeyCode::Char('h'))).unwrap();
        assert_eq!(state.focus, FocusPane::Projects);
    }
}
