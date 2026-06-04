use std::path::PathBuf;

use anyhow::Result;
use crossterm::event::KeyEvent;

use crate::{
    features::{
        create_project::{self, CreateProjectSpec, CreateProjectState},
        workspace::WorkspaceState,
    },
    shared::{process::ExternalCommand, ui::theme::UiTheme},
};

#[derive(Debug, Clone, PartialEq, Eq)]
pub enum Effect {
    None,
    Quit,
    Message(String),
    ToggleHelp,
    Exec(ExternalCommand),
    Suspend(ExternalCommand),
    OpenCreateProject,
    CloseCreateProject,
    CreateProjectSubmit(CreateProjectSpec),
}

#[derive(Debug)]
pub enum Mode {
    Workspace,
    CreateProject(CreateProjectState),
}

pub struct App {
    pub mode: Mode,
    pub workspace: WorkspaceState,
    pub theme: UiTheme,
    pub message: String,
    pub show_help: bool,
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
        })
    }

    pub fn handle_key(&mut self, key: KeyEvent) -> Result<Effect> {
        let effect = match &mut self.mode {
            Mode::Workspace => self.workspace.handle_key(key)?,
            Mode::CreateProject(state) => state.handle_key(key)?,
        };
        self.apply_local_effect(effect)
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
            Effect::OpenCreateProject => {
                self.mode = Mode::CreateProject(CreateProjectState::new());
                self.message = "Create project: fill fields, Enter/Tab to continue".into();
                Effect::None
            }
            Effect::CloseCreateProject => {
                self.mode = Mode::Workspace;
                self.message = WorkspaceState::help().into();
                Effect::None
            }
            Effect::CreateProjectSubmit(spec) => {
                let slug = create_project::create_project(self.root(), &spec)?;
                self.workspace.refresh_from_external()?;
                self.mode = Mode::Workspace;
                self.message = format!("Created project: {slug}");
                Effect::None
            }
            passthrough => passthrough,
        })
    }
}
