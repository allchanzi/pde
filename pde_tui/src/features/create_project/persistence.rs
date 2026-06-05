pub fn create_project(root: &Path, spec: &CreateProjectSpec) -> Result<String> {
    let slug = slugify(&spec.name);
    let args = vec![
        "register".into(),
        spec.name.clone(),
        spec.path.clone(),
        "--slug".into(),
        slug.clone(),
        "--base-branch".into(),
        spec.base_branch.clone(),
        "--layout-variant".into(),
        "custom".into(),
    ];
    let output = Command::new(root.join("bin/core/pde/projects"))
        .args(args)
        .output()
        .context("failed to register project")?;
    if !output.status.success() {
        bail!(
            "project registration failed: {}",
            String::from_utf8_lossy(&output.stderr)
        );
    }
    write_custom_layouts(&slug, &spec.layout)?;
    Ok(slug)
}

fn field_line(label: &'static str, value: &str, active: bool, theme: &UiTheme) -> Line<'static> {
    let prefix = if active { "> " } else { "  " };
    Line::from(vec![
        Span::styled(
            format!("{prefix}{label:<12}"),
            if active {
                theme.help_title()
            } else {
                theme.title()
            },
        ),
        Span::raw(value.to_string()),
    ])
}

fn default_path(name: &str) -> String {
    let base = env::var("PDE_PROJECTS_DIR").unwrap_or_else(|_| {
        format!(
            "{}/projects",
            env::var("HOME").unwrap_or_else(|_| ".".into())
        )
    });
    format!("{}/{}", base, slugify(name))
}

fn slugify(value: &str) -> String {
    let slug = value
        .trim()
        .to_lowercase()
        .chars()
        .map(|c| if c.is_ascii_alphanumeric() { c } else { '-' })
        .collect::<String>()
        .split('-')
        .filter(|part| !part.is_empty())
        .collect::<Vec<_>>()
        .join("-");
    if slug.is_empty() {
        "project".into()
    } else {
        slug
    }
}

fn adjust_ratio(value: &mut u16, delta: i16) {
    *value = ((*value as i16 + delta).max(1).min(99)) as u16;
}

fn write_custom_layouts(slug: &str, tabs: &[LayoutTab]) -> Result<()> {
    write_zellij_layout(slug, tabs)?;
    write_tmux_layout(slug, tabs)?;
    Ok(())
}

fn write_zellij_layout(slug: &str, tabs: &[LayoutTab]) -> Result<()> {
    let path = home()
        .join(".config/zellij/layouts")
        .join(format!("{slug}.kdl"));
    fs::create_dir_all(path.parent().unwrap())?;
    let mut lines = vec![
        "layout {".to_string(),
        "    default_tab_template {".into(),
        "        pane size=1 borderless=true {".into(),
        "            plugin location=\"tab-bar\"".into(),
        "        }".into(),
        "        children".into(),
        "        pane size=2 borderless=true {".into(),
        "            plugin location=\"status-bar\"".into(),
        "        }".into(),
        "    }".into(),
        "".into(),
    ];
    for (idx, tab) in tabs.iter().enumerate() {
        lines.push(format!(
            "    tab name=\"{}\"{} {{",
            escape_kdl(&tab.name),
            if idx == 0 { " focus=true" } else { "" }
        ));
        if tab.preset == Some(LayoutPreset::Ide) {
            lines.extend(zellij_ide_tab(tab));
        } else if tab.rows.len() > 1 {
            lines.push("        pane split_direction=\"horizontal\" {".into());
            let row_percentages = percentages(tab.rows.iter().map(|row| row.ratio));
            for (row, row_percentage) in tab.rows.iter().zip(row_percentages) {
                lines.extend(zellij_row(row, row_percentage, 12));
            }
            lines.push("        }".into());
        } else {
            lines.extend(zellij_row(&tab.rows[0], 100, 8));
        }
        lines.push("    }".into());
    }
    lines.push("}".into());
    fs::write(path, lines.join("\n") + "\n")?;
    Ok(())
}

fn zellij_ide_tab(tab: &LayoutTab) -> Vec<String> {
    let editor = tab
        .rows
        .first()
        .and_then(|row| row.panes.first())
        .map(|pane| pane.command.as_str())
        .unwrap_or("${EDITOR:-nvim} .");
    let ai = tab
        .rows
        .first()
        .and_then(|row| row.panes.get(1))
        .map(|pane| pane.command.as_str())
        .unwrap_or(ai_command());
    let terminal = tab
        .rows
        .get(1)
        .and_then(|row| row.panes.get(1))
        .map(|pane| pane.command.as_str())
        .unwrap_or("");
    let mut lines = vec![
        "        pane split_direction=\"vertical\" {".into(),
        "            pane command=\"zsh\" size=\"65%\" {".into(),
        format!(
            "                args \"-lc\" \"{}; exec \\\"$SHELL\\\" -l\"",
            escape_kdl(editor)
        ),
        "            }".into(),
        "            pane split_direction=\"horizontal\" size=\"35%\" {".into(),
        "                pane command=\"zsh\" size=\"60%\" {".into(),
        format!(
            "                    args \"-lc\" \"{}; exec \\\"$SHELL\\\" -l\"",
            escape_kdl(ai)
        ),
        "                }".into(),
    ];
    if terminal.trim().is_empty() {
        lines.push("                pane size=\"40%\"".into());
    } else {
        lines.extend([
            "                pane command=\"zsh\" size=\"40%\" {".into(),
            format!(
                "                    args \"-lc\" \"{}; exec \\\"$SHELL\\\" -l\"",
                escape_kdl(terminal)
            ),
            "                }".into(),
        ]);
    }
    lines.extend(["            }".into(), "        }".into()]);
    lines
}

fn zellij_row(row: &LayoutRow, row_percentage: u16, indent: usize) -> Vec<String> {
    let pad = " ".repeat(indent);
    if row.panes.len() > 1 {
        let mut lines = vec![format!(
            "{pad}pane split_direction=\"vertical\" size=\"{row_percentage}%\" {{"
        )];
        let pane_percentages = percentages(row.panes.iter().map(|pane| pane.ratio));
        for (pane, pane_percentage) in row.panes.iter().zip(pane_percentages) {
            lines.extend(zellij_pane(pane, pane_percentage, indent + 4));
        }
        lines.push(format!("{pad}}}"));
        lines
    } else {
        zellij_pane(&row.panes[0], row_percentage, indent)
    }
}

fn zellij_pane(pane: &LayoutPane, percentage: u16, indent: usize) -> Vec<String> {
    let pad = " ".repeat(indent);
    if pane.command.is_empty() {
        return vec![format!("{pad}pane size=\"{percentage}%\"")];
    }
    vec![
        format!("{pad}pane command=\"zsh\" size=\"{percentage}%\" {{"),
        format!(
            "{pad}    args \"-lc\" \"{}; exec \\\"$SHELL\\\" -l\"",
            escape_kdl(&pane.command)
        ),
        format!("{pad}}}"),
    ]
}

fn write_tmux_layout(slug: &str, tabs: &[LayoutTab]) -> Result<()> {
    let path = home().join(".config/tmux").join(format!("{slug}.sh"));
    fs::create_dir_all(path.parent().unwrap())?;
    let mut lines = vec![
        "setup_tmux_layout() {".to_string(),
        "  local session=\"$1\"".into(),
        "  local project_dir=\"$2\"".into(),
    ];
    for (idx, tab) in tabs.iter().enumerate() {
        let window = idx + 1;
        if idx == 0 {
            lines.push(format!(
                "  tmux new-session -d -s \"$session\" -n {} -c \"$project_dir\"",
                shell_quote(&tab.name)
            ));
        } else {
            lines.push(format!(
                "  tmux new-window -t \"$session\":{window} -n {} -c \"$project_dir\"",
                shell_quote(&tab.name)
            ));
        }
        if tab.preset == Some(LayoutPreset::Ide) {
            lines.extend(tmux_ide_tab(tab, window));
            continue;
        }
        let mut pane_index = 1usize;
        for (row_idx, row) in tab.rows.iter().enumerate() {
            if row_idx > 0 {
                lines.push(format!(
                    "  tmux split-window -v -t \"$session\":{window} -c \"$project_dir\""
                ));
                pane_index += 1;
            }
            for (col_idx, pane) in row.panes.iter().enumerate() {
                if col_idx > 0 {
                    lines.push(format!(
                        "  tmux split-window -h -t \"$session\":{window}.{} -c \"$project_dir\"",
                        pane_index
                    ));
                    pane_index += 1;
                }
                if !pane.command.is_empty() {
                    lines.push(format!(
                        "  tmux send-keys -t \"$session\":{window}.{} {} C-m",
                        pane_index,
                        shell_quote(&pane.command)
                    ));
                }
            }
        }
        lines.push(format!(
            "  tmux select-layout -t \"$session\":{window} tiled >/dev/null 2>&1 || true"
        ));
    }
    lines.extend(["  tmux select-window -t \"$session\":1".into(), "}".into()]);
    fs::write(path, lines.join("\n") + "\n")?;
    Ok(())
}

fn tmux_ide_tab(tab: &LayoutTab, window: usize) -> Vec<String> {
    let editor = tab
        .rows
        .first()
        .and_then(|row| row.panes.first())
        .map(|pane| pane.command.as_str())
        .unwrap_or("${EDITOR:-nvim} .");
    let ai = tab
        .rows
        .first()
        .and_then(|row| row.panes.get(1))
        .map(|pane| pane.command.as_str())
        .unwrap_or(ai_command());
    let terminal = tab
        .rows
        .get(1)
        .and_then(|row| row.panes.get(1))
        .map(|pane| pane.command.as_str())
        .unwrap_or("");
    let mut lines = vec![
        format!(
            "  tmux send-keys -t \"$session\":{window}.1 {} C-m",
            shell_quote(editor)
        ),
        format!("  tmux split-window -h -p 35 -t \"$session\":{window}.1 -c \"$project_dir\""),
        format!(
            "  tmux send-keys -t \"$session\":{window}.2 {} C-m",
            shell_quote(ai)
        ),
        format!("  tmux split-window -v -p 40 -t \"$session\":{window}.2 -c \"$project_dir\""),
    ];
    if !terminal.trim().is_empty() {
        lines.push(format!(
            "  tmux send-keys -t \"$session\":{window}.3 {} C-m",
            shell_quote(terminal)
        ));
    }
    lines
}

fn escape_kdl(value: &str) -> String {
    value.replace('\\', "\\\\").replace('"', "\\\"")
}
fn shell_quote(value: &str) -> String {
    format!("'{}'", value.replace('\'', "'\\''"))
}
fn home() -> PathBuf {
    env::var_os("HOME")
        .map(PathBuf::from)
        .unwrap_or_else(|| PathBuf::from("."))
}
