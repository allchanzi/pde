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
    text::{Line, Span},
    widgets::{Block, Borders, Clear, Paragraph, Wrap},
};

use crate::{
    app::{App, Effect, Mode},
    features::{create_project, workspace},
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
                Effect::Exec(command) => return process::exec(app.root(), &command),
                Effect::Suspend(command) => run_suspended(terminal, &mut app, &command)?,
                Effect::None
                | Effect::Message(_)
                | Effect::ToggleHelp
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
    let [main, footer] = Layout::default()
        .direction(Direction::Vertical)
        .constraints([Constraint::Min(3), Constraint::Length(4)])
        .areas(frame.area());

    workspace::render(frame, main, &mut app.workspace, &app.theme);

    if let Mode::CreateProject(state) = &app.mode {
        let area = centered_rect(74, 70, frame.area());
        create_project::render(frame, area, state, &app.theme);
    }

    frame.render_widget(
        Paragraph::new(footer_lines(app))
            .block(
                Block::default()
                    .borders(Borders::ALL)
                    .title(format!("Status / shortcuts • theme: {}", app.theme.name)),
            )
            .wrap(Wrap { trim: true }),
        footer,
    );

    if app.show_help {
        render_help_popup(frame, app);
    }
}

fn footer_lines(app: &App) -> Vec<Line<'static>> {
    let shortcuts = match &app.mode {
        Mode::Workspace => workspace::WorkspaceState::help().to_string(),
        Mode::CreateProject(state) => state.footer_help().to_string(),
    };

    let message = app.message.trim();
    if message.is_empty() || message == shortcuts {
        return vec![Line::from(shortcuts)];
    }

    vec![
        Line::from(message.to_string()),
        Line::from(Span::styled(shortcuts, app.theme.muted())),
    ]
}

fn render_help_popup(frame: &mut ratatui::Frame<'_>, app: &App) {
    let area = centered_rect(62, 62, frame.area());
    let block = Block::default()
        .borders(Borders::ALL)
        .title(" Help (?) ")
        .border_style(app.theme.help_title());
    let lines = match &app.mode {
        Mode::Workspace => app.workspace.active_help_lines(&app.theme),
        Mode::CreateProject(state) => state.active_help_lines(&app.theme),
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
