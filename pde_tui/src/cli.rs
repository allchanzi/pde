use std::path::PathBuf;

use clap::Parser;

#[derive(Parser, Debug)]
#[command(name = "pde-tui", version, about = "Terminal UI for PDE")]
pub struct Args {
    /// PDE repository root. Defaults to $PDE_ROOT or auto-detection.
    #[arg(long, env = "PDE_ROOT")]
    pub root: Option<PathBuf>,
}
