pub fn render(
    frame: &mut ratatui::Frame<'_>,
    area: Rect,
    state: &CreateProjectState,
    theme: &UiTheme,
    cursor_enabled: bool,
) {
    frame.render_widget(Clear, area);
    let columns = Layout::default()
        .direction(Direction::Horizontal)
        .constraints([Constraint::Percentage(44), Constraint::Percentage(56)])
        .split(area);

    let block = Block::default()
        .borders(Borders::ALL)
        .title(" Create project ")
        .border_style(theme.focused_border());
    let paragraph = Paragraph::new(state.lines(theme))
        .block(block)
        .wrap(Wrap { trim: false });
    frame.render_widget(paragraph, columns[0]);
    if cursor_enabled {
        render_text_field_cursor(frame, columns[0], state);
    }
    render_layout_preview(frame, columns[1], state, theme, cursor_enabled);
    if let Some(picker) = state.new_pane_picker {
        render_new_pane_picker(frame, area, picker, theme);
    }
}

fn render_text_field_cursor(
    frame: &mut ratatui::Frame<'_>,
    area: Rect,
    state: &CreateProjectState,
) {
    if state.confirm != ConfirmState::Editing
        || state.new_pane_picker.is_some()
        || state.layout_mode == LayoutEditMode::EditCommand
    {
        return;
    }

    let Some((row, value)) = text_field_cursor_row_and_value(state) else {
        return;
    };
    let inner = inner_rect(area);
    if inner.width == 0 || inner.height <= row {
        return;
    }

    let value_start = 14;
    let value_width = inner.width.saturating_sub(value_start).max(1);
    let value_len = value.chars().count() as u16;
    let cursor_offset = value_start + value_len.min(value_width.saturating_sub(1));
    frame.set_cursor_position(Position {
        x: inner.x + cursor_offset,
        y: inner.y + row,
    });
}

fn text_field_cursor_row_and_value(state: &CreateProjectState) -> Option<(u16, &str)> {
    match state.field {
        Field::Name => Some((2, state.name.as_str())),
        Field::Path => Some((3, state.path.as_str())),
        Field::BaseBranch => Some((4, state.base_branch.as_str())),
        Field::Layout => None,
    }
}

fn render_command_cursor(
    frame: &mut ratatui::Frame<'_>,
    area: Rect,
    state: &CreateProjectState,
    selected: bool,
    command: &str,
) {
    if !selected
        || state.field != Field::Layout
        || state.layout_mode != LayoutEditMode::EditCommand
        || state.confirm != ConfirmState::Editing
        || state.new_pane_picker.is_some()
    {
        return;
    }
    let inner = inner_rect(area);
    if inner.width == 0 || inner.height < 2 {
        return;
    }
    let command_len = command.chars().count() as u16;
    let cursor_offset = command_len.min(inner.width.saturating_sub(1));
    frame.set_cursor_position(Position {
        x: inner.x + cursor_offset,
        y: inner.y + 1,
    });
}

fn render_new_pane_picker(
    frame: &mut ratatui::Frame<'_>,
    area: Rect,
    picker: NewPanePickerState,
    theme: &UiTheme,
) {
    let popup = centered_rect(68, 58, area);
    frame.render_widget(Clear, popup);
    let mut lines = vec![
        Line::from(Span::styled("New window / preset", theme.help_title())),
        Line::from(""),
        Line::from("Choose a window/tab to add. Enter confirms, Esc closes, j/k moves."),
        Line::from("Direct keys: Space empty window, e editor, i ide, g git, d docker, K k9s, m monitor."),
        Line::from(""),
    ];
    for (index, choice) in NEW_PANE_CHOICES.iter().copied().enumerate() {
        let marker = if index == picker.selected { ">" } else { " " };
        let style = if index == picker.selected {
            theme.selected()
        } else {
            theme.title()
        };
        lines.push(Line::from(vec![
            Span::styled(
                format!("{marker} {:<5} {:<13}", choice.key(), choice.label()),
                style,
            ),
            Span::raw(choice.description().to_string()),
        ]));
    }

    let block = Block::default()
        .borders(Borders::ALL)
        .title(" Add ")
        .border_style(theme.focused_border());
    let paragraph = Paragraph::new(lines)
        .block(block)
        .wrap(Wrap { trim: false });
    frame.render_widget(paragraph, popup);
}

fn centered_rect(percent_x: u16, percent_y: u16, area: Rect) -> Rect {
    let vertical = Layout::default()
        .direction(Direction::Vertical)
        .constraints([
            Constraint::Percentage((100 - percent_y) / 2),
            Constraint::Percentage(percent_y),
            Constraint::Percentage((100 - percent_y) / 2),
        ])
        .split(area);
    Layout::default()
        .direction(Direction::Horizontal)
        .constraints([
            Constraint::Percentage((100 - percent_x) / 2),
            Constraint::Percentage(percent_x),
            Constraint::Percentage((100 - percent_x) / 2),
        ])
        .split(vertical[1])[1]
}

fn render_layout_preview(
    frame: &mut ratatui::Frame<'_>,
    area: Rect,
    state: &CreateProjectState,
    theme: &UiTheme,
    cursor_enabled: bool,
) {
    let mode = match state.layout_mode {
        LayoutEditMode::Navigate => "nav",
        LayoutEditMode::EditCommand => "edit command",
    };
    let block = Block::default()
        .borders(Borders::ALL)
        .title(format!(
            " Live preview: {} ({mode}) ",
            state.current_tab().name
        ))
        .border_style(if state.field == Field::Layout {
            theme.focused_border()
        } else {
            theme.border()
        });
    let inner = inner_rect(area);
    frame.render_widget(block, area);

    if inner.width < 8 || inner.height < 4 {
        return;
    }

    let tab = state.current_tab();
    if tab.preset == Some(LayoutPreset::Ide) {
        render_ide_preview(frame, inner, tab, theme);
        return;
    }

    let row_percentages = percentages(tab.rows.iter().map(|row| row.ratio));
    let row_constraints = row_percentages
        .iter()
        .copied()
        .map(Constraint::Percentage)
        .collect::<Vec<_>>();
    let row_chunks = Layout::default()
        .direction(Direction::Vertical)
        .constraints(row_constraints)
        .split(inner);

    for (row_index, row) in tab.rows.iter().enumerate() {
        let row_area = row_chunks[row_index];
        let pane_percentages = percentages(row.panes.iter().map(|pane| pane.ratio));
        let pane_constraints = pane_percentages
            .iter()
            .copied()
            .map(Constraint::Percentage)
            .collect::<Vec<_>>();
        let pane_chunks = Layout::default()
            .direction(Direction::Horizontal)
            .constraints(pane_constraints)
            .split(row_area);

        for (pane_index, pane) in row.panes.iter().enumerate() {
            let selected = row_index == state.selected_row && pane_index == state.selected_pane;
            let command = if pane.command.trim().is_empty() {
                "shell".to_string()
            } else {
                pane.command.clone()
            };
            let title = format!(
                " r{} {}% / p{} {}% ",
                row_index + 1,
                row_percentages[row_index],
                pane_index + 1,
                pane_percentages[pane_index]
            );
            let content = vec![
                Line::from(Span::styled(
                    if selected { "selected" } else { "pane" },
                    if selected {
                        theme.help_title()
                    } else {
                        theme.muted()
                    },
                )),
                Line::from(command),
            ];
            let pane_block = Block::default()
                .borders(Borders::ALL)
                .title(title)
                .border_style(if selected {
                    theme.focused_border()
                } else {
                    theme.border()
                });
            let paragraph = Paragraph::new(content)
                .block(pane_block)
                .wrap(Wrap { trim: false });
            frame.render_widget(paragraph, pane_chunks[pane_index]);
            if cursor_enabled {
                render_command_cursor(frame, pane_chunks[pane_index], state, selected, &pane.command);
            }
        }
    }

    let footer = Paragraph::new(vec![Line::from(Span::styled(
        "Ratios are weights; preview normalizes them to Constraint::Percentage.",
        theme.muted(),
    ))]);
    let footer_area = Rect {
        x: inner.x,
        y: inner.y + inner.height.saturating_sub(1),
        width: inner.width,
        height: 1,
    };
    frame.render_widget(footer, footer_area);
}

fn render_ide_preview(
    frame: &mut ratatui::Frame<'_>,
    area: Rect,
    tab: &LayoutTab,
    theme: &UiTheme,
) {
    if area.width < 8 || area.height < 4 {
        return;
    }
    let columns = Layout::default()
        .direction(Direction::Horizontal)
        .constraints([Constraint::Percentage(65), Constraint::Percentage(35)])
        .split(area);
    let right_rows = Layout::default()
        .direction(Direction::Vertical)
        .constraints([Constraint::Percentage(60), Constraint::Percentage(40)])
        .split(columns[1]);

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

    render_preview_pane(frame, columns[0], " editor 65% ", editor, true, theme);
    render_preview_pane(frame, right_rows[0], " ai 60% ", ai, false, theme);
    render_preview_pane(
        frame,
        right_rows[1],
        " terminal 40% ",
        if terminal.trim().is_empty() {
            "shell"
        } else {
            terminal
        },
        false,
        theme,
    );
}

fn render_preview_pane(
    frame: &mut ratatui::Frame<'_>,
    area: Rect,
    title: &'static str,
    command: &str,
    focused: bool,
    theme: &UiTheme,
) {
    let pane_block = Block::default()
        .borders(Borders::ALL)
        .title(title)
        .border_style(if focused {
            theme.focused_border()
        } else {
            theme.border()
        });
    let paragraph = Paragraph::new(vec![Line::from(command.to_string())])
        .block(pane_block)
        .wrap(Wrap { trim: false });
    frame.render_widget(paragraph, area);
}

fn inner_rect(area: Rect) -> Rect {
    Rect {
        x: area.x.saturating_add(1),
        y: area.y.saturating_add(1),
        width: area.width.saturating_sub(2),
        height: area.height.saturating_sub(2),
    }
}

fn percentages(ratios: impl Iterator<Item = u16>) -> Vec<u16> {
    let ratios = ratios.collect::<Vec<_>>();
    if ratios.is_empty() {
        return vec![];
    }
    let total = ratios.iter().copied().map(u32::from).sum::<u32>().max(1);
    let mut percentages = ratios
        .iter()
        .map(|ratio| ((*ratio as u32 * 100) / total).max(1) as u16)
        .collect::<Vec<_>>();
    let sum = percentages.iter().copied().map(u32::from).sum::<u32>();
    match sum.cmp(&100) {
        std::cmp::Ordering::Less => {
            if let Some(last) = percentages.last_mut() {
                *last += (100 - sum) as u16;
            }
        }
        std::cmp::Ordering::Greater => {
            let mut overflow = sum - 100;
            for percentage in percentages.iter_mut().rev() {
                let removable = u32::from(percentage.saturating_sub(1)).min(overflow);
                *percentage -= removable as u16;
                overflow -= removable;
                if overflow == 0 {
                    break;
                }
            }
        }
        std::cmp::Ordering::Equal => {}
    }
    percentages
}
