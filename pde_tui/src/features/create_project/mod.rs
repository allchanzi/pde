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
    widgets::{Block, Borders, Clear, List, ListItem, ListState, Paragraph, Wrap},
};

use crate::{
    app::Effect,
    shared::{selection::PickerSearch, ui::theme::UiTheme},
};

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
    FullDevWorkflow,
    EditorTab,
    IdeTab,
    GitTab,
    DockerTab,
    RtuiTab,
    PantsuiTab,
    K9sTab,
    MonitorTab,
}

#[derive(Debug, Clone, Default)]
struct NewPanePickerState {
    selected: usize,
    search: PickerSearch,
}

const NEW_PANE_CHOICES: [NewPaneChoice; 11] = [
    NewPaneChoice::EmptyPane,
    NewPaneChoice::FullDevelopment,
    NewPaneChoice::FullDevWorkflow,
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
    fn tmux_layout_targets_pane_ids_not_numbers() {
        let mut grid = command_tab("grid", "a");
        grid.rows[0].panes.push(LayoutPane {
            ratio: 1,
            command: "b".into(),
        });
        grid.rows.push(grid.rows[0].clone());
        let script = tmux_layout(&[command_tab("one", "x"), ide_tab(), grid]).join("\n");
        // Numbers would break when the user's base-index or pane-base-index is 0.
        assert!(!script.contains("\"$session\":1"), "{script}");
        assert!(!script.contains("\"$session\":2"), "{script}");
        assert_eq!(
            script.matches("tmux send-keys -t \"$pane\"").count(),
            1 + 2 + 4
        );
        assert_eq!(script.matches("split-window").count(), 2 + 3);
        assert!(script.contains("tmux select-window -t \"$first\""));
    }

    #[test]
    fn preset_search_works_in_create_and_edit_without_firing_shortcut_letters() {
        for edit_slug in [None, Some("existing-project".to_string())] {
            let mut state = CreateProjectState::new();
            state.edit_slug = edit_slug;
            state.available_full_development = true;
            state.field = Field::Layout;
            let original = state.layout.clone();
            let press = |state: &mut CreateProjectState, code| {
                state
                    .handle_key(KeyEvent::new(code, crossterm::event::KeyModifiers::NONE))
                    .unwrap()
            };
            press(&mut state, KeyCode::Char('o'));
            press(&mut state, KeyCode::Char('/'));
            assert_eq!(state.status_label(), "SEARCH");
            for character in "full-development".chars() {
                assert_eq!(press(&mut state, KeyCode::Char(character)), Effect::None);
                assert_eq!(state.layout, original);
                assert!(state.new_pane_picker.is_some());
            }
            assert_eq!(press(&mut state, KeyCode::Enter), Effect::None);
            assert_eq!(state.status_label(), "NORMAL");
            assert_eq!(state.layout, original);
            let index = state.new_pane_picker.as_ref().unwrap().selected;
            assert_eq!(
                state.available_presets()[index],
                NewPaneChoice::FullDevelopment
            );
            press(&mut state, KeyCode::Enter);
            assert!(state.new_pane_picker.is_none());
            assert_eq!(state.layout, full_development_layout());
        }
    }

    #[test]
    fn preset_search_esc_keeps_the_picker_open_and_descriptions_are_searchable() {
        let mut state = CreateProjectState::new();
        state.available_full_development = true;
        state.field = Field::Layout;
        state.open_new_pane_picker();
        for character in "/jq? /".chars() {
            assert_eq!(
                state.handle_new_pane_picker_key(KeyCode::Char(character)),
                Effect::None
            );
        }
        assert_eq!(
            state.new_pane_picker.as_ref().unwrap().search.input(),
            Some("jq? /")
        );
        assert_eq!(state.handle_new_pane_picker_key(KeyCode::Esc), Effect::None);
        assert!(state.new_pane_picker.is_some());
        for character in "/10 development".chars() {
            state.handle_new_pane_picker_key(KeyCode::Char(character));
        }
        state.handle_new_pane_picker_key(KeyCode::Enter);
        let index = state.new_pane_picker.as_ref().unwrap().selected;
        assert_eq!(
            state.available_presets()[index],
            NewPaneChoice::FullDevelopment
        );
        state.handle_new_pane_picker_key(KeyCode::Esc);
        assert!(state.new_pane_picker.is_none());
        assert_eq!(state.field, Field::Layout);
        assert_eq!(state.layout.len(), 1);
    }

    #[test]
    fn preset_picker_scrolls_to_search_results_and_displays_no_match_feedback() {
        let mut state = CreateProjectState::new();
        state.field = Field::Layout;
        state.available_pantsui = true;
        state.open_new_pane_picker();
        for character in "/pants".chars() {
            state.handle_new_pane_picker_key(KeyCode::Char(character));
        }
        state.handle_new_pane_picker_key(KeyCode::Enter);
        let theme = UiTheme::load(Path::new("/nonexistent-theme"));
        let mut terminal =
            ratatui::Terminal::new(ratatui::backend::TestBackend::new(70, 16)).unwrap();
        terminal
            .draw(|frame| {
                render(frame, frame.area(), &state, &theme, true, "");
            })
            .unwrap();
        let text = terminal
            .backend()
            .buffer()
            .content
            .iter()
            .map(|cell| cell.symbol())
            .collect::<String>();
        assert!(text.contains("PantsUI tab"), "{text}");
        assert!(text.contains("/pants"), "{text}");
        assert!(text.contains("[/] search"), "{text}");
        let selected = state.new_pane_picker.as_ref().unwrap().selected;
        for character in "/missing-preset".chars() {
            state.handle_new_pane_picker_key(KeyCode::Char(character));
        }
        state.handle_new_pane_picker_key(KeyCode::Enter);
        terminal
            .draw(|frame| {
                render(frame, frame.area(), &state, &theme, true, "");
            })
            .unwrap();
        let text = terminal
            .backend()
            .buffer()
            .content
            .iter()
            .map(|cell| cell.symbol())
            .collect::<String>();
        assert!(text.contains("No match for \"missing-preset\""), "{text}");
        assert_eq!(state.new_pane_picker.as_ref().unwrap().selected, selected);
    }

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
                    ("lazygit", "lazygit"),
                    ("rtui", "rtui ."),
                    ("lazydocker", "lazydocker"),
                    ("sentui", "sentui"),
                    ("ntui", "ntui"),
                    ("pantsui", "pantsui"),
                ]
            );
            assert_ne!(state.draft(), state.baseline);
            press(&mut state, KeyCode::Char('o'));
            press(&mut state, KeyCode::Char('f'));
            assert_eq!(state.layout, spec.layout);
        }
    }

    #[test]
    fn workflow_layout_is_opt_in_and_available_in_create_and_edit() {
        for edit in [None, Some("project".into())] {
            let mut state = CreateProjectState::new();
            state.edit_slug = edit;
            state.available_full_development = true;
            state.field = Field::Layout;
            state.open_new_pane_picker();
            state.handle_new_pane_picker_key(KeyCode::Char('w'));
            assert_eq!(state.layout, full_dev_workflow_layout());
            let commands: Vec<_> = state
                .layout
                .iter()
                .map(|tab| tab.rows[0].panes[0].command.as_str())
                .collect();
            assert_eq!(commands[0], "pde workflow");
            assert_eq!(commands[1], "pde workflow editor");
            assert_eq!(commands[2], "pde workflow agent");
            assert_eq!(commands[5], "pde workflow api");
            assert_eq!(
                full_development_layout()[2].rows[0].panes[0].command,
                "fleetui"
            );
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
