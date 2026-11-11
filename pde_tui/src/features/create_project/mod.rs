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
    ConfirmDiscard,
}

/// The user-editable values, compared with the opening state to detect unsaved work.
#[derive(Debug, Clone, Default, PartialEq, Eq)]
struct FormDraft {
    name: String,
    path: String,
    base_branch: String,
    selected_multiplexer: usize,
    enable_rtui: bool,
    enable_pantsui: bool,
    layout: Vec<LayoutTab>,
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
    FullDevelopment,
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

const NEW_PANE_CHOICES: [NewPaneChoice; 10] = [
    NewPaneChoice::EmptyPane,
    NewPaneChoice::FullDevelopment,
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
    available_full_development: bool,
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
    baseline: FormDraft,
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
    fn editing_visits_layout_before_review_and_preserves_other_capabilities() {
        let mut state = CreateProjectState::new();
        state.edit_slug = Some("original-slug".into());
        state.name = "Renamed".into();
        state.multiplexers = vec!["tmux".into()];
        state.extra_capabilities = vec!["requests".into()];
        state.field = Field::Capabilities;
        state.next_field();
        assert_eq!(state.confirm, ConfirmState::Editing);
        assert_eq!(state.field, Field::Layout);
        state.next_field();
        assert_eq!(state.confirm, ConfirmState::ConfirmCreate);
        state.handle_confirm_key(KeyCode::Char('n'));
        assert_eq!(state.confirm, ConfirmState::Editing);
        let Effect::CreateProjectSubmit(spec) = state.handle_confirm_key(KeyCode::Char('y')) else {
            panic!("expected submission")
        };
        assert_eq!(spec.edit_slug.as_deref(), Some("original-slug"));
        assert!(spec.capabilities.contains(&"requests".to_string()));
    }

    #[test]
    fn question_mark_is_text_in_text_fields_and_help_elsewhere() {
        let mut state = CreateProjectState::new();
        let press = |state: &mut CreateProjectState, code| {
            state
                .handle_key(KeyEvent::new(code, crossterm::event::KeyModifiers::NONE))
                .unwrap()
        };
        assert_eq!(press(&mut state, KeyCode::Char('?')), Effect::None);
        assert_eq!(state.name, "?");
        state.field = Field::Capabilities;
        assert_eq!(press(&mut state, KeyCode::Char('?')), Effect::ToggleHelp);
    }

    #[test]
    fn esc_closes_a_clean_form_and_asks_before_discarding_changes() {
        let mut state = CreateProjectState::new();
        let press = |state: &mut CreateProjectState, code| {
            state
                .handle_key(KeyEvent::new(code, crossterm::event::KeyModifiers::NONE))
                .unwrap()
        };
        assert_eq!(press(&mut state, KeyCode::Esc), Effect::CloseCreateProject);
        press(&mut state, KeyCode::Char('x'));
        assert_eq!(press(&mut state, KeyCode::Esc), Effect::None);
        assert_eq!(state.status_label(), "CONFIRM");
        assert_eq!(press(&mut state, KeyCode::Char('n')), Effect::None);
        assert_eq!(state.name, "x");
        assert_eq!(state.status_label(), "INSERT");
        press(&mut state, KeyCode::Esc);
        assert_eq!(press(&mut state, KeyCode::Esc), Effect::None);
        assert_eq!(state.confirm, ConfirmState::Editing);
        press(&mut state, KeyCode::Esc);
        assert_eq!(
            press(&mut state, KeyCode::Char('y')),
            Effect::CloseCreateProject
        );
    }

    #[test]
    fn full_development_replaces_layout_when_creating_and_editing() {
        for edit_slug in [None, Some("existing-project".to_string())] {
            let mut state = CreateProjectState::new();
            state.edit_slug = edit_slug.clone();
            state.available_full_development = true;
            state.multiplexers = vec!["tmux".into()];
            state.field = Field::Layout;
            state.add_preset_tab(ide_tab());
            let press = |state: &mut CreateProjectState, code| {
                state
                    .handle_key(KeyEvent::new(code, crossterm::event::KeyModifiers::NONE))
                    .unwrap()
            };
            press(&mut state, KeyCode::Char('o'));
            press(&mut state, KeyCode::Char('f'));
            assert!(state.new_pane_picker.is_none());
            assert_eq!(
                (state.selected_tab, state.selected_row, state.selected_pane),
                (0, 0, 0)
            );
            let Effect::CreateProjectSubmit(spec) = state.submit() else {
                panic!("expected submission")
            };
            assert_eq!(spec.edit_slug, edit_slug);
            let tabs: Vec<_> = spec
                .layout
                .iter()
                .map(|tab| {
                    assert_eq!(tab.rows.len(), 1);
                    assert_eq!(tab.rows[0].panes.len(), 1);
                    (tab.name.as_str(), tab.rows[0].panes[0].command.as_str())
                })
                .collect();
            assert_eq!(
                tabs,
                [
                    ("terminal", ""),
                    ("nvim", "nvim ."),
                    ("fleetui", "fleetui"),
                    ("gtui", "gtui"),
                    ("rtui", "rtui ."),
                    ("pantsui", "pantsui"),
                    ("lazydocker", "lazydocker"),
                ]
            );
            assert_ne!(state.draft(), state.baseline);
            press(&mut state, KeyCode::Char('o'));
            press(&mut state, KeyCode::Char('f'));
            assert_eq!(state.layout, spec.layout);
        }
    }

    #[test]
    fn full_development_requires_all_tools() {
        let mut state = CreateProjectState::new();
        state.available_full_development = false;
        let layout = state.layout.clone();
        state.open_new_pane_picker();
        assert!(
            !state
                .available_presets()
                .contains(&NewPaneChoice::FullDevelopment)
        );
        assert!(matches!(
            state.handle_new_pane_picker_key(KeyCode::Char('f')),
            Effect::Message(_)
        ));
        assert_eq!(state.layout, layout);
        assert!(state.new_pane_picker.is_some());
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
