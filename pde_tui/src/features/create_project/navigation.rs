impl CreateProjectState {
    fn move_pane_left(&mut self) {
        self.selected_pane = self.selected_pane.saturating_sub(1);
    }
    fn move_pane_right(&mut self) {
        self.selected_pane = (self.selected_pane + 1).min(self.current_row().panes.len() - 1);
    }
    fn move_row_up(&mut self) {
        self.selected_row = self.selected_row.saturating_sub(1);
        self.clamp_pane();
    }
    fn move_row_down(&mut self) {
        self.selected_row = (self.selected_row + 1).min(self.current_tab().rows.len() - 1);
        self.clamp_pane();
    }
    fn previous_tab(&mut self) {
        self.selected_tab = self.selected_tab.saturating_sub(1);
        self.selected_row = 0;
        self.selected_pane = 0;
    }
    fn next_tab(&mut self) {
        self.selected_tab = (self.selected_tab + 1).min(self.layout.len() - 1);
        self.selected_row = 0;
        self.selected_pane = 0;
    }

    fn adjust_pane_ratio(&mut self, delta: i16) {
        adjust_ratio(&mut self.current_pane_mut().ratio, delta);
    }
    fn adjust_row_ratio(&mut self, delta: i16) {
        adjust_ratio(&mut self.current_row_mut().ratio, delta);
    }
    fn clamp_pane(&mut self) {
        self.selected_pane = self.selected_pane.min(self.current_row().panes.len() - 1);
    }

    fn current_tab(&self) -> &LayoutTab {
        &self.layout[self.selected_tab]
    }
    fn current_tab_mut(&mut self) -> &mut LayoutTab {
        &mut self.layout[self.selected_tab]
    }
    fn current_row(&self) -> &LayoutRow {
        &self.current_tab().rows[self.selected_row]
    }
    fn current_row_mut(&mut self) -> &mut LayoutRow {
        let row = self.selected_row;
        &mut self.current_tab_mut().rows[row]
    }
    fn current_pane_mut(&mut self) -> &mut LayoutPane {
        let pane = self.selected_pane;
        &mut self.current_row_mut().panes[pane]
    }
}
