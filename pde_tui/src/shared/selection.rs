use ratatui::widgets::ListState;

pub fn select_first_when_present(state: &mut ListState, len: usize) {
    state.select((len > 0).then_some(0));
}

pub fn clamp_selection(state: &mut ListState, len: usize) {
    state.select(match (len, state.selected()) {
        (0, _) => None,
        (size, Some(index)) => Some(index.min(size - 1)),
        (_, None) => Some(0),
    });
}
