use std::{path::Path, process::Command};

use anyhow::{Context, Result};
#[derive(Debug, Clone, PartialEq, Eq)]
pub enum ExternalCommand {
    PdeUpdate(Vec<String>),
    Projects(Vec<String>),
    Program { program: String, args: Vec<String> },
}

impl ExternalCommand {
    pub fn script_path<'a>(&'a self, root: &'a Path) -> std::path::PathBuf {
        match self {
            Self::PdeUpdate(_) => root.join("bin/pde-update"),
            Self::Projects(_) => root.join("bin/core/pde/projects"),
            Self::Program { program, .. } => program.into(),
        }
    }

    pub fn args(&self) -> &[String] {
        match self {
            Self::PdeUpdate(args) | Self::Projects(args) | Self::Program { args, .. } => args,
        }
    }
}

pub fn run(root: &Path, command: &ExternalCommand) -> Result<std::process::ExitStatus> {
    let script = command.script_path(root);
    Command::new(&script)
        .args(command.args())
        .status()
        .with_context(|| format!("failed to run {}", script.display()))
}
