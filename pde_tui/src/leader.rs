//! Space-leader key tree (which-key) and the status line, styled like the Neovim setup.
use ratatui::{Frame, layout::Rect};
use rustline::{Palette, Rustline, Segment, Separators};
use whichkey::{Colors, Entry, Keymap, WhichKey};

use crate::{
    app::{App, Mode},
    features::workspace::WorkspaceState,
};

pub fn which_key() -> WhichKey<&'static str> {
    WhichKey::new(Keymap::new(vec![
        Entry::action('?', "Help", "help").also('h'),
        Entry::action('q', "Quit", "quit"),
        Entry::action('o', "Open", "open"),
        Entry::action('a', "Add", "add"),
        Entry::action('e', "Edit project", "edit"),
        Entry::action('b', "Branches", "branches"),
        Entry::action('d', "Delete", "delete"),
        Entry::action('r', "Refresh", "refresh"),
        Entry::action('u', "Update", "update"),
        Entry::action('v', "Details", "details"),
        Entry::group(
            'w',
            "Window",
            vec![
                Entry::action('h', "Focus left", "focus_left"),
                Entry::action('l', "Focus right", "focus_right"),
                Entry::action('k', "Focus up", "focus_up"),
                Entry::action('j', "Focus down", "focus_down"),
            ],
        ),
    ]))
}

pub fn key_for(action: &str) -> Option<(char, bool)> {
    // (key, alt) pairs fed back through the normal key handler.
    Some(match action {
        "open" => ('o', false),
        "add" => ('a', false),
        "edit" => ('e', false),
        "branches" => ('b', false),
        "delete" => ('d', false),
        "refresh" => ('r', false),
        "update" => ('u', false),
        "details" => ('v', false),
        "focus_left" => ('h', true),
        "focus_right" => ('l', true),
        "focus_up" => ('k', true),
        "focus_down" => ('j', true),
        _ => return None,
    })
}

pub fn draw_which_key(frame: &mut Frame<'_>, app: &App) {
    let p = app.theme.palette;
    app.which_key.draw(
        frame,
        frame.area(),
        1,
        "Space",
        Colors {
            base: p.base,
            border: p.blue,
            title: p.lavender,
            key: p.yellow,
            group: p.blue,
            text: p.text,
            subtle: p.subtle,
        },
    );
}

pub fn draw_status(frame: &mut Frame<'_>, area: Rect, app: &App) {
    let p = app.theme.palette;
    let mode_label = match &app.mode {
        Mode::Workspace => "NORMAL",
        Mode::CreateProject(state) => state.status_label(),
        Mode::Worktree(state) => state.status_label(),
    };
    let (label, accent) = if app.show_help {
        ("HELP", p.yellow)
    } else if app.pending_command.is_some() {
        ("CONFIRM", p.red)
    } else if app.details.open {
        ("DETAILS", p.pink)
    } else {
        match mode_label {
            "INSERT" => ("INSERT", p.green),
            "CONFIRM" => ("CONFIRM", p.red),
            _ => ("NORMAL", p.blue),
        }
    };
    let context = match &app.mode {
        Mode::Workspace => app.workspace.focus_title(),
        Mode::CreateProject(state) => state.title(),
        Mode::Worktree(_) => "Worktree",
    };
    let project = app
        .root()
        .file_name()
        .map(|name| name.to_string_lossy().into_owned())
        .unwrap_or_default();
    let message = app.message.trim();
    let (center, center_color) = if let Some((prompt, _)) = &app.pending_command {
        (prompt.clone(), p.yellow)
    } else if !matches!(app.mode, Mode::Workspace) {
        // Forms show their own message and shortcuts inside the panel.
        (String::new(), p.subtle)
    } else if app.details.open {
        (
            "[1-5/h/l] cards • [j/k] scroll • [g/G] top/bottom • [Esc/v] close".to_string(),
            p.subtle,
        )
    } else if app.which_key.is_open() {
        (app.which_key.summary(), p.subtle)
    } else if message.is_empty() || message == WorkspaceState::help() {
        (app.workspace.shortcuts().to_string(), p.subtle)
    } else {
        (message.to_string(), p.text)
    };
    let mut line = Rustline::new(Palette { base: p.base, text: p.text }, Separators::Powerline)
        .left(Segment::new(label, p.base, accent).required().max_width(12));
    // A confirmation names its target and choices, so it gets the whole bar.
    if app.pending_command.is_none() {
        line = line
            .left(Segment::new(project, p.base, p.pink).max_width(24).min_width(3))
            .left(Segment::new(context, p.text, p.surface0).min_bar_width(80));
    }
    line.right(
            Segment::new(format!("v{}", env!("CARGO_PKG_VERSION")), p.base, p.blue)
                .required()
                .bold(false),
        )
        .center(center, center_color)
        .draw(frame, area);
}
