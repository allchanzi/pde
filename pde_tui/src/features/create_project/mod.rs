use std::{
    env, fs,
    path::{Path, PathBuf},
    process::Command,
};

use anyhow::{Context, Result, bail};
use crossterm::event::{KeyCode, KeyEvent};
use ratatui::{
    layout::{Constraint, Direction, Layout, Position, Rect},
    text::{Line, Span},
    widgets::{Block, Borders, Clear, Paragraph, Wrap},
};

use crate::{app::Effect, shared::ui::theme::UiTheme};

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
enum Field {
    Name,
    Path,
    BaseBranch,
    Layout,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct CreateProjectSpec {
    pub name: String,
    pub path: String,
    pub base_branch: String,
    pub layout: Vec<LayoutTab>,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct LayoutTab {
    pub name: String,
    pub rows: Vec<LayoutRow>,
    preset: Option<LayoutPreset>,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
enum LayoutPreset {
    Ide,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct LayoutRow {
    pub ratio: u16,
    pub panes: Vec<LayoutPane>,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct LayoutPane {
    pub ratio: u16,
    pub command: String,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
enum ConfirmState {
    Editing,
    ConfirmCreate,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
enum LayoutEditMode {
    Navigate,
    EditCommand,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
enum NewPaneChoice {
    EmptyPane,
    EditorTab,
    IdeTab,
    GitTab,
    DockerTab,
    K9sTab,
    MonitorTab,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
struct NewPanePickerState {
    selected: usize,
}

const NEW_PANE_CHOICES: [NewPaneChoice; 7] = [
    NewPaneChoice::EmptyPane,
    NewPaneChoice::EditorTab,
    NewPaneChoice::IdeTab,
    NewPaneChoice::GitTab,
    NewPaneChoice::DockerTab,
    NewPaneChoice::K9sTab,
    NewPaneChoice::MonitorTab,
];

#[derive(Debug)]
pub struct CreateProjectState {
    field: Field,
    name: String,
    path: String,
    base_branch: String,
    layout: Vec<LayoutTab>,
    selected_tab: usize,
    selected_row: usize,
    selected_pane: usize,
    pending_n: bool,
    pending_delete: bool,
    new_pane_picker: Option<NewPanePickerState>,
    layout_mode: LayoutEditMode,
    confirm: ConfirmState,
}

include!("interaction.rs");
include!("help.rs");
include!("actions.rs");
include!("navigation.rs");
include!("presets.rs");
include!("ui.rs");
include!("persistence.rs");
