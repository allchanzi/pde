# Personal Development Environment

A terminal-first PDE app with a Rust TUI, CLI wrappers, and optional install presets. The default install is intentionally empty/minimal: it installs the app, creates PDE config, and verifies that either tmux or Zellij is available. Opinionated dotfiles live in the tracked `allc` preset.

---

## Contents

- [Highlights](#highlights)
- [Quick Start](#quick-start)
- [Overview](#overview)
- [Directory structure](#directory-structure)
- [Requirements](#requirements)
- [Installation](#installation)
- [Editing Configs](#editing-configs)
- [Theme system](#theme-system)
- [Multiplexer](#multiplexer)
- [Project registry — projects](#project-registry--projects)
- [Neovim](#neovim)
- [Shell](#shell)
- [Terminals](#terminals)
- [Application Reference](#application-reference)
- [Tooling Reference](#tooling-reference)
- [Scripts reference](#scripts-reference)

---

## Highlights

- Minimal default install for PDE TUI/CLI plus tmux or Zellij verification
- Optional `allc` preset for opinionated dotfiles, terminals, themes, shortcuts, and Neovim setup
- Choice of `tmux` or `zellij`, with per-user preferences stored outside git
- Registry-driven project picker (`projects`) with typed presets for code, hardware, and notes workspaces
- Rust TUI (`pde`) with project/workspace/session management and native create flow
- Optional AI panes and machine-local overrides without forking the tracked config

---

## Quick Start

```bash
git clone https://github.com/allc/pde ~/git/personal/pde
cd ~/git/personal/pde
./install.sh              # app + default preset
# optional: ./install.sh --preset allc
pde
```

After that, register projects in the shared registry and open them from the TUI or CLI:

```bash
projects register amplifier ~/projects/amplifier --type hardware
projects
```

---

## Overview

The repo is split into the PDE app and install presets. The app-first root install builds the Rust TUI, links CLI wrappers, creates `~/.config/pde`, and runs `presets/default`. The default preset only checks that a multiplexer is installed and writes minimal config. The `presets/allc` preset is the tracked opinionated setup with dotfiles, terminal configs, themes, shortcuts, Homebrew packages, and Neovim setup.

Machine-local choices live in `~/.config/pde/prefs` and optional local override files under `~/.config/tmux/` or `~/.config/zellij/layouts/`.

---

## Directory structure

```
pde/
├── pde_tui/            Rust Ratatui app
├── bin/                Thin CLI wrappers and remaining shell/Python helpers
│   ├── pde             Main entrypoint
│   ├── projects        Project registry CLI wrapper
│   └── pde-worktree    Worktree CLI wrapper
├── presets/
│   ├── default/        Minimal preset: verify tmux/zellij + empty PDE config
│   └── allc/           Opinionated tracked preset
│       ├── dotfiles/   App configs for terminals, nvim, tmux, zellij, zsh, ...
│       ├── themes/     Theme definitions
│       ├── Brewfile
│       └── Brewfile.macOS
├── templates/          Project / note / hardware scaffolding templates
└── install.sh          App installer + selected preset runner
```

---

## Requirements

Default install requirements:

- macOS or Linux
- `git`
- Rust/Cargo
- one multiplexer: `tmux` or `zellij`

The optional `allc` preset additionally expects/installs a larger Homebrew-based toolchain, terminal configs, Neovim config, themes, fonts, and shell integrations.

---

## Installation

Minimal PDE app + default preset:

```bash
git clone https://github.com/allc/pde ~/git/personal/pde
cd ~/git/personal/pde
./install.sh
pde
```

Opinionated `allc` preset:

```bash
./install.sh --preset allc
```

Or run a preset directly after installing the app:

```bash
./presets/default/install.sh
./presets/allc/install.sh
```

`install.sh` does the following:

1. Builds `pde_tui` with Cargo
2. Symlinks app wrappers into `~/bin`
3. Runs `presets/<name>/install.sh`

`presets/default` only creates empty PDE config and verifies `tmux`/`zellij`.
`presets/allc` installs/links the tracked dotfiles and preferred tools.

Runtime/log/state data is intentionally kept outside the repo:

- Neovim log: `$PDE_STATE_HOME/nvim/nvim.log` (default `~/.local/state/pde/nvim/nvim.log`)
- Lazygit runtime state: official Lazygit config/runtime dir (`~/Library/Application Support/lazygit` on macOS, `~/.config/lazygit` on Linux)
- k9s runtime state/logs/clusters: official k9s config/runtime dir (`~/Library/Application Support/k9s` on macOS, `~/.config/k9s` on Linux)

Restart your terminal when done if you installed `allc`.

### First Run

From a fresh clone to your first launcher command:

```bash
git clone https://github.com/allc/pde ~/git/personal/pde
cd ~/git/personal/pde
./install.sh              # app + default preset
# optional: ./install.sh --preset allc
pde
```

Use `pde` for the Rust TUI project picker/create flow, or use `projects register` for CLI registration. Existing personal wrapper scripts in `bin/` can still be linked by `install.sh` when explicitly tracked.

---

## Editing Configs

The default preset only links PDE app wrappers. Dotfile symlinks are part of the `allc` preset. If you install `allc`, edit files under `presets/allc/dotfiles`, not the generated paths under `~/.config`.

- `./install.sh` links app wrappers such as `pde`, `projects`, and `pde-worktree`
- `./install.sh --preset allc` also links terminal, shell, tmux/zellij, Neovim, theme, Lazygit, and k9s configs
- user-specific choices such as terminal, multiplexer, AI commands, and optional features live outside the repo in `~/.config/pde/prefs`

Typical `allc` edit flow:

```bash
cd ~/git/personal/pde
nvim presets/allc/dotfiles/ghostty/config
```

Useful apply/reload commands:

```bash
tmux source-file ~/.tmux.conf   # reload tmux config
exec zsh -l                     # restart current shell
nvim --headless "+Lazy! sync" +qa   # sync/update nvim plugins after plugin changes
```

For the terminal emulators and TUIs below, restart the app if you are unsure whether a specific setting hot-reloads.

---

## Theme system

Themes are bash variable files in `presets/allc/themes/`. The `current` symlink points to whichever theme is active.

### Picking a theme

```bash
theme              # interactive fzf picker
theme list         # print all available themes
theme current      # show the active theme name
theme apply catppuccin-mocha   # apply directly by name
theme apply nord
theme apply dracula
theme apply solarized-dark
theme apply tokyonight-night
theme apply synthwave-84
theme update       # download latest official catppuccin configs from GitHub
```

`theme update` fetches the official upstream configs from the [catppuccin](https://github.com/catppuccin) GitHub organisation and caches them under `~/.cache/catppuccin/`. Applying any catppuccin theme afterward will use those cached files.

### What gets updated when you apply a theme

| Tool | What changes |
|------|-------------|
| Alacritty | `~/.config/alacritty/theme.conf` |
| Kitty | `~/.config/kitty/theme.conf` |
| Ghostty | `~/.config/ghostty/theme` |
| tmux | `~/.tmux.theme.conf` (reloaded live if running) |
| Zellij | `theme` line in `~/.config/zellij/config.kdl` |
| Lazygit | `~/.config/lazygit/theme.yml` (or macOS equivalent) |
| K9s | `~/Library/Application Support/k9s/skins/dotfiles.yaml` on macOS, `~/.config/k9s/skins/dotfiles.yaml` on Linux |
| Neovim | `~/.config/nvim/lua/config/theme.lua` (colorscheme + background) |
| zsh-syntax-highlighting | `~/.config/shell/catppuccin-syntax.zsh` |
| fzf | `~/.config/shell/catppuccin-fzf.zsh` |

### Adding a custom theme

Copy an existing theme file and edit the colour variables:

```bash
cp presets/allc/themes/catppuccin-mocha.sh presets/allc/themes/my-theme.sh
# edit presets/allc/themes/my-theme.sh
theme apply my-theme
```

Required variables: `THEME_NAME`, `NVIM_COLORSCHEME`, `NVIM_BACKGROUND`, `BASE`, `TEXT`, `SUBTLE`, `SURFACE0`–`SURFACE2`, `SUBTEXT0`–`SUBTEXT1`, `OVERLAY1`, `ROSEWATER`, `LAVENDER`, `BLUE`, `PINK`, `GREEN`, `YELLOW`, `CYAN`, `RED`, `WHITE`.

---

## Multiplexer

The environment supports both **tmux** and **Zellij**. Your per-user preferences are stored in `~/.config/pde/prefs`:

```
MULTIPLEXER=zellij   # or tmux
TERMINAL=kitty       # or ghostty / alacritty
AI_PROFILE=codex+claude   # or codex / claude / ollama / custom / none
AI_COMMAND_1=codex
AI_COMMAND_2=claude
ENABLE_PANTS=1
```

`setup` covers the common presets. If you want something more specific, edit `AI_COMMAND_1` and `AI_COMMAND_2` directly or use a local tmux/Zellij layout override.

Switch at any time:

```bash
setup          # re-run the wizard
setup --reset  # remove per-user prefs and local layout overrides
# or edit ~/.config/pde/prefs directly
```

The main `pde` launcher and registry-driven project sessions read this preference at runtime and launch the correct multiplexer automatically.

### tmux

Config: `tmux/.tmux.conf` + `tmux/theme.conf`

Key bindings use the `Ctrl-a` prefix. The theme file is included from `.tmux.conf` so it is updated independently of the main config.

| Shortcut | Action |
|----------|--------|
| `Ctrl-a g` | Show existing worktrees for current folder |
| `Ctrl-a G` | Show all branches for current folder |
| `Ctrl-a n` | Create new branch worktree from default base |
| `Ctrl-a Tab` | Open session switcher |
| `Ctrl-a h` | Open floating full PDE shortcuts help |
| `Ctrl-a M` | Open floating process analysis popup |
| `Ctrl-a P` | Create system snapshot and copy it to clipboard |

### Zellij

Config: `zellij/config.kdl`  
Layouts: `zellij/layouts/*.kdl`

| Shortcut | Action |
|----------|--------|
| `Ctrl-a` | Enter Tmux mode (prefix for all commands below) |
| `Ctrl-a \|` | Split pane vertically |
| `Ctrl-a -` | Split pane horizontally |
| `Ctrl-a c` | New tab |
| `Ctrl-a x` | Close current tab |
| `Ctrl-a q` | Close current pane |
| `Ctrl-a g` | Show existing worktrees for current folder |
| `Ctrl-a G` | Show all branches for current folder |
| `Ctrl-a n` | Create new branch worktree from default base |
| `Ctrl-a Tab` | Open the floating session manager |
| `Ctrl-a d` | Detach session |
| `Ctrl-a X` | Quit the whole Zellij session |
| `Ctrl-a Q` | Quit the whole Zellij session |
| `Ctrl-a a/w/s/D` | Resize pane (left/up/down/right) |
| `Ctrl-a p / t / r / m / [` | Enter pane / tab / resize / move / scroll mode |
| `Ctrl-a o` | Enter session mode |
| `Ctrl-a h` | Open floating full PDE shortcuts help |
| `Ctrl-a z / f / n` | Fullscreen / toggle pane frames / floating panes |
| `Ctrl-a M` | Open floating process analysis pane |
| `Ctrl-a , / .` | Rename tab / rename pane |
| `Ctrl-a ?` | Open the floating session manager |
| `Alt-1` … `Alt-7` | Jump to tab by number |
| `Alt-Left / Alt-Right` | Previous / next tab |
| `Alt-W/A/S/D` | Navigate panes |

Zellij panes in these layouts are configured in a tmux-like style:

- `editor`, `ai`, `git`, `docker`, and `monitor` panes return to a login shell after the foreground command exits
- when `nvim`, `codex`, `claude`, `lazygit`, `btop`, etc. exit, the pane falls back to a login shell instead of staying as a dead command pane
- close a pane you no longer want with `Ctrl-a q`
- for machine-local overrides, `pde` prefers `~/.config/zellij/layouts/pde.local.kdl` if it exists
- `setup` writes `~/.config/zellij/layouts/pde.local.kdl` from the selected AI profile in `~/.config/pde/prefs`
- `Ctrl-a` now behaves more like a top-level command palette: the status bar shows tmux-mode options in a taller two-line footer, and `Ctrl-a ?` opens the built-in floating session manager

To switch back to native Zellij command panes:

- edit [zellij/layouts/pde.kdl](zellij/layouts/pde.kdl)
- replace `pane command="zsh" { args "-lc" "...; exec \"$SHELL\" -l"` with direct command panes such as `pane command="claude"` or `pane command="nvim" { args "." }`

---

## Project registry — projects

`projects` is the registry-driven project manager for this setup. It stores per-user project metadata outside git and opens the correct workspace preset based on project type.

Supported project types:

- `code` — developer-oriented layout with editor, git, optional AI, and branch/worktree support
- `hardware` — files + nvim + docs + tools layout, with project-defined commands for schematic / PCB / 3D / datasheets / build flows
- `notes` — lightweight notes/docs workspace

Project metadata is stored in:

- `~/.config/pde/projects.json`

When creating a new project, the suggested path defaults to `$HOME/projects/<slug>`. Override the base directory by exporting `PDE_PROJECTS_DIR` in your environment, e.g. `export PDE_PROJECTS_DIR="$HOME/Documents/code"`.

Main commands:

```bash
projects                                   # picker + open selected project
projects list                              # includes active tmux/zellij sessions per project
projects open my-project
projects open my-project -b feature/branch
projects register my-project ~/git/my-project --type code
projects register amplifier ~/projects/amplifier --type hardware
projects delete amplifier
projects info amplifier
projects run amplifier schematic
```

Registry entries can include optional capabilities and custom commands. This is especially useful for hardware projects where `projects run <name> <capability>` can open named tools such as `schematic`, `mindmap`, `model3d`, or `datasheets`.

If you want a standalone alias in `~/bin`, `projects register` can create a wrapper launcher that delegates back to the registry entry. Existing hand-crafted launchers can still coexist with the registry.

To remove a project from the registry, use `projects delete <name>`. This keeps the project files on disk and, by default, also removes a generated wrapper launcher. Use `--keep-launcher` if you want to keep that alias.

`pde create` is a convenience wrapper around registry creation. It registers the project and creates the target directory if needed, but it no longer scaffolds starter files into that directory.

---

## Neovim

Plugin manager: [lazy.nvim](https://github.com/folke/lazy.nvim)  
Config entry: `nvim/lua/config/`  
Plugin specs: `nvim/lua/plugins/`

### Key plugins

| Plugin | Purpose |
|--------|---------|
| telescope.nvim | Fuzzy finder for files, grep, buffers, diagnostics |
| nvim-tree | File explorer sidebar |
| lualine.nvim | Statusline with powerline separators |
| bufferline.nvim | Buffer tabs at the top |
| gitsigns.nvim | Inline git blame, hunk navigation and staging |
| conform.nvim | Formatting |
| nvim-lspconfig | LSP client |
| render-markdown.nvim | Better Markdown / README rendering inside Neovim |
| vimtex | LaTeX editing, compile, and PDF viewer integration |
| catppuccin/nvim | Colour scheme |
| trouble.nvim | Diagnostics panel |
| which-key.nvim | Keybinding hints |

### Keymaps

Open the in-editor cheatsheet at any time:

```
<Space>h    Open cheatsheet popup
```

#### Find

| Key | Action |
|-----|--------|
| `SPC f f` | Find files |
| `SPC f g` | Grep across project |
| `SPC f p` | Grep with search text and path/glob in one popup |
| `SPC f r` | Recent files |
| `SPC f s` | Search word under cursor |
| `SPC f c` | Search in current buffer |
| `SPC f b` | List open buffers |
| `SPC f h` | Help tags |
| `SPC f d` | Diagnostics |

`SPC f p` opens a small popup with two fields:

```text
Search: <what to find>
Path:   <directory, file, or glob>
```

Examples for the `Path` field:

```text
nvim/lua/plugins       # exact directory
nvim/lua/plugins/*.lua # glob
**/*test*.py           # glob anywhere in the repo
```

#### Buffers

| Key | Action |
|-----|--------|
| `] b` / `[ b` | Next / prev buffer |
| `SPC b d` | Close buffer |
| `SPC b q` | Close all buffers |
| `SPC b Q` | Force close all buffers |
| `SPC b >` / `SPC b <` | Move buffer right / left |
| `SPC b p` | Pin / unpin buffer |

#### File tree

| Key | Action |
|-----|--------|
| `SPC e` | Toggle file tree |
| `SPC o` | Focus file tree |
| `Tab` | Toggle focus between tree and previous window |
| `I` | Toggle showing gitignored files |

#### Git (gitsigns)

| Key | Action |
|-----|--------|
| `] c` / `[ c` | Next / prev hunk |
| `SPC g h s` | Stage hunk |
| `SPC g h r` | Reset hunk |
| `SPC g h p` | Preview hunk |
| `SPC g h b` | Blame popup for line |
| `SPC g h B` | Toggle inline blame |

#### LSP

| Key | Action |
|-----|--------|
| `g d` | Go to definition |
| `g r` | Go to references |
| `K` | Hover documentation |
| `SPC c a` | Code action |
| `SPC c f` | Format file |
| `SPC r n` | Rename symbol |

#### Diagnostics

| Key | Action |
|-----|--------|
| `SPC x x` | Toggle diagnostics panel |
| `] d` / `[ d` | Next / prev diagnostic |

#### File tree

| Key | Action |
|-----|--------|
| `SPC e` | Toggle explorer |
| `SPC o` | Focus explorer |
| `a` / `d` / `r` | Add / delete / rename |
| `c` / `x` / `p` | Copy / cut / paste |

#### Splits & windows

| Key | Action |
|-----|--------|
| `SPC s v` | Vertical split |
| `SPC s h` | Horizontal split |
| `Ctrl-h/j/k/l` | Navigate between windows |

---

## Shell

ZSH config is split into focused files under `zsh/shell/`:

| File | Contents |
|------|----------|
| `env.zsh` | PATH, pyenv (lazy), history settings, plugin sourcing |
| `aliases.zsh` | Shell aliases |
| `functions.zsh` | Shell functions |
| `vi-mode.zsh` | Vi keybindings for the command line |
| `theme.zsh` | Theme-related shell helpers |

**Vi mode** is enabled for the command line (`bindkey -v`). `Esc` switches to command mode, `i`/`a` return to insert, and the cursor changes shape with the mode. Common keys (`Ctrl-A`/`Ctrl-E`/`Ctrl-R`/`Ctrl-W`, Backspace) still work in insert mode, and `v` in command mode opens the current line in Neovim. Vi keys are also active in tmux copy mode (`v` select, `y` yank), plus Neovim, Lazygit, k9s, btop, and Zellij.

**Pyenv** is lazy-initialised — the full `pyenv init` only runs the first time you invoke `pyenv` or `python`, keeping shell startup fast.

**fzf**, **zsh-autosuggestions**, and **zsh-syntax-highlighting** are loaded from Homebrew if installed.

`aliases.zsh` also prefers `eza` for `ls`-style listings when it is installed; otherwise it falls back to a colour-enabled native `ls`. Useful defaults: `ll` for detailed view, `la` to show dotfiles, `lt` for a quick tree/recent listing.

Extra shell shortcut:

| Shortcut | Action |
|----------|--------|
| `Alt-h` | Open `fzf` over shell history, pick a command, run it |

---

## Terminals

### Kitty (`kitty/`)

`kitty.conf` includes `theme.conf` which is written by `bin/theme`. The catppuccin theme is loaded from the official upstream source when you run `theme update`.

### Ghostty (`ghostty/`)

`config` uses `config-file = theme` — the `theme` file is written by `bin/theme`.

### Alacritty (`alacritty/`)

`alacritty.toml` imports `theme.conf`. The catppuccin TOML is fetched from the official upstream source.

---

## Application Reference

| App | Repo config | Live path | Official docs | Applying changes |
|-----|-------------|-----------|---------------|------------------|
| Neovim | `nvim/` | `~/.config/nvim/` | https://neovim.io/doc/ | Restart Neovim for config changes; run `nvim --headless "+Lazy! sync" +qa` after plugin spec changes |
| tmux | `tmux/.tmux.conf`, `tmux/theme.conf` | `~/.tmux.conf`, `~/.tmux.theme.conf` | https://github.com/tmux/tmux/wiki | `tmux source-file ~/.tmux.conf` |
| Zellij | `zellij/config.kdl`, `zellij/layouts/*.kdl` | `~/.config/zellij/` | https://zellij.dev/documentation/ | Detach/reattach or start a new session after config/layout edits; theme changes are not applied live to existing sessions |
| Ghostty | `ghostty/config`, `ghostty/theme` | `~/.config/ghostty/` | https://ghostty.org/docs/config | Some settings reload, some do not; restart Ghostty for full safety |
| Kitty | `kitty/kitty.conf`, `kitty/theme.conf` | `~/.config/kitty/` | https://sw.kovidgoyal.net/kitty/conf/ | Restart Kitty for guaranteed reload |
| Alacritty | `alacritty/alacritty.toml`, `alacritty/theme.toml` | `~/.config/alacritty/` | https://alacritty.org/config-alacritty.html | `live_config_reload = true`, so many changes apply automatically |
| Lazygit | `lazygit/config.yml`, `lazygit/config.shared.yml` | `~/.config/lazygit/` or macOS app support path | https://github.com/jesseduffield/lazygit/blob/master/docs/Config.md | Restart Lazygit |
| K9s | `k9s/config.yaml`, `k9s/skins/dotfiles.yaml` | `~/.config/k9s/` or macOS app support path | https://k9scli.io/ | Restart K9s if the skin is already loaded |
| btop | `btop/btop.conf` | `~/.config/btop/btop.conf` | https://github.com/aristocratos/btop#configurability | Restart btop |
| zsh | `zsh/.zshrc`, `zsh/shell/*.zsh` | `~/.zshrc`, `~/.config/shell/` | https://zsh.sourceforge.io/Doc/ | `source ~/.zshrc` or `exec zsh -l` |
| Preferences | per-user choices managed by setup | `~/.config/pde/prefs` | n/a | Re-run `setup` or edit the file directly |

Notes:

- `theme apply <name>` rewrites the theme-managed files for Ghostty, Kitty, Alacritty, tmux, Zellij, Lazygit, K9s, Neovim, fzf, and zsh syntax highlighting
- custom project layouts write Zellij layout files under `~/.config/zellij/layouts/`
- some terminal settings are platform-specific; when in doubt, prefer the official docs page linked above for the exact option semantics
- optional AI tool installation is handled by [install-optionals](bin/install-optionals) based on the current AI profile

---

## Tooling Reference

| Tool | Where it shows up here | Official docs | Notes |
|------|-------------------------|---------------|-------|
| fzf | shell history picker, theme picker, setup wizard | https://junegunn.github.io/fzf/ | Shell integration is loaded from `~/.fzf.zsh`; search syntax is documented at https://junegunn.github.io/fzf/search-syntax/ |
| ripgrep (`rg`) | code search, Telescope grep backend, shell usage | https://github.com/BurntSushi/ripgrep and https://github.com/BurntSushi/ripgrep/blob/master/GUIDE.md | By default it respects `.gitignore`; use `-uu` / `-uuu` to relax filtering |
| Codex | AI panes in tmux/Zellij | https://platform.openai.com/docs/codex | Local shell/tooling docs: https://platform.openai.com/docs/guides/code-generation |
| Claude Code | AI panes in tmux/Zellij | https://docs.anthropic.com/en/docs/claude-code/overview | Installed via `npm install -g @anthropic-ai/claude-code` in this setup |
| Pants | helper code in `nvim/lua/config/pants*.lua` | https://www.pantsbuild.org/ | Project-specific, but this repo has integrations and shortcuts for it |
| btop | monitor pane | https://github.com/aristocratos/btop#configurability | Most settings can also be changed from the in-app menu |

---

## Scripts reference

| Script | Purpose | Migration priority |
|---|---|---|
| `bin/pde` | Thin wrapper to `bin/core/pde/pde`; main user entrypoint. | Keep wrapper |
| `bin/core/pde/pde` | Main PDE shell entrypoint; starts Rust TUI and delegates CLI commands. | High |
| `bin/projects` | Thin wrapper to `bin/core/pde/projects`. | Keep wrapper |
| `bin/core/pde/projects` | Core project registry, list/register/delete/open/inspect, tmux/zellij launch. | Highest |
| `bin/pde-worktree` | Thin wrapper to `bin/core/pde/pde-worktree`. | Keep wrapper |
| `bin/core/pde/pde-worktree` | Worktree picker/manager for code projects. | High |
| `bin/pde-prefs` | Loads and migrates PDE preference files. | Medium |
| `bin/setup` | Interactive setup for preferences, AI tools, theme, multiplexer. | Medium |
| `bin/install-optionals` | Installs optional tooling selected in setup. | Low/medium |
| `bin/pde-update` | Update/install helper for the PDE repo. | Low |
| `bin/pde-version` | Prints git tag/commit version. | Low |
| `bin/theme` | Theme picker/applicator/updater. | Medium |
| `bin/network-ports` | Live/listen-port process overview. | Low |
| `bin/process-analyze` | Local process/RAM/CPU and ports analysis report. | Low |
| `bin/ai-system-snapshot` | System/process/network/Docker snapshot for AI debugging. | Low |
| `bin/pde-shortcuts-help` | Text help for tmux/zellij/PDE shortcuts. | Low |
| `bin/run-and-return-to-shell` | Runs a command and returns to login shell. | Low |
| `bin/tmux-open-in-nvim` | Opens a selected tmux path in an existing Neovim pane. | Low |

Legacy `pde-create`, `pde-dashboard`, and `pde-project-browser` were removed; project creation now lives in the Rust TUI and registry CLI.

All scripts live in `bin/` and are symlinked to `~/bin/` by `install.sh`.

### `pde`

Main entry-point for this dotfiles repo. With no arguments it opens the Rust TUI.

```
pde                                Open the Rust TUI
pde create                         Open the TUI create flow
pde create <name> <path> --type code|hardware|notes
                                   Register a project via the registry CLI
pde open [project]                 Open a registered project
pde list                           List registered projects
pde info [project]                 Show project info
pde theme [theme-command]          Run `theme` through the main entry-point
pde install                        Run the setup wizard
pde update                         Update repo + re-run install
pde update --check                 Show branch/upstream update status
pde --version                      Show PDE version
pde -h                             Help
```

### `setup`

Interactive wizard run by `setup` or `pde install`. Steps through:

1. Package installation (`install.sh`)
2. Multiplexer choice (tmux / zellij) — saved to `~/.config/pde/prefs`
3. Terminal choice (kitty / ghostty / alacritty) — saved to `~/.config/pde/prefs`
4. AI choice (`codex+claude`, `codex`, `claude`, `ollama`, `custom`, `none`) — saved to `~/.config/pde/prefs`
5. Extra feature choice (currently `pants`) — saved to `~/.config/pde/prefs`
6. Theme picker (`bin/theme`)
7. Optional AI tool installation (`bin/install-optionals`)

Reset mode:

- `setup --reset`
- `pde install --reset`
- removes `~/.config/pde/prefs`, the legacy `~/.config/config/prefs` and `~/.config/shell/prefs`, `~/.config/zellij/layouts/pde.local.kdl`, and `~/.config/tmux/pde.local.sh`
- leaves project-specific local overrides such as `~/.config/zellij/layouts/<name>.local.kdl` untouched

### `theme`

```
theme                    Interactive picker (fzf)
theme list               List all available themes
theme current            Print active theme name
theme apply <name>       Apply a theme by name
theme update             Download latest catppuccin configs from GitHub
```

### `pde-update`

Update helper for this PDE repo. Supports:

- `pde update` — fetch + fast-forward pull + re-run `install.sh`
- `pde update --check` — show branch/upstream status without changing anything
- `pde update --install-only` — skip git pull and only re-run `install.sh`

### `projects`

Registry-driven project picker and launcher. Supports:

- interactive project picker
- `code`, `hardware`, and `notes` presets
- project registration with `--type`
- optional launcher wrapper generation
- project deletion via `projects delete <name>`
- capability commands such as `projects run amplifier schematic`
- code-project worktree flows via `projects open <name> -b <branch>`
- active session listing in `projects list` and `projects info`
- Rust TUI project picker/create flow via `pde`

### `pde-prefs`

Shared shell helper used by the launcher scripts and setup wizard to read and write per-user preferences from `~/.config/pde/prefs`.

### `install-optionals`

Installs optional AI tools based on the current AI profile in `~/.config/pde/prefs`. Supported automatic installs currently cover:

- `codex` via `@openai/codex`
- `claude` via `@anthropic-ai/claude-code`
- `ollama` via Homebrew formula `ollama`

The Ollama preset stores `AI_COMMAND_1="ollama run <model>"` (default model: `llama3.2`). Make sure the Ollama service/app is running and the model is pulled/available. Custom AI commands are not auto-installed; point them at an already installed binary or install that tool separately.


### `tmux-open-in-nvim`

Opens the file path under the tmux cursor in the nearest nvim instance in the current session.

### `ai-system-snapshot`

Generates a markdown snapshot of the current system state (packages, configs, tool versions) suitable for pasting into an AI context window.

### `process-analyze`

Builds a local heuristic report from `ps` and `lsof`, then highlights:

- top CPU processes
- top RAM processes
- category summaries
- likely optimization candidates
- listening ports

You can run it directly with:

```bash
pde process-analyze
```

### `pde-shortcuts-help`

Prints the full PDE shortcuts cheatsheet for tmux or Zellij:

```bash
pde shortcuts-help all
pde shortcuts-help tmux
pde shortcuts-help zellij
```
