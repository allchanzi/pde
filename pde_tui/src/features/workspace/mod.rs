use std::{env, fs, path::Path, path::PathBuf, process::Command};

use anyhow::{Context, Result};
use crossterm::event::{KeyCode, KeyEvent, KeyModifiers};
use ratatui::{
    layout::Rect,
    text::{Line, Span},
    widgets::{List, ListItem, ListState, Paragraph, Wrap},
};
use serde::Deserialize;
use tuikit::{Nav, NavKeys, NavStep, next_match, smart_contains};

use crate::{
    app::Effect,
    shared::{process::ExternalCommand, root::home_dir, selection, ui::theme::UiTheme},
};

const HELP: &str = "[?] help • [j/k] select • [h/l/1-4] focus • [gg/G] first/last • [Ctrl+u/d] half page • [Ctrl+b/f] full page • [Enter/o] open or attach • [/] search • [a]dd • [b]ranch • [e]dit • [d]elete • [r]efresh • [u]pdate • [q]uit";

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
    nav: NavKeys,
    search_input: Option<String>,
    search_query: String,
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
            nav: NavKeys::default(),
            search_input: None,
            search_query: String::new(),
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
        assert_eq!(state.global_session_list.selected(), Some(59));
        assert!(state.nav_pending());
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
    fn alt_is_left_to_the_multiplexer_and_ctrl_moves_focus() {
        let mut state = WorkspaceState::fixture();
        state.focus = FocusPane::Projects;
        state
            .handle_key(KeyEvent::new(KeyCode::Char('l'), KeyModifiers::ALT))
            .unwrap();
        assert_eq!(state.focus, FocusPane::Projects);
        state
            .handle_key(KeyEvent::new(KeyCode::Char('l'), KeyModifiers::CONTROL))
            .unwrap();
        assert_eq!(state.focus, FocusPane::Workspaces);
        state
            .handle_key(KeyEvent::new(KeyCode::Char('j'), KeyModifiers::CONTROL))
            .unwrap();
        assert_eq!(state.focus, FocusPane::ProjectSessions);
    }

    #[test]
    fn brackets_no_longer_page() {
        let mut state = WorkspaceState::fixture();
        state.handle_key(key(KeyCode::Char(']'))).unwrap();
        assert_eq!(state.global_session_list.selected(), Some(0));
    }

    #[test]
    fn search_jumps_with_smartcase_and_repeats() {
        let mut state = WorkspaceState::fixture();
        let type_query = |state: &mut WorkspaceState, text: &str| {
            state.handle_key(key(KeyCode::Char('/'))).unwrap();
            for character in text.chars() {
                state.handle_key(key(KeyCode::Char(character))).unwrap();
            }
            state.handle_key(key(KeyCode::Enter)).unwrap()
        };
        assert_eq!(type_query(&mut state, "session 42"), Effect::None);
        assert_eq!(state.global_session_list.selected(), Some(42));
        assert_eq!(
            type_query(&mut state, "SESSION"),
            Effect::Message("No match for \"SESSION\"".into())
        );
        type_query(&mut state, "session 5");
        assert_eq!(state.global_session_list.selected(), Some(50));
        state.handle_key(key(KeyCode::Char('n'))).unwrap();
        assert_eq!(state.global_session_list.selected(), Some(51));
        state.handle_key(key(KeyCode::Char('N'))).unwrap();
        assert_eq!(state.global_session_list.selected(), Some(50));
    }

    #[test]
    fn typing_a_search_never_triggers_shortcuts() {
        let mut state = WorkspaceState::fixture();
        state.handle_key(key(KeyCode::Char('/'))).unwrap();
        for character in "dq?".chars() {
            assert_eq!(state.handle_key(key(KeyCode::Char(character))).unwrap(), Effect::None);
        }
        assert_eq!(state.search_input(), Some("dq?"));
        state.handle_key(key(KeyCode::Esc)).unwrap();
        assert_eq!(state.search_input(), None);
        assert_eq!(state.global_session_list.selected(), Some(0));
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
