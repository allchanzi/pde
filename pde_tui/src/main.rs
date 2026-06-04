mod app;
mod cli;
mod features;
mod shared;
mod tui;

use anyhow::Result;
use clap::Parser;

use crate::{app::App, cli::Args, shared::root::resolve_root};

fn main() -> Result<()> {
    let args = Args::parse();
    let root = args.root.unwrap_or(resolve_root()?);
    tui::run(App::new(root)?)
}
