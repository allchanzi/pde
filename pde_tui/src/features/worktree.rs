use crate::{
    app::Effect,
    shared::{process::ExternalCommand, ui::theme::UiTheme},
};
use anyhow::{Result, bail};
use crossterm::event::{KeyCode, KeyEvent};
use ratatui::{
    layout::{Constraint, Direction, Layout, Rect},
    text::Line,
    widgets::{Block, Borders, Clear, List, ListItem, ListState, Paragraph, Wrap},
};
use std::{collections::BTreeSet, path::PathBuf, process::Command};

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
enum Step {
    Branch,
    Name,
    Confirm,
}

#[derive(Debug)]
pub struct WorktreeState {
    slug: String,
    path: PathBuf,
    branches: Vec<String>,
    selection: ListState,
    new: bool,
    step: Step,
    name: String,
    message: String,
    pending_g: bool,
}

impl WorktreeState {
    pub fn load(slug: String, path: String, base: Option<String>, new: bool) -> Result<Self> {
        let output = Command::new("git")
            .args([
                "for-each-ref",
                "--format=%(refname)",
                "refs/heads",
                "refs/remotes/origin",
            ])
            .current_dir(&path)
            .output()?;
        if !output.status.success() {
            bail!(
                "Cannot list branches: {}",
                String::from_utf8_lossy(&output.stderr)
            );
        }
        let branches = parse_branches(&String::from_utf8_lossy(&output.stdout));
        if branches.is_empty() {
            bail!("No branches found. Create an initial commit first.");
        }
        let selected = base
            .and_then(|base| branches.iter().position(|item| item == &base))
            .unwrap_or(0);
        Ok(Self {
            slug,
            path: path.into(),
            branches,
            selection: ListState::default().with_selected(Some(selected)),
            new,
            step: Step::Branch,
            name: String::new(),
            message: String::new(),
            pending_g: false,
        })
    }

    fn branch(&self) -> &str {
        &self.branches[self.selection.selected().unwrap_or(0)]
    }
    fn open(&self) -> Effect {
        let mut args = vec!["open".into(), self.slug.clone(), "-b".into()];
        if self.new {
            args.extend([
                self.name.trim().into(),
                "--from".into(),
                self.branch().into(),
            ]);
        } else {
            args.push(self.branch().into());
        }
        Effect::Suspend(ExternalCommand::Projects(args))
    }

    pub fn handle_key(&mut self, key: KeyEvent) -> Result<Effect> {
        if self.step == Step::Branch && self.pending_g {
            self.pending_g = false;
            if key.code == KeyCode::Char('g') {
                self.selection.select(Some(0));
                return Ok(Effect::None);
            }
        }
        if key.code == KeyCode::Char('?') {
            return Ok(Effect::ToggleHelp);
        }
        Ok(match self.step {
            Step::Branch => match key.code {
                KeyCode::Esc => Effect::CloseCreateProject,
                KeyCode::Down | KeyCode::Char('j') => {
                    let index =
                        (self.selection.selected().unwrap_or(0) + 1).min(self.branches.len() - 1);
                    self.selection.select(Some(index));
                    Effect::None
                }
                KeyCode::Up | KeyCode::Char('k') => {
                    self.selection.select(Some(
                        self.selection.selected().unwrap_or(0).saturating_sub(1),
                    ));
                    Effect::None
                }
                KeyCode::Home => {
                    self.selection.select(Some(0));
                    Effect::None
                }
                KeyCode::End => {
                    self.selection.select(Some(self.branches.len() - 1));
                    Effect::None
                }
                KeyCode::Char('g') => {
                    self.pending_g = true;
                    Effect::None
                }
                KeyCode::Char('G') => {
                    self.selection.select(Some(self.branches.len() - 1));
                    Effect::None
                }
                KeyCode::Enter if self.new => {
                    self.step = Step::Name;
                    Effect::None
                }
                KeyCode::Enter => self.open(),
                _ => Effect::None,
            },
            Step::Name => match key.code {
                KeyCode::Esc => {
                    self.step = Step::Branch;
                    self.message.clear();
                    Effect::None
                }
                KeyCode::Backspace => {
                    self.name.pop();
                    Effect::None
                }
                KeyCode::Char(c) => {
                    self.name.push(c);
                    self.message.clear();
                    Effect::None
                }
                KeyCode::Enter => {
                    let name = self.name.trim();
                    let valid = !name.is_empty()
                        && Command::new("git")
                            .args(["check-ref-format", "--branch", name])
                            .current_dir(&self.path)
                            .output()?
                            .status
                            .success();
                    if !valid {
                        self.message = "Enter a valid Git branch name.".into();
                    } else if self.branches.iter().any(|branch| branch == name) {
                        self.message = "Branch already exists. Choose a new name or open it from the branch picker.".into();
                    } else {
                        self.step = Step::Confirm;
                        self.message.clear();
                    }
                    Effect::None
                }
                _ => Effect::None,
            },
            Step::Confirm => match key.code {
                KeyCode::Char('y' | 'Y') => self.open(),
                KeyCode::Char('n' | 'N') | KeyCode::Esc => {
                    self.step = Step::Name;
                    Effect::None
                }
                _ => Effect::None,
            },
        })
    }

    fn shortcuts(&self) -> &'static str {
        match self.step {
            Step::Branch => {
                "[↑/↓] / [j/k] select • [gg/G] first/last • [Enter] continue • [Esc] cancel • [?] help"
            }
            Step::Name => "Type branch name • [Enter] review • [Esc] back • [?] help",
            Step::Confirm => "Create and open worktree? [y]es / [n]o • [?] help",
        }
    }

    pub fn help(&self, theme: &UiTheme) -> Vec<Line<'static>> {
        vec![
            theme.shortcut_line(self.shortcuts()),
            theme.shortcut_line("Source branch is the starting point for the new branch."),
            theme.shortcut_line("The new worktree opens in the project's configured multiplexer."),
        ]
    }
}

pub fn render(
    frame: &mut ratatui::Frame<'_>,
    area: Rect,
    state: &mut WorktreeState,
    theme: &UiTheme,
    cursor: bool,
) {
    frame.render_widget(Clear, area);
    let [content, footer] = Layout::default()
        .direction(Direction::Vertical)
        .constraints([Constraint::Min(3), Constraint::Length(5)])
        .areas(area);
    let title = format!(
        " {} / {} ",
        state.slug,
        if state.new {
            "New worktree"
        } else {
            "Open branch"
        }
    );
    let block = Block::default()
        .borders(Borders::ALL)
        .title(title)
        .border_style(theme.focused_border());
    if state.step == Step::Branch {
        let items = state
            .branches
            .iter()
            .map(|branch| ListItem::new(branch.clone()))
            .collect::<Vec<_>>();
        let title = if state.new {
            " Select source branch "
        } else {
            " Select branch to open "
        };
        frame.render_stateful_widget(
            List::new(items)
                .block(block.title(title))
                .highlight_style(theme.selected())
                .highlight_symbol("> "),
            content,
            &mut state.selection,
        );
    } else {
        let lines = vec![
            Line::from(format!("Source branch: {}", state.branch())),
            Line::from(""),
            Line::from("New branch name:"),
            Line::from(state.name.clone()),
            Line::from(""),
            theme.shortcut_line(if state.step == Step::Confirm {
                "Review the source and name, then confirm below."
            } else {
                "A separate working directory will be created for this branch."
            }),
        ];
        let inner = block.inner(content);
        frame.render_widget(
            Paragraph::new(lines)
                .block(block)
                .wrap(Wrap { trim: false }),
            content,
        );
        if cursor && state.step == Step::Name && inner.height > 3 && inner.width > 0 {
            frame.set_cursor_position((
                inner.x + (state.name.chars().count() as u16).min(inner.width - 1),
                inner.y + 3,
            ));
        }
    }
    frame.render_widget(
        Paragraph::new(vec![
            theme.shortcut_line(&state.message),
            theme.shortcut_line(state.shortcuts()),
        ])
        .block(
            Block::default()
                .borders(Borders::ALL)
                .title(" Worktree / shortcuts ")
                .border_style(theme.focused_border()),
        )
        .wrap(Wrap { trim: true }),
        footer,
    );
}

fn parse_branches(raw: &str) -> Vec<String> {
    raw.lines()
        .filter_map(|line| {
            line.strip_prefix("refs/heads/").or_else(|| {
                line.strip_prefix("refs/remotes/origin/")
                    .filter(|branch| *branch != "HEAD")
            })
        })
        .map(str::to_string)
        .collect::<BTreeSet<_>>()
        .into_iter()
        .collect()
}

#[cfg(test)]
mod tests {
    use super::*;
    use crossterm::event::KeyModifiers;
    #[test]
    fn branches_merge_local_and_origin_without_head() {
        assert_eq!(
            parse_branches(
                "refs/heads/main\nrefs/remotes/origin/main\nrefs/remotes/origin/HEAD\nrefs/remotes/origin/feature/x\n"
            ),
            vec!["feature/x", "main"]
        );
    }
    #[test]
    fn confirmation_uses_source_and_new_name_and_can_go_back() {
        let mut state = WorktreeState {
            slug: "project".into(),
            path: ".".into(),
            branches: vec!["main".into()],
            selection: ListState::default().with_selected(Some(0)),
            new: true,
            step: Step::Confirm,
            name: "feature/new".into(),
            message: String::new(),
            pending_g: false,
        };
        assert_eq!(
            state
                .handle_key(KeyEvent::new(KeyCode::Char('y'), KeyModifiers::NONE))
                .unwrap(),
            Effect::Suspend(ExternalCommand::Projects(vec![
                "open".into(),
                "project".into(),
                "-b".into(),
                "feature/new".into(),
                "--from".into(),
                "main".into()
            ]))
        );
        state
            .handle_key(KeyEvent::new(KeyCode::Char('n'), KeyModifiers::NONE))
            .unwrap();
        assert_eq!(state.step, Step::Name);
    }
    #[test]
    fn popup_keeps_name_source_and_shortcuts_inside_terminal() {
        let mut state = WorktreeState {
            slug: "project".into(),
            path: ".".into(),
            branches: vec!["main".into()],
            selection: ListState::default().with_selected(Some(0)),
            new: true,
            step: Step::Name,
            name: "feature/new".into(),
            message: String::new(),
            pending_g: false,
        };
        let mut terminal =
            ratatui::Terminal::new(ratatui::backend::TestBackend::new(100, 30)).unwrap();
        let theme = UiTheme::load(std::path::Path::new("/nonexistent-theme"));
        terminal
            .draw(|frame| render(frame, frame.area(), &mut state, &theme, true))
            .unwrap();
        let buffer = terminal.backend().buffer();
        let text = buffer
            .content
            .iter()
            .map(|cell| cell.symbol())
            .collect::<String>();
        assert!(text.contains("Source branch: main"));
        assert!(text.contains("feature/new"));
        assert!(text.contains("[Enter] review"));
        assert!(text.contains("Worktree / shortcuts"));
    }
    #[test]
    fn vim_first_last_require_two_lowercase_g_presses() {
        let mut state = WorktreeState {
            slug: "project".into(),
            path: ".".into(),
            branches: vec!["a".into(), "b".into(), "c".into()],
            selection: ListState::default().with_selected(Some(1)),
            new: true,
            step: Step::Branch,
            name: String::new(),
            message: String::new(),
            pending_g: false,
        };
        let key = |c| KeyEvent::new(KeyCode::Char(c), KeyModifiers::NONE);
        state.handle_key(key('g')).unwrap();
        assert_eq!(state.selection.selected(), Some(1));
        state.handle_key(key('g')).unwrap();
        assert_eq!(state.selection.selected(), Some(0));
        state.handle_key(key('G')).unwrap();
        assert_eq!(state.selection.selected(), Some(2));
        state.handle_key(key('g')).unwrap();
        state.handle_key(key('k')).unwrap();
        state.handle_key(key('g')).unwrap();
        assert_eq!(state.selection.selected(), Some(1));
    }
}
