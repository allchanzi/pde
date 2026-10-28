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
    Multiplexer,
    Capabilities,
    Layout,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct CreateProjectSpec {
    pub edit_slug: Option<String>,
    pub name: String,
    pub path: String,
    pub base_branch: String,
    pub multiplexer: String,
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
    edit_slug: Option<String>,
    extra_capabilities: Vec<String>,
    field: Field,
    name: String,
    path: String,
    base_branch: String,
    multiplexers: Vec<String>,
    selected_multiplexer: usize,
    available_rtui: bool,
    available_pantsui: bool,
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

fn command_available(command: &str) -> bool {
    use std::os::unix::fs::PermissionsExt;
    env::var_os("PATH").is_some_and(|paths| {
        env::split_paths(&paths).any(|dir| {
            fs::metadata(dir.join(command))
                .is_ok_and(|meta| meta.is_file() && meta.permissions().mode() & 0o111 != 0)
        })
    })
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn multiplexer_choice_is_submitted_and_required() {
        let mut state = CreateProjectState::new();
        state.name = "Example".into();
        state.multiplexers = vec!["tmux".into(), "zellij".into()];
        state.field = Field::Multiplexer;
        state
            .handle_key(KeyEvent::new(
                KeyCode::Right,
                crossterm::event::KeyModifiers::NONE,
            ))
            .unwrap();
        let Effect::CreateProjectSubmit(spec) = state.submit() else {
            panic!("expected submit")
        };
        assert_eq!(spec.multiplexer, "zellij");
        state.multiplexers.clear();
        assert!(matches!(state.request_confirmation(), Effect::Message(_)));
        assert_eq!(state.confirm, ConfirmState::Editing);
    }

    #[test]
    fn editing_reviews_without_replacing_layout_and_preserves_other_capabilities() {
        let mut state = CreateProjectState::new();
        state.edit_slug = Some("original-slug".into());
        state.name = "Renamed".into();
        state.multiplexers = vec!["tmux".into()];
        state.extra_capabilities = vec!["requests".into()];
        state.field = Field::Capabilities;
        state.next_field();
        assert_eq!(state.confirm, ConfirmState::ConfirmCreate);
        assert_eq!(state.field, Field::Capabilities);
        state.handle_confirm_key(KeyCode::Char('n'));
        assert_eq!(state.confirm, ConfirmState::Editing);
        let Effect::CreateProjectSubmit(spec) = state.handle_confirm_key(KeyCode::Char('y')) else {
            panic!("expected submission")
        };
        assert_eq!(spec.edit_slug.as_deref(), Some("original-slug"));
        assert!(spec.capabilities.contains(&"requests".to_string()));
    }

    #[test]
    fn missing_capabilities_cannot_be_enabled_or_added_by_shortcut() {
        let mut state = CreateProjectState::new();
        state.available_rtui = false;
        state.available_pantsui = false;
        state.enable_rtui = false;
        state.enable_pantsui = false;
        state.toggle_capability(CapabilityChoice::Rtui);
        state.toggle_capability(CapabilityChoice::Pantsui);
        assert!(state.capabilities().is_empty());
        let tabs = state.layout.len();
        assert!(matches!(
            state.apply_new_pane_choice(NewPaneChoice::RtuiTab),
            Effect::Message(_)
        ));
        assert_eq!(state.layout.len(), tabs);
        assert!(!state.available_presets().contains(&NewPaneChoice::RtuiTab));
    }
}
