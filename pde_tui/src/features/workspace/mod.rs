use std::{env, fs, path::Path, path::PathBuf, process::Command};

use anyhow::{Context, Result};
use crossterm::event::{KeyCode, KeyEvent, KeyModifiers};
use ratatui::{
    layout::{Constraint, Direction, Layout, Rect},
    text::{Line, Span},
    widgets::{List, ListItem, ListState, Paragraph, Wrap},
};
use serde::Deserialize;

use crate::{
    app::Effect,
    shared::{process::ExternalCommand, root::home_dir, selection, ui::theme::UiTheme},
};

const HELP: &str = "? help • h/j/k/l focus+scroll • gg/G top/bottom • Ctrl+d/u page • o/Enter open/attach • a add • d delete/kill session • r refresh • q quit";

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
}

include!("lifecycle.rs");
include!("input.rs");
include!("selection.rs");
include!("actions.rs");
include!("accessors.rs");
include!("ui.rs");
include!("data.rs");
