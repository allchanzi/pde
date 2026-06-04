use std::{io, path::Path, process::Command};

use anyhow::{Context, Result};
use crossterm::{
    execute,
    terminal::{LeaveAlternateScreen, disable_raw_mode},
};

#[derive(Debug, Clone, PartialEq, Eq)]
pub enum ExternalCommand {
    CorePdeWorktree(Vec<String>),
    Projects(Vec<String>),
    Program { program: String, args: Vec<String> },
}

impl ExternalCommand {
    pub fn script_path<'a>(&'a self, root: &'a Path) -> std::path::PathBuf {
        match self {
            Self::CorePdeWorktree(_) => root.join("bin/core/pde/pde-worktree"),
            Self::Projects(_) => root.join("bin/core/pde/projects"),
            Self::Program { program, .. } => program.into(),
        }
    }

    pub fn args(&self) -> &[String] {
        match self {
            Self::CorePdeWorktree(args) | Self::Projects(args) | Self::Program { args, .. } => args,
        }
    }
}

pub fn exec(root: &Path, command: &ExternalCommand) -> Result<()> {
    disable_raw_mode().ok();
    execute!(io::stdout(), LeaveAlternateScreen).ok();

    let script = command.script_path(root);
    let status = Command::new(&script)
        .args(command.args())
        .status()
        .with_context(|| format!("failed to run {}", script.display()))?;
    std::process::exit(status.code().unwrap_or(1));
}

pub fn run(root: &Path, command: &ExternalCommand) -> Result<std::process::ExitStatus> {
    let script = command.script_path(root);
    Command::new(&script)
        .args(command.args())
        .status()
        .with_context(|| format!("failed to run {}", script.display()))
}
