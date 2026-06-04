fn editor_tab() -> LayoutTab {
    command_tab("editor", "${EDITOR:-nvim} .")
}

fn ide_tab() -> LayoutTab {
    LayoutTab {
        name: "ide".into(),
        preset: Some(LayoutPreset::Ide),
        rows: vec![
            LayoutRow {
                ratio: 3,
                panes: vec![
                    LayoutPane {
                        ratio: 2,
                        command: "${EDITOR:-nvim} .".into(),
                    },
                    LayoutPane {
                        ratio: 1,
                        command: ai_command().into(),
                    },
                ],
            },
            LayoutRow {
                ratio: 2,
                panes: vec![
                    LayoutPane {
                        ratio: 2,
                        command: String::new(),
                    },
                    LayoutPane {
                        ratio: 1,
                        command: String::new(),
                    },
                ],
            },
        ],
    }
}

fn monitor_tab() -> LayoutTab {
    LayoutTab {
        name: "monitor".into(),
        preset: None,
        rows: vec![
            LayoutRow {
                ratio: 1,
                panes: vec![LayoutPane {
                    ratio: 1,
                    command: "if command -v network-ports >/dev/null 2>&1; then network-ports; else lsof -nP -iTCP; fi".into(),
                }],
            },
            LayoutRow {
                ratio: 1,
                panes: vec![LayoutPane {
                    ratio: 1,
                    command: "if command -v htop >/dev/null 2>&1; then htop; else top; fi".into(),
                }],
            },
        ],
    }
}

fn command_tab(name: &str, command: &str) -> LayoutTab {
    LayoutTab {
        name: name.into(),
        preset: None,
        rows: vec![LayoutRow {
            ratio: 1,
            panes: vec![LayoutPane {
                ratio: 1,
                command: command.into(),
            }],
        }],
    }
}

fn ai_command() -> &'static str {
    "eval \"${AI_COMMAND_1:-codex}\""
}

impl NewPaneChoice {
    fn key(self) -> &'static str {
        match self {
            Self::EmptyPane => "Space",
            Self::EditorTab => "e",
            Self::IdeTab => "i",
            Self::GitTab => "g",
            Self::DockerTab => "d",
            Self::K9sTab => "K",
            Self::MonitorTab => "m",
        }
    }

    fn label(self) -> &'static str {
        match self {
            Self::EmptyPane => "Empty pane",
            Self::EditorTab => "Editor tab",
            Self::IdeTab => "IDE tab",
            Self::GitTab => "Git tab",
            Self::DockerTab => "Docker tab",
            Self::K9sTab => "K9s tab",
            Self::MonitorTab => "Monitor tab",
        }
    }

    fn description(self) -> &'static str {
        match self {
            Self::EmptyPane => "Add an empty pane to the current row",
            Self::EditorTab => "New tab running ${EDITOR:-nvim} .",
            Self::IdeTab => "New tab: editor left, AI top-right, terminal bottom-right",
            Self::GitTab => "New tab running lazygit",
            Self::DockerTab => "New tab running lazydocker",
            Self::K9sTab => "New tab running k9s",
            Self::MonitorTab => "New tab with network monitor and htop/top",
        }
    }
}

impl ProjectType {
    fn label(self) -> &'static str {
        match self {
            Self::Code => "code",
            Self::Hardware => "hardware",
            Self::Notes => "notes",
        }
    }
    fn next(self) -> Self {
        match self {
            Self::Code => Self::Hardware,
            Self::Hardware => Self::Notes,
            Self::Notes => Self::Code,
        }
    }
}
