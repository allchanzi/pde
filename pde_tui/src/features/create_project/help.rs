impl CreateProjectState {
    pub fn lines(&self, theme: &UiTheme) -> Vec<Line<'static>> {
        let mut lines = vec![
            Line::from(Span::styled("Create project", theme.help_title())),
            Line::from(""),
            field_line("Name", &self.name, self.field == Field::Name, theme),
            field_line("Path", &self.path, self.field == Field::Path, theme),
            field_line(
                "Base branch",
                &self.base_branch,
                self.field == Field::BaseBranch,
                theme,
            ),
            field_line(
                "Layout",
                "custom windows/tabs",
                self.field == Field::Layout,
                theme,
            ),
            Line::from(""),
        ];
        lines.extend(self.layout_lines(theme));
        lines.extend([
            Line::from(""),
            Line::from(Span::styled(self.footer_help(), theme.muted())),
        ]);
        if self.confirm == ConfirmState::ConfirmCreate {
            lines.extend([
                Line::from(""),
                Line::from(Span::styled(
                    "Confirm create? Enter=yes, Esc=no",
                    theme.help_title(),
                )),
            ]);
        }
        lines
    }

    pub fn footer_help(&self) -> &'static str {
        if self.confirm == ConfirmState::ConfirmCreate {
            return "Create confirm • Enter create • Esc back • ? help";
        }
        if self.field == Field::Layout {
            return match self.layout_mode {
                LayoutEditMode::Navigate => "Create layout • n=[n]ew p/r/w • p=[p]opup window • d=[d]elete p/r/w • i=[i]nsert/edit • ? help",
                LayoutEditMode::EditCommand => "Create layout command edit • type command • Enter/Esc finish edit • ? help",
            };
        }
        "Create project • Enter/Tab next • Shift+Tab previous • ? help • Esc cancel"
    }

    pub fn active_help_lines(&self, theme: &UiTheme) -> Vec<Line<'static>> {
        vec![
            Line::from(Span::styled("Create project shortcuts", theme.help_title())),
            Line::from(""),
            Line::from("Enter / Tab       Next field; create from Layout field"),
            Line::from("Shift+Tab         Previous field"),
            Line::from("Esc               Escape/cancel / leave command edit / close confirmation"),
            Line::from("?                 Help toggle"),
            Line::from(""),
            Line::from(Span::styled("Layout editor", theme.title())),
            Line::from("n w               [n]ew [w]indow/tab via popup"),
            Line::from("p                 [p]opup for empty/predefined window/tab"),
            Line::from("n r               [n]ew [r]ow inside current window"),
            Line::from("n p               [n]ew [p]ane in current row"),
            Line::from("d w               [d]elete selected [w]indow/tab"),
            Line::from("d r               [d]elete selected [r]ow"),
            Line::from("d p               [d]elete selected [p]ane"),
            Line::from("                  Presets: editor, ide, git, docker, k9s, monitor"),
            Line::from("h/l               Vim left/right: select previous/next pane"),
            Line::from("j/k               Vim down/up: select next/previous row"),
            Line::from("[ / ]             Previous/next window/tab"),
            Line::from("i                 [i]nsert/edit selected pane command"),
            Line::from("Esc               Escape edit mode"),
            Line::from("type              In edit mode: write pane command"),
            Line::from("Backspace         In edit mode: delete command character"),
            Line::from("+ / -             Increase/decrease selected pane ratio"),
            Line::from("{ / }             Decrease/increase selected row ratio"),
            Line::from(""),
            Line::from(Span::styled("Model", theme.title())),
            Line::from("Each window/tab contains rows. Each row contains pane cells."),
            Line::from("Ratios are normalized to Ratatui Constraint::Percentage in the preview."),
            Line::from("Commands are started in their pane; blank command opens a shell."),
        ]
    }

    fn layout_lines(&self, theme: &UiTheme) -> Vec<Line<'static>> {
        self.layout
            .iter()
            .enumerate()
            .flat_map(|(tab_index, tab)| {
                let tab_marker = if tab_index == self.selected_tab {
                    ">"
                } else {
                    " "
                };
                let tab_style = if tab_index == self.selected_tab {
                    theme.help_title()
                } else {
                    theme.title()
                };
                let header = Line::from(Span::styled(
                    format!("{tab_marker} window {}: {}", tab_index + 1, tab.name),
                    tab_style,
                ));
                let row_percentages = percentages(tab.rows.iter().map(|row| row.ratio));
                let rows = tab.rows.iter().enumerate().map(move |(row_index, row)| {
                    let pane_percentages = percentages(row.panes.iter().map(|pane| pane.ratio));
                    let cells = row
                        .panes
                        .iter()
                        .enumerate()
                        .map(|(pane_index, pane)| {
                            let selected = tab_index == self.selected_tab
                                && row_index == self.selected_row
                                && pane_index == self.selected_pane;
                            let command = if pane.command.is_empty() {
                                "shell"
                            } else {
                                &pane.command
                            };
                            let cell = format!(
                                "[{}:{}%] {}",
                                pane_index + 1,
                                pane_percentages[pane_index],
                                command
                            );
                            if selected { format!("*{cell}*") } else { cell }
                        })
                        .collect::<Vec<_>>()
                        .join(" | ");
                    Line::from(format!(
                        "  row {} {}% :: {}",
                        row_index + 1,
                        row_percentages[row_index],
                        cells
                    ))
                });
                std::iter::once(header).chain(rows).collect::<Vec<_>>()
            })
            .collect()
    }

}
