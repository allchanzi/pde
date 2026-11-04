use std::{
    io::{self, Stdout},
    time::Duration,
};

use anyhow::{Context, Result};
use crossterm::{
    event::{self, Event, KeyEventKind},
    execute,
    terminal::{EnterAlternateScreen, LeaveAlternateScreen, disable_raw_mode, enable_raw_mode},
};
use ratatui::{
    Terminal,
    backend::CrosstermBackend,
    layout::{Constraint, Direction, Layout},
    text::Line,
    widgets::{Block, Borders, Clear, Paragraph, Wrap},
};

use crate::{
    app::{App, Effect, Mode},
    features::{create_project, workspace, worktree},
    shared::process,
};

type Backend = CrosstermBackend<Stdout>;
type AppTerminal = Terminal<Backend>;

pub fn run(app: App) -> Result<()> {
    let mut terminal = init_terminal()?;
    let result = event_loop(&mut terminal, app);
    restore_terminal(&mut terminal)?;
    result
}

fn init_terminal() -> Result<AppTerminal> {
    enable_raw_mode().context("failed to enable raw mode")?;
    let mut stdout = io::stdout();
    execute!(stdout, EnterAlternateScreen).context("failed to enter alternate screen")?;
    Terminal::new(CrosstermBackend::new(stdout)).context("failed to create terminal")
}

fn restore_terminal(terminal: &mut AppTerminal) -> Result<()> {
    disable_raw_mode().context("failed to disable raw mode")?;
    execute!(terminal.backend_mut(), LeaveAlternateScreen)
        .context("failed to leave alternate screen")?;
    terminal.show_cursor().context("failed to show cursor")
}

fn event_loop(terminal: &mut AppTerminal, mut app: App) -> Result<()> {
    loop {
        terminal.draw(|frame| render(frame, &mut app))?;
        if let Some(effect) = next_effect(&mut app)? {
            match effect {
                Effect::Quit => return Ok(()),
                Effect::Suspend(command) => run_suspended(terminal, &mut app, &command)?,
                Effect::None
                | Effect::Message(_)
                | Effect::ToggleHelp
                | Effect::OpenWorktree { .. }
                | Effect::OpenEditProject(_)
                | Effect::OpenCreateProject
                | Effect::CloseCreateProject
                | Effect::CreateProjectSubmit(_) => {}
            }
        }
    }
}

fn run_suspended(
    terminal: &mut AppTerminal,
    app: &mut App,
    command: &crate::shared::process::ExternalCommand,
) -> Result<()> {
    restore_terminal(terminal)?;
    let status = process::run(app.root(), command)?;
    *terminal = init_terminal()?;
    app.refresh_after_external_command()?;
    if !status.success() {
        app.message = format!("Command exited with status: {status}");
    }
    Ok(())
}

fn next_effect(app: &mut App) -> Result<Option<Effect>> {
    if !event::poll(Duration::from_millis(250))? {
        return Ok(None);
    }

    let Event::Key(key) = event::read()? else {
        return Ok(None);
    };

    (key.kind == KeyEventKind::Press)
        .then(|| app.handle_key(key))
        .transpose()
}

fn render(frame: &mut ratatui::Frame<'_>, app: &mut App) {
    if let Mode::CreateProject(state) = &app.mode {
        let area = centered_rect(94, 94, frame.area());
        create_project::render(frame, area, state, &app.theme, !app.show_help, &app.message);
        if app.show_help {
            render_help_popup(frame, app);
        }
        return;
    }

    if let Mode::Worktree(state) = &mut app.mode {
        let area = centered_rect(80, 80, frame.area());
        worktree::render(frame, area, state, &app.theme, !app.show_help);
        if app.show_help {
            render_help_popup(frame, app);
        }
        return;
    }
    let [main, footer] = Layout::default()
        .direction(Direction::Vertical)
        .constraints([Constraint::Min(3), Constraint::Length(1)])
        .areas(frame.area());

    workspace::render(frame, main, &mut app.workspace, &app.theme);
    crate::leader::draw_status(frame, footer, app);
    crate::leader::draw_which_key(frame, app);

    if app.details.open {
        render_details(frame, app, main);
    }
    if app.show_help {
        render_help_popup(frame, app);
    }
}

fn render_details(frame: &mut ratatui::Frame<'_>, app: &mut App, content: ratatui::layout::Rect) {
    let area = centered_rect(90, 90, content);
    let block = app.theme.panel_block(" Details [v/Esc] close ", true);
    let inner = block.inner(area);
    frame.render_widget(Clear, area);
    frame.render_widget(block, area);
    let [tabs, body] = Layout::vertical([Constraint::Length(1), Constraint::Min(0)]).areas(inner);
    frame.render_widget(
        ratatui::widgets::Tabs::new([
            "1 Project",
            "2 Workspaces",
            "3 Global sessions",
            "4 Project sessions",
            "5 Status",
        ])
        .select(app.details.tab)
        .highlight_style(app.theme.selected()),
        tabs,
    );
    let mut lines = app.workspace.details(app.details.tab);
    if app.details.tab == 4 {
        lines.extend([
            format!("Theme: {}", app.theme.name),
            format!("Version: {}", env!("CARGO_PKG_VERSION")),
            format!("Status: {}", app.message),
        ]);
    }
    if lines.is_empty() {
        lines.push("No entries.".into());
    }
    app.details_max_scroll = lines.len().saturating_sub(body.height as usize);
    app.details.scroll = app.details.scroll.min(app.details_max_scroll);
    frame.render_widget(
        Paragraph::new(
            lines
                .into_iter()
                .skip(app.details.scroll)
                .map(Line::from)
                .collect::<Vec<_>>(),
        ),
        body,
    );
}

fn render_help_popup(frame: &mut ratatui::Frame<'_>, app: &App) {
    let area = centered_rect(62, 62, frame.area());
    let block = Block::default()
        .borders(Borders::ALL)
        .title(" [?] Help ")
        .border_style(app.theme.help_title());
    let lines = if app.details.open {
        vec![
            app.theme
                .shortcut_line("[1–5/h/l] cards • [j/k] scroll • [g/G] top/bottom"),
            app.theme
                .shortcut_line("[Esc/v] close • [Tab/Shift+Tab] focus • [?] help"),
        ]
    } else {
        match &app.mode {
            Mode::Workspace => app.workspace.active_help_lines(&app.theme),
            Mode::CreateProject(state) => state.active_help_lines(&app.theme),
            Mode::Worktree(state) => state.help(&app.theme),
        }
    };
    let help = Paragraph::new(lines).block(block).wrap(Wrap { trim: true });

    frame.render_widget(Clear, area);
    frame.render_widget(help, area);
}

fn centered_rect(
    percent_x: u16,
    percent_y: u16,
    area: ratatui::layout::Rect,
) -> ratatui::layout::Rect {
    let [_, vertical, _] = Layout::default()
        .direction(Direction::Vertical)
        .constraints([
            Constraint::Percentage((100 - percent_y) / 2),
            Constraint::Percentage(percent_y),
            Constraint::Percentage((100 - percent_y) / 2),
        ])
        .areas(area);

    let [_, horizontal, _] = Layout::default()
        .direction(Direction::Horizontal)
        .constraints([
            Constraint::Percentage((100 - percent_x) / 2),
            Constraint::Percentage(percent_x),
            Constraint::Percentage((100 - percent_x) / 2),
        ])
        .areas(vertical);

    horizontal
}

#[cfg(test)]
mod tests {
    use super::*;
    use ratatui::backend::TestBackend;
    fn screen(app: &mut App, width: u16, height: u16) -> String {
        let mut terminal = Terminal::new(TestBackend::new(width, height)).unwrap();
        terminal.draw(|frame| render(frame, app)).unwrap();
        terminal
            .backend()
            .buffer()
            .content
            .iter()
            .map(|cell| cell.symbol())
            .collect()
    }
    #[test]
    fn details_scroll_reaches_real_bottom_and_clamps_after_resize() {
        let mut app = App::fixture();
        app.details.open = true;
        app.details.tab = 2;
        let first = screen(&mut app, 100, 25);
        assert!(first.contains("session-0"));
        assert!(app.details_max_scroll > 0);
        app.details
            .key(crossterm::event::KeyCode::Char('G'), app.details_max_scroll);
        let last = screen(&mut app, 100, 25);
        assert!(last.contains("session-59"));
        screen(&mut app, 100, 100);
        assert_eq!(app.details.scroll, 0);
        for (width, height) in [(1, 1), (8, 3), (20, 8)] {
            screen(&mut app, width, height);
        }
    }
}
