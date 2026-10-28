impl CreateProjectState {
    pub fn lines(&self, theme: &UiTheme) -> Vec<Line<'static>> {
        if self.field == Field::Layout && self.confirm == ConfirmState::Editing {
            let mut lines = vec![
                Line::from(Span::styled("Edit layout", theme.help_title())),
                theme.shortcut_line(""),
            ];
            lines.extend(self.layout_lines(theme));
            return lines;
        }
        let mut lines = vec![
            Line::from(Span::styled(self.title(), theme.help_title())),
            theme.shortcut_line(""),
            field_line("Name", &self.name, self.field == Field::Name, theme),
            field_line("Path", &self.path, self.field == Field::Path, theme),
            field_line(
                "Base branch",
                &self.base_branch,
                self.field == Field::BaseBranch,
                theme,
            ),
            field_line("Multiplexer", &if self.multiplexers.is_empty() {
                "None installed (tmux/zellij)".into()
            } else {
                self.multiplexers.iter().enumerate().map(|(index, name)| if index == self.selected_multiplexer { format!("[{name}]") } else { name.clone() }).collect::<Vec<_>>().join(" / ")
            }, self.field == Field::Multiplexer, theme),
            capability_line(self, theme),
            field_line(
                "Layout",
                if self.edit_slug.is_some() { "preserved" } else { "tabs and terminal panes" },
                self.field == Field::Layout,
                theme,
            ),
            theme.shortcut_line(""),
        ];
        if self.edit_slug.is_none() { lines.extend(self.layout_lines(theme)); }
        if self.confirm == ConfirmState::ConfirmCreate {
            lines.extend([
                theme.shortcut_line(""),
                Line::from(Span::styled(
                    if self.edit_slug.is_some() { "Save project changes?" } else { "Create this project?" },
                    theme.help_title(),
                )),
            ]);
        }
        lines
    }

    pub fn footer_help(&self) -> &'static str {
        if self.confirm == ConfirmState::ConfirmCreate {
            return if self.edit_slug.is_some() { "Save changes? [y]es / [n]o • [?] help" } else { "Create project? [y]es / [n]o • [?] help" };
        }
        if self.pending_n {
            return "Add: [p]ane / [r]ow • [Esc] cancel";
        }
        if self.pending_delete {
            return "Delete: [p]ane / [r]ow / [w] whole tab • [Esc] cancel";
        }
        if self.new_pane_picker.is_some() {
            return "[Enter] add preset • [↑/↓] select • [Esc] back";
        }
        if self.field == Field::Layout {
            return match self.layout_mode {
                LayoutEditMode::Navigate => "[Tab] next • [Shift+Tab] back • [Enter] review • [?] help • [Esc] cancel",
                LayoutEditMode::EditCommand => "Type pane command • [Enter/Esc] finish • [?] help",
            };
        }
        "[Enter/Tab] next • [Shift+Tab] previous • [?] help • [Esc] cancel"
    }

    pub fn active_help_lines(&self, theme: &UiTheme) -> Vec<Line<'static>> {
        if self.confirm == ConfirmState::ConfirmCreate {
            return vec![
                Line::from(Span::styled(if self.edit_slug.is_some() { "Save project changes?" } else { "Create project?" }, theme.help_title())),
                theme.shortcut_line(if self.edit_slug.is_some() { "[y]es — save changes" } else { "[y]es — create project" }),
                theme.shortcut_line("[n]o — return to editing"),
                theme.shortcut_line("[?] toggle help"),
            ];
        }
        if self.edit_slug.is_some() {
            return vec![
                Line::from(Span::styled("Edit project shortcuts", theme.help_title())),
                theme.shortcut_line("[Enter/Tab] next field; review from Capabilities"),
                theme.shortcut_line("[Shift+Tab] previous field • [Esc] cancel • [?] help"),
                theme.shortcut_line("[←/→] / [Space] choose multiplexer"),
                theme.shortcut_line("[Space] toggle capability • [h/l] select • [r]tui / [p]antsui"),
                theme.shortcut_line("The existing layout and project slug are preserved."),
            ];
        }
        vec![
            Line::from(Span::styled("Create project shortcuts", theme.help_title())),
            theme.shortcut_line(""),
            theme.shortcut_line("[Enter/Tab] next field; review from Layout"),
            theme.shortcut_line("[Shift+Tab] previous field"),
            theme.shortcut_line("[Esc] cancel / finish editing"),
            theme.shortcut_line("[?] toggle help"),
            theme.shortcut_line("[←/→] / [Space] choose installed multiplexer"),
            theme.shortcut_line("[Space] toggle capability • [h/l] select • [r]tui / [p]antsui"),
            theme.shortcut_line(""),
            Line::from(Span::styled("Layout editor", theme.title())),
            theme.shortcut_line("[o]pen tab presets"),
            theme.shortcut_line("[n]ew [r]ow inside current tab"),
            theme.shortcut_line("[n]ew [p]ane in current row"),
            theme.shortcut_line("[d]elete selected [w] whole tab"),
            theme.shortcut_line("[d]elete selected [r]ow"),
            theme.shortcut_line("[d]elete selected [p]ane"),
            theme.shortcut_line("Presets: editor, ide, git, docker, rtui, pantsui, k9s, monitor"),
            theme.shortcut_line("[h/l] previous/next pane"),
            theme.shortcut_line("[j/k] next/previous row"),
            theme.shortcut_line("[Left bracket/Right bracket] previous/next tab"),
            theme.shortcut_line("[i]nsert/edit selected pane command"),
            theme.shortcut_line("type              In edit mode: write pane command"),
            theme.shortcut_line("[Backspace] delete command character in edit mode"),
            theme.shortcut_line("[+/-] increase/decrease selected pane ratio"),
            theme.shortcut_line("[{/}] decrease/increase selected row ratio"),
            theme.shortcut_line(""),
            Line::from(Span::styled("Model", theme.title())),
            theme.shortcut_line("Tab = screen (tmux window); row = horizontal band; pane = terminal."),
            theme.shortcut_line("Commands are started in their pane; blank command opens a shell."),
        ]
    }

    fn layout_lines(&self, theme: &UiTheme) -> Vec<Line<'static>> {
        let mut lines = vec![
            Line::from(Span::styled("Layout: tab → row → pane", theme.title())),
            theme.shortcut_line("Tab: a separate screen (tmux window)."),
            theme.shortcut_line("Row: a horizontal band inside a tab."),
            theme.shortcut_line("Pane: one terminal inside a row."),
            theme.shortcut_line(""),
            Line::from(Span::styled(format!(
                "Selected: tab {} / row {} / pane {}",
                self.selected_tab + 1, self.selected_row + 1, self.selected_pane + 1
            ), theme.help_title())),
            theme.shortcut_line(""),
        ];
        lines.push(Line::from(format!(
            "Tab {}/{}: {}", self.selected_tab + 1, self.layout.len(), self.current_tab().name
        )));
        if self.field == Field::Layout && self.confirm == ConfirmState::Editing {
            lines.push(theme.shortcut_line(""));
            let hints: &[&str] = if self.layout_mode == LayoutEditMode::EditCommand {
                &["Editing selected pane command", "Type a command; leave blank for a shell."]
            } else if self.pending_n {
                &["Add a terminal at the end of this row", "or a new row at the bottom of this tab."]
            } else if self.pending_delete {
                &["Delete the selected pane, its row,", "or the whole tab."]
            } else {
                &[
                    "Move: [←/→] pane • [↑/↓] row",
                    "Tabs: left/right bracket keys",
                    "Add: [o]pen tab presets",
                    "     [n]ew [p]ane / [n]ew [r]ow",
                    "Edit: [i]nsert pane command",
                    "Remove: [d]elete [p]ane/[r]ow/[w] tab",
                    "Size: [+/-] pane width • [{/}] row height",
                ]
            };
            lines.extend(hints.iter().map(|hint| theme.shortcut_line(hint)));
        }
        lines
    }

}

fn capability_line(state: &CreateProjectState, theme: &UiTheme) -> Line<'static> {
    let active = state.field == Field::Capabilities;
    let prefix = if active { "> " } else { "  " };
    let label_style = if active {
        theme.help_title()
    } else {
        theme.title()
    };
    let rtui_selected = active && state.selected_capability == CapabilityChoice::Rtui;
    let pantsui_selected = active && state.selected_capability == CapabilityChoice::Pantsui;
    let rtui_style = if rtui_selected {
        theme.selected()
    } else {
        theme.title()
    };
    let pantsui_style = if pantsui_selected {
        theme.selected()
    } else {
        theme.title()
    };
    let rtui_mark = if state.enable_rtui { "[x]" } else { "[ ]" };
    let pantsui_mark = if state.enable_pantsui { "[x]" } else { "[ ]" };
    Line::from(vec![
        Span::styled(format!("{prefix}{:<12}", "Capabilities"), label_style),
        Span::styled(format!("{rtui_mark} rtui{}", if state.available_rtui { "" } else { " (not installed)" }), rtui_style),
        Span::raw("  "),
        Span::styled(format!("{pantsui_mark} pantsui{}", if state.available_pantsui { "" } else { " (not installed)" }), pantsui_style),
    ])
}
