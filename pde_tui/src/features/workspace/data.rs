fn active_project_sessions(detail: &ProjectInspect) -> Vec<SessionRow> {
    detail
        .rows
        .iter()
        .flat_map(|row| {
            [
                row.tmux_active.then(|| SessionRow {
                    backend: SessionBackend::Tmux,
                    label: row.label.clone(),
                    session: row.session_name.clone(),
                }),
                row.zellij_active.then(|| SessionRow {
                    backend: SessionBackend::Zellij,
                    label: row.label.clone(),
                    session: row.zellij_session_name.clone(),
                }),
            ]
            .into_iter()
            .flatten()
        })
        .collect()
}

fn load_global_sessions() -> Vec<SessionRow> {
    [
        list_sessions("tmux", &["list-sessions", "-F", "#S"], SessionBackend::Tmux),
        list_sessions(
            "zellij",
            &["list-sessions", "--short", "--no-formatting"],
            SessionBackend::Zellij,
        ),
    ]
    .into_iter()
    .flatten()
    .collect()
}

fn list_sessions(program: &str, args: &[&str], backend: SessionBackend) -> Vec<SessionRow> {
    Command::new(program)
        .args(args)
        .output()
        .ok()
        .filter(|output| output.status.success())
        .map(|output| String::from_utf8_lossy(&output.stdout).to_string())
        .unwrap_or_default()
        .lines()
        .map(str::trim)
        .filter(|line| !line.is_empty())
        .map(|session| SessionRow {
            backend,
            label: session.to_string(),
            session: session.to_string(),
        })
        .collect()
}

fn load_projects() -> Result<Vec<Project>> {
    registry_file()
        .filter(|path| path.exists())
        .map(read_registry)
        .transpose()
        .map(|projects| projects.unwrap_or_default())
}

fn read_registry(path: PathBuf) -> Result<Vec<Project>> {
    fs::read_to_string(&path)
        .with_context(|| format!("failed to read {}", path.display()))
        .and_then(|raw| {
            serde_json::from_str::<Registry>(&raw)
                .with_context(|| format!("failed to parse {}", path.display()))
        })
        .map(|registry| sorted_projects(registry.projects))
}

fn sorted_projects(mut projects: Vec<Project>) -> Vec<Project> {
    projects.sort_by_key(|project| project.name.to_lowercase());
    projects
}

fn registry_file() -> Option<PathBuf> {
    Some(
        env::var_os("PDE_PROJECTS_FILE")
            .map(PathBuf::from)
            .unwrap_or_else(|| home_dir().join(".config/pde/projects.json")),
    )
}

fn inspect_project(root: &Path, slug: &str) -> Result<ProjectInspect> {
    let output = Command::new(root.join("bin/core/pde/projects"))
        .args(["inspect", slug])
        .output()
        .with_context(|| format!("failed to inspect project {slug}"))?;

    if !output.status.success() {
        let stderr = String::from_utf8_lossy(&output.stderr);
        anyhow::bail!("failed to inspect project {slug}: {stderr}");
    }

    serde_json::from_slice(&output.stdout)
        .with_context(|| format!("invalid inspect JSON for {slug}"))
}
