use std::path::PathBuf;

use anyhow::Result;
use crossterm::event::{KeyCode, KeyEvent, KeyEventKind, KeyModifiers};
use whichkey::{Outcome, WhichKey};

use crate::{
    features::{
        create_project::{self, CreateProjectSpec, CreateProjectState},
        workspace::WorkspaceState,
        worktree::WorktreeState,
    },
    shared::{
        process::ExternalCommand,
        ui::{details::Details, theme::UiTheme},
    },
};

#[derive(Debug, Clone, PartialEq, Eq)]
pub enum Effect {
    None,
    Quit,
    Message(String),
    ToggleHelp,
    Suspend(ExternalCommand),
    OpenWorktree {
        slug: String,
        path: String,
        base: Option<String>,
        new: bool,
    },
    OpenCreateProject,
    OpenEditProject(String),
    CloseCreateProject,
    CreateProjectSubmit(CreateProjectSpec),
}

#[derive(Debug)]
pub enum Mode {
    Workspace,
    CreateProject(CreateProjectState),
    Worktree(WorktreeState),
}

pub struct App {
    pub mode: Mode,
    pub workspace: WorkspaceState,
    pub theme: UiTheme,
    pub message: String,
    pub show_help: bool,
    pub details: Details,
    pub details_max_scroll: usize,
    pub which_key: WhichKey<&'static str>,
}

impl App {
    pub fn new(root: PathBuf) -> Result<Self> {
        let theme = UiTheme::load(&root);
        Ok(Self {
            mode: Mode::Workspace,
            workspace: WorkspaceState::load(root)?,
            theme,
            message: WorkspaceState::help().into(),
            show_help: false,
            details: Details::default(),
            details_max_scroll: 0,
            which_key: crate::leader::which_key(),
        })
    }

    pub fn handle_key(&mut self, key: KeyEvent) -> Result<Effect> {
        if key.kind == KeyEventKind::Release || matches!(key.code, KeyCode::Modifier(_)) {
            return Ok(Effect::None);
        }
        if self.show_help {
            if matches!(
                key.code,
                crossterm::event::KeyCode::Esc | crossterm::event::KeyCode::Char('?')
            ) {
                self.show_help = false;
            }
            return Ok(Effect::None);
        }
        if self.details.open {
            if key.code == KeyCode::Char('?') {
                self.show_help = true;
            } else if matches!(key.code, KeyCode::Tab | KeyCode::BackTab) {
                self.details.open = false;
                let effect = self.workspace.handle_key(key)?;
                return self.apply_local_effect(effect);
            } else {
                self.details.key(key.code, self.details_max_scroll);
            }
            return Ok(Effect::None);
        }
        if matches!(self.mode, Mode::Workspace) {
            if self.which_key.is_open() {
                return self.handle_leader_key(key);
            }
            if key.code == KeyCode::Char(' ') && key.modifiers.is_empty() {
                self.which_key.open();
                return Ok(Effect::None);
            }
        }
        if matches!(self.mode, Mode::Workspace)
            && key.code == KeyCode::Char('v')
            && key.modifiers.is_empty()
        {
            self.details.open = true;
            self.details.scroll = 0;
            return Ok(Effect::None);
        }
        let effect = match &mut self.mode {
            Mode::Workspace => self.workspace.handle_key(key)?,
            Mode::CreateProject(state) => state.handle_key(key)?,
            Mode::Worktree(state) => state.handle_key(key)?,
        };
        self.apply_local_effect(effect)
    }

    fn handle_leader_key(&mut self, key: KeyEvent) -> Result<Effect> {
        let outcome = match key.code {
            KeyCode::Backspace => self.which_key.back(),
            KeyCode::Char(character) => self.which_key.press(character),
            _ => {
                self.which_key.cancel();
                return Ok(Effect::None);
            }
        };
        match outcome {
            Outcome::Action("help") => self.apply_local_effect(Effect::ToggleHelp),
            Outcome::Action("quit") => Ok(Effect::Quit),
            Outcome::Action(action) => match crate::leader::key_for(action) {
                Some((character, alt)) => self.handle_key(KeyEvent::new(
                    KeyCode::Char(character),
                    if alt { KeyModifiers::ALT } else { KeyModifiers::NONE },
                )),
                None => Ok(Effect::None),
            },
            Outcome::Unknown => {
                self.message = "Unknown Space key".into();
                Ok(Effect::None)
            }
            Outcome::Pending | Outcome::Cancelled => Ok(Effect::None),
        }
    }

    pub fn root(&self) -> &std::path::Path {
        self.workspace.root()
    }

    pub fn refresh_after_external_command(&mut self) -> Result<()> {
        self.workspace.refresh_from_external()?;
        self.theme = UiTheme::load(self.root());
        self.message = "Returned to TUI and refreshed.".into();
        Ok(())
    }

    fn apply_local_effect(&mut self, effect: Effect) -> Result<Effect> {
        Ok(match effect {
            Effect::Message(message) => {
                self.message = message;
                Effect::None
            }
            Effect::ToggleHelp => {
                self.show_help = !self.show_help;
                Effect::None
            }
            Effect::OpenWorktree {
                slug,
                path,
                base,
                new,
            } => {
                match WorktreeState::load(slug, path, base, new) {
                    Ok(state) => self.mode = Mode::Worktree(state),
                    Err(error) => self.message = error.to_string(),
                }
                Effect::None
            }
            Effect::OpenEditProject(slug) => {
                match CreateProjectState::edit(self.root(), &slug) {
                    Ok(state) => {
                        self.mode = Mode::CreateProject(state);
                        self.message = "Edit project details and layout.".into();
                    }
                    Err(error) => self.message = error.to_string(),
                }
                Effect::None
            }
            Effect::OpenCreateProject => {
                self.mode = Mode::CreateProject(CreateProjectState::new());
                self.message = "Fill in project details.".into();
                Effect::None
            }
            Effect::CloseCreateProject => {
                self.mode = Mode::Workspace;
                self.message = WorkspaceState::help().into();
                Effect::None
            }
            Effect::CreateProjectSubmit(spec) => {
                let slug = match create_project::create_project(self.root(), &spec) {
                    Ok(slug) => slug,
                    Err(error) => {
                        self.message = error.to_string();
                        return Ok(Effect::None);
                    }
                };
                self.workspace.refresh_from_external()?;
                self.mode = Mode::Workspace;
                self.message = format!(
                    "{} project: {slug}",
                    if spec.edit_slug.is_some() {
                        "Updated"
                    } else {
                        "Created"
                    }
                );
                Effect::None
            }
            passthrough => passthrough,
        })
    }
}

#[cfg(test)]
impl App {
    pub(crate) fn fixture() -> Self {
        let workspace = WorkspaceState::fixture();
        Self {
            theme: UiTheme::load(workspace.root()),
            workspace,
            mode: Mode::Workspace,
            message: String::new(),
            show_help: false,
            details: Details::default(),
            details_max_scroll: 0,
            which_key: crate::leader::which_key(),
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crossterm::event::KeyModifiers;
    fn key(code: KeyCode) -> KeyEvent {
        KeyEvent::new(code, KeyModifiers::NONE)
    }

    #[test]
    fn details_are_modal_and_close_without_changing_form_input() {
        let mut app = App::fixture();
        app.handle_key(key(KeyCode::Char('v'))).unwrap();
        assert!(app.details.open);
        app.handle_key(key(KeyCode::Char('3'))).unwrap();
        assert_eq!(app.details.tab, 2);
        app.handle_key(key(KeyCode::Char('?'))).unwrap();
        assert!(app.show_help);
        app.handle_key(key(KeyCode::Esc)).unwrap();
        assert!(!app.show_help);
        assert!(app.details.open);
        app.handle_key(key(KeyCode::Esc)).unwrap();
        assert!(!app.details.open);
        app.mode = Mode::CreateProject(CreateProjectState::new());
        for c in ['v', 'i', 'a', 'j', 'k'] {
            app.handle_key(key(KeyCode::Char(c))).unwrap();
        }
        assert!(!app.details.open);
        assert!(matches!(app.mode, Mode::CreateProject(_)));
    }
}
