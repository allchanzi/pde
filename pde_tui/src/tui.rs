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
    widgets::{Clear, Paragraph},
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
    execute!(
        stdout,
        EnterAlternateScreen,
        crossterm::event::EnableMouseCapture
    )
    .context("failed to enter alternate screen")?;
    Terminal::new(CrosstermBackend::new(stdout)).context("failed to create terminal")
}

fn restore_terminal(terminal: &mut AppTerminal) -> Result<()> {
    disable_raw_mode().context("failed to disable raw mode")?;
    execute!(
        terminal.backend_mut(),
        crossterm::event::DisableMouseCapture,
        LeaveAlternateScreen
    )
    .context("failed to leave alternate screen")?;
    terminal.show_cursor().context("failed to show cursor")
}

fn event_loop(terminal: &mut AppTerminal, mut app: App) -> Result<()> {
    let mut selection = tuikit::TextSelection::default();
    loop {
        if let Some(message) = app.workspace.poll_background() {
            app.message = message;
        }
        terminal.draw(|frame| {
            render(frame, &mut app);
            selection.capture(frame.buffer_mut(), app.text_area.get());
            selection.paint(
                frame,
                ratatui::style::Style::new().add_modifier(ratatui::style::Modifier::REVERSED),
            );
        })?;
        if let Some(effect) = next_effect(&mut app, &mut selection)? {
            match effect {
                Effect::Quit => return Ok(()),
                Effect::Suspend(command) => run_suspended(terminal, &mut app, &command)?,
                Effect::None
                | Effect::Message(_)
                | Effect::ToggleHelp
                | Effect::ConfirmCommand { .. }
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
    app.refresh_after_external_command(status.success())?;
    if !status.success() {
        app.message = format!("Command exited with status: {status}");
    }
    Ok(())
}

fn next_effect(app: &mut App, selection: &mut tuikit::TextSelection) -> Result<Option<Effect>> {
    let timeout = if app.workspace.background_pending() {
        16
    } else {
        250
    };
    if !event::poll(Duration::from_millis(timeout))? {
        return Ok(None);
    }

    let event = event::read()?;
    if selection.event(&event) {
        return Ok(None);
    }
    let Event::Key(key) = event else {
        return Ok(None);
    };

    // Nothing is visible below the minimum size, so only quitting is safe.
    let (width, height) = crossterm::terminal::size()?;
    if !tuikit::fits(width, height) && key.code != crossterm::event::KeyCode::Char('q') {
        return Ok(None);
    }
    (key.kind == KeyEventKind::Press)
        .then(|| app.handle_key(key))
        .transpose()
}

fn render(frame: &mut ratatui::Frame<'_>, app: &mut App) {
    app.text_area.set(ratatui::layout::Rect::default());
    if tuikit::too_small(frame, frame.area()) {
        return;
    }
    let [main, footer] = Layout::default()
        .direction(Direction::Vertical)
        .constraints([Constraint::Min(3), Constraint::Length(1)])
        .areas(frame.area());

    match &mut app.mode {
        Mode::CreateProject(state) => {
            let area = centered_rect(94, 94, main);
            app.text_area.set(create_project::render(
                frame,
                area,
                state,
                &app.theme,
                !app.show_help,
                &app.message,
            ));
        }
        Mode::Worktree(state) => {
            let area = centered_rect(80, 80, main);
            app.text_area.set(worktree::render(
                frame,
                area,
                state,
                &app.theme,
                !app.show_help,
            ));
        }
        Mode::Workspace => app.text_area.set(workspace::render(
            frame,
            main,
            &mut app.workspace,
            &app.theme,
        )),
    }
    crate::leader::draw_status(frame, footer, app);
    crate::leader::draw_which_key(frame, app);
    if app.which_key.is_open() || app.pending_command.is_some() {
        app.text_area.set(ratatui::layout::Rect::default());
    }

    if app.details.open {
        render_details(frame, app, main);
    }
    if app.show_help {
        render_help_popup(frame, main, app);
        app.text_area.set(app.help_popup.text_area.get());
    }
}

fn render_details(frame: &mut ratatui::Frame<'_>, app: &mut App, content: ratatui::layout::Rect) {
    let area = centered_rect(90, 90, content);
    let block = app.theme.panel_block(" Details [v/q/Esc] close ", true);
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
    app.text_area.set(body);
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

fn render_help_popup(frame: &mut ratatui::Frame<'_>, area: ratatui::layout::Rect, app: &App) {
    let lines = if app.details.open {
        vec![
            app.theme
                .shortcut_line("[1–5/h/l] cards • [j/k] scroll • [gg/G] top/bottom"),
            app.theme
                .shortcut_line("[Esc/v/q] close • [Tab/Shift+Tab] focus • [?] help"),
        ]
    } else {
        match &app.mode {
            Mode::Workspace => app.workspace.active_help_lines(&app.theme),
            Mode::CreateProject(state) => state.active_help_lines(&app.theme),
            Mode::Worktree(state) => state.help(&app.theme),
        }
    };
    app.help_popup
        .render(frame, area, " [?] Help ", lines, app.theme.help_title());
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
        terminal
            .draw(|frame| {
                render(frame, app);
            })
            .unwrap();
        terminal
            .backend()
            .buffer()
            .content
            .iter()
            .map(|cell| cell.symbol())
            .collect()
    }
    #[test]
    fn forms_keep_the_status_line_with_their_real_mode() {
        let mut app = App::fixture();
        app.mode = Mode::CreateProject(create_project::CreateProjectState::new());
        let form = screen(&mut app, 100, 30);
        assert!(form.contains("INSERT"), "{form}");
        assert!(form.contains("Create project"), "{form}");
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

    #[test]
    fn below_the_minimum_size_only_the_notice_is_drawn() {
        let mut app = App::fixture();
        let small = screen(&mut app, 30, 8);
        assert!(small.contains("Enlarge terminal"), "{small}");
        assert!(!small.contains("Global"), "{small}");
        let normal = screen(&mut app, 40, 10);
        assert!(!normal.contains("Enlarge terminal"), "{normal}");
    }

    #[test]
    fn help_scrolls_to_its_real_end_on_a_small_terminal() {
        let mut app = App::fixture();
        app.show_help = true;
        let top = screen(&mut app, 60, 12);
        assert!(top.contains("scroll") && !top.contains("[q]uit"), "{top}");
        app.handle_key(crossterm::event::KeyEvent::new(
            crossterm::event::KeyCode::Char('G'),
            crossterm::event::KeyModifiers::NONE,
        ))
        .unwrap();
        assert!(screen(&mut app, 60, 12).contains("[q]uit"));
    }
}
