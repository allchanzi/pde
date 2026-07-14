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
    Capabilities,
    Layout,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct CreateProjectSpec {
    pub name: String,
    pub path: String,
    pub base_branch: String,
    pub capabilities: Vec<String>,
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
enum CapabilityChoice {
    Rtui,
    Pantsui,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
enum NewPaneChoice {
    EmptyPane,
    EditorTab,
    IdeTab,
    GitTab,
    DockerTab,
    RtuiTab,
    PantsuiTab,
    K9sTab,
    MonitorTab,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
struct NewPanePickerState {
    selected: usize,
}

const NEW_PANE_CHOICES: [NewPaneChoice; 9] = [
    NewPaneChoice::EmptyPane,
    NewPaneChoice::EditorTab,
    NewPaneChoice::IdeTab,
    NewPaneChoice::GitTab,
    NewPaneChoice::DockerTab,
    NewPaneChoice::RtuiTab,
    NewPaneChoice::PantsuiTab,
    NewPaneChoice::K9sTab,
    NewPaneChoice::MonitorTab,
];

#[derive(Debug)]
pub struct CreateProjectState {
    field: Field,
    name: String,
    path: String,
    base_branch: String,
    enable_rtui: bool,
    enable_pantsui: bool,
    selected_capability: CapabilityChoice,
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

fn default_capabilities_enabled() -> bool {
    if let Ok(value) = env::var("ENABLE_PANTS") {
        return matches!(value.trim(), "1" | "true" | "TRUE" | "yes" | "YES");
    }

    let home = env::var("HOME").unwrap_or_else(|_| ".".into());
    let prefs_paths = [
        format!("{home}/.config/pde/prefs"),
        format!("{home}/.config/config/prefs"),
        format!("{home}/.config/shell/prefs"),
    ];

    for path in prefs_paths {
        let Ok(contents) = fs::read_to_string(path) else {
            continue;
        };
        for line in contents.lines() {
            let trimmed = line.trim();
            if trimmed.is_empty() || trimmed.starts_with('#') {
                continue;
            }
            let Some((key, value)) = trimmed.split_once('=') else {
                continue;
            };
            if key.trim() != "ENABLE_PANTS" {
                continue;
            }
            let value = value.trim().trim_matches('\'').trim_matches('"');
            return matches!(value, "1" | "true" | "TRUE" | "yes" | "YES");
        }
    }

    false
}
