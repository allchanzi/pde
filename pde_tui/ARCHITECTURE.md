# PDE TUI Rust Architecture

## Goals

- Prefer **vertical slices** over technical layers for user-facing behavior.
- Prefer **declarative / functional style**: events map to effects, render functions map state to widgets, IO stays at boundaries.
- Keep legacy shell/python core callable until each slice is ported deliberately.

## Project shape

```text
src/
  main.rs                 # boot only
  cli.rs                  # CLI args only
  app.rs                  # top-level state machine and cross-slice effects
  tui.rs                  # terminal runtime, event loop, frame layout
  features/
    workspace.rs          # main PDE workspace: projects, workspaces, runners
  shared/
    process.rs            # external command boundary
    root.rs               # PDE root detection
    selection.rs          # reusable pure list-selection helpers
    ui/theme.rs           # shared UI theme loaded from PDE presets/allc/themes/current + presets/allc/themes/*.sh
```

## Vertical-slice rules

A feature owns the behavior for one user workflow. Each feature module should keep these together:

- state/model structs
- event-to-effect mapping
- render functions
- feature-local data loading/parsing when it is only used by that feature

Do **not** create broad `models/`, `views/`, or `controllers/` folders. If two features need the same code, move only the stable reusable piece to `shared/`. UI styling belongs in `shared/ui/` and should be passed into feature render functions rather than hard-coded in slices.

## Declarative / functional rules

- Keyboard handlers should return `Effect` instead of directly executing IO.
- Rendering should be a pure-ish projection: `state -> widgets`.
- Prefer iterator pipelines (`map`, `collect`, `transpose`) for transformations.
- Keep mutation localized to state transitions (`App::apply_local_effect`, feature state transitions, selection helpers).
- External process execution belongs in `shared::process`.

## Current workspace UX

The main screen is split into two vertical halves:

- Left/global half:
  - `Projects`: registered projects. `a` adds a project, `d` deletes selected project registration.
  - `Global runners`: all active tmux/zellij sessions. `Enter` attaches.
- Right/selected half:
  - `Workspaces`: ways to open the selected project — main workspace and git worktrees. `Enter` opens, `a` starts the new-worktree flow, `d` deletes selected worktree.
  - `Project runners`: active tmux/zellij sessions for the selected project/worktrees. `Enter` attaches.
- Footer shows baseline shortcuts. `?` opens a contextual help popup for the active panel.
- `Tab` cycles focus between panels. `Alt+h/j/k/l` or `Alt+a/s/w/d` moves focus by direction. `j/k` or arrows scroll the focused panel.

## Adding a new feature

1. Add `src/features/<feature>.rs`.
2. Define `<Feature>State` and a `handle_key(...) -> Effect` or `Result<Effect>`.
3. Define `render(frame, area, state)` in the same module.
4. Add top-level coordination in `app.rs`/`tui.rs` only if the feature needs a new top-level view.
5. If it needs legacy integration, return `Effect::Exec(ExternalCommand::...)`.

## Custom project layouts

The create-project flow supports `minimal`, `full`, and `custom` code layouts.
`custom` asks for tabs and pane commands, then writes both multiplexer-specific layout files:

- `~/.config/zellij/layouts/<slug>.kdl`
- `~/.config/tmux/<slug>.sh`

Pane commands are entered as `|`-separated values. Blank panes open an interactive shell.
The legacy core already prefers these custom files when opening a project.
