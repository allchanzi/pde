use std::{env, path::PathBuf};

use anyhow::{Context, Result, anyhow};

pub fn resolve_root() -> Result<PathBuf> {
    env::var_os("PDE_ROOT")
        .map(PathBuf::from)
        .map(Ok)
        .unwrap_or_else(detect_root)
}

fn detect_root() -> Result<PathBuf> {
    env::current_dir()
        .context("failed to read current directory")?
        .ancestors()
        .find(|candidate| candidate.join("bin/core/pde/projects").exists())
        .map(PathBuf::from)
        .ok_or_else(|| anyhow!("could not detect PDE root; pass --root or set PDE_ROOT"))
}

pub fn home_dir() -> PathBuf {
    env::var_os("HOME")
        .map(PathBuf::from)
        .unwrap_or_else(|| PathBuf::from("."))
}
