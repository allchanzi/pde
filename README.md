# Personal Development Environment

Portable dotfiles and a terminal-first development environment for macOS and Linux.

This repo bootstraps a full local setup around Neovim, tmux or Zellij, themed terminals, shell helpers, and per-project launchers. Machine-local preferences live outside the repo, so the tracked files stay shareable and safe to publish.

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
- [Project launcher — pde-create](#project-launcher--pde-create)
- [Neovim](#neovim)
- [Shell](#shell)
- [Terminals](#terminals)
- [Application Reference](#application-reference)
- [Tooling Reference](#tooling-reference)
- [Scripts reference](#scripts-reference)

---

## Highlights

- One-command bootstrap via Homebrew, symlinks, theme application, and Neovim plugin sync
- Choice of `tmux` or `zellij`, with per-user preferences stored outside git
- Shared theming across Ghostty, Kitty, Alacritty, tmux, Zellij, Lazygit, Neovim, fzf, and shell syntax highlighting
- Project launcher generator (`pde-create`) with branch-aware git worktree support
- Optional AI panes and machine-local overrides without forking the tracked config

---

## Quick Start

```bash
git clone https://github.com/<your-user>/<your-repo> ~/git/config
cd ~/git/config
./bootstrap.sh
exec zsh -l
pde install
pde
```

After that, generate per-project launchers as needed:

```bash
pde-create my-project ~/git/my-project --full
my-project
```

---

## Overview

Everything is managed through a bootstrap + symlink approach. After cloning you run one script and the environment is wired up: packages installed via Homebrew, config directories symlinked into `~/.config`, a Neovim plugin sync triggered, and an interactive wizard that lets you pick your multiplexer, terminal emulator, AI profile, optional features, and colour theme.

The repo is structured so that tracked files stay generic while user-specific choices live in `~/.config/pde/prefs` and optional local override files under `~/.config/tmux/` or `~/.config/zellij/layouts/`.

---

## Directory structure

```
config/
├── alacritty/          Alacritty terminal config
├── bin/                Executable scripts (symlinked into ~/bin)
│   ├── pde             Dashboard / theme / install entry-point
│   ├── pde-prefs       Shared helper for per-user preferences
│   ├── install-optionals  Install optional AI tools selected in setup
│   ├── pde-create          Generate project launcher scripts
│   ├── setup           Interactive setup wizard
│   ├── theme           Theme picker and applicator
│   ├── ai-system-snapshot  Snapshot LLM context about the system
│   └── tmux-open-in-nvim   Open current tmux pane path in nvim
├── bootstrap.sh        One-shot bootstrap (packages + symlinks)
├── Brewfile            Cross-platform Homebrew packages
├── Brewfile.macOS      macOS-only casks (terminals + fonts)
├── ghostty/            Ghostty terminal config
├── k9s/                K9s config and generated skin
├── kitty/              Kitty terminal config
├── lazygit/            Lazygit config
├── nvim/               Neovim config (lazy.nvim)
│   └── lua/
│       ├── config/     options, keymaps, lazy loader
│       └── plugins/    plugin specs (ui, lsp, format, git, …)
├── themes/             Theme definitions (bash variable files)
│   ├── catppuccin-mocha.sh
│   ├── catppuccin-latte.sh
│   ├── neon-cyberpunk.sh
│   └── current         Symlink → active theme file
├── tmux/               tmux config and theme include
├── zellij/             Zellij config and layouts
│   ├── config.kdl
│   └── layouts/        Per-project KDL layout files
└── zsh/
    ├── .zshrc
    └── shell/          Sourced fragments
        ├── aliases.zsh
        ├── env.zsh
        ├── functions.zsh
        └── theme.zsh
```

---

## Requirements

- macOS (Apple Silicon or Intel) or Linux
- `git`
- `curl`
- A [Nerd Font](https://www.nerdfonts.com/) — JetBrainsMono Nerd Font is installed automatically on macOS via `Brewfile.macOS`; on Linux install it manually from [nerdfonts.com](https://www.nerdfonts.com/font-downloads)

Everything else (Neovim, tmux, Zellij, fzf, lazygit, …) is installed by `bootstrap.sh` via Homebrew.

### Platform notes

| Feature | macOS | Linux |
|---------|-------|-------|
| Homebrew | `/opt/homebrew` (Apple Silicon) or `/usr/local` (Intel) | `/home/linuxbrew/.linuxbrew` |
| Terminal emulators (Kitty, Ghostty, Alacritty) | Installed via `Brewfile.macOS` | Install manually |
| Nerd Font | Installed via `Brewfile.macOS` | Install manually |
| zsh plugins | Loaded from Homebrew or common system paths | Same (with Linux Homebrew or system package manager) |
| Java / Chrome | Set up only if found in standard macOS Homebrew paths | Not configured (add to your own env) |
| Clipboard in `ai-system-snapshot` | `pbcopy` | `wl-copy` / `xclip` / `xsel` (first available) |

---

## Installation

```bash
git clone https://github.com/<your-user>/<your-repo> ~/git/config
cd ~/git/config
./bootstrap.sh
```

`bootstrap.sh` does the following:

1. Installs Homebrew if it is missing
2. Runs `brew bundle` for `Brewfile` (and `Brewfile.macOS` on macOS)
3. Backs up any existing config files that are not already symlinks
4. Creates symlinks from `~/.config/*` and `~/bin/*` into this repo
5. Applies the currently active theme
6. Sets up fzf shell integration
7. Reloads the tmux config if tmux is running
8. Runs `nvim --headless "+Lazy! sync" +qa` to install Neovim plugins

After bootstrap completes, run the **interactive setup wizard** to choose your multiplexer, terminal emulator, AI setup, optional features, and colour theme:

```bash
setup
# or
pde install
```

To remove your per-user wizard choices and go back to the repo defaults:

```bash
setup --reset
# or
pde install --reset
```

Restart your terminal when done.

### First Run

From a fresh clone to your first launcher command:

```bash
git clone https://github.com/<your-user>/<your-repo> ~/git/config
cd ~/git/config
./bootstrap.sh
exec zsh -l
pde install
pde
```

If you already have a repo-specific launcher script in `bin/`, you can run it after `bootstrap.sh` has linked it into `~/bin`. Example:

```bash
example-proj-name
```

If you want a launcher for some other repo, generate it first:

```bash
pde-create example-proj-name ~/git/example-proj-name --full
example-proj-name
```

---

## Editing Configs

`bootstrap.sh` symlinks the live config locations back into this repository. In practice this means:

- edit the files in this repo, not the generated paths under `~/.config` or `~/bin`
- the matching live path updates immediately because it is a symlink
- if you add a brand new top-level config file or script, re-run `./bootstrap.sh` if it also needs a new symlink in `$HOME`
- user-specific choices such as terminal, multiplexer, AI commands, and optional features now live outside the repo in `~/.config/pde/prefs`

Typical edit flow:

```bash
cd ~/git/config
nvim ghostty/config
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

Themes are bash variable files in `themes/`. The `current` symlink points to whichever theme is active.

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
cp themes/catppuccin-mocha.sh themes/my-theme.sh
# edit themes/my-theme.sh
theme apply my-theme
```

Required variables: `THEME_NAME`, `NVIM_COLORSCHEME`, `NVIM_BACKGROUND`, `BASE`, `TEXT`, `SUBTLE`, `SURFACE0`–`SURFACE2`, `SUBTEXT0`–`SUBTEXT1`, `OVERLAY1`, `ROSEWATER`, `LAVENDER`, `BLUE`, `PINK`, `GREEN`, `YELLOW`, `CYAN`, `RED`, `WHITE`.

---

## Multiplexer

The environment supports both **tmux** and **Zellij**. Your per-user preferences are stored in `~/.config/pde/prefs`:

```
MULTIPLEXER=zellij   # or tmux
TERMINAL=kitty       # or ghostty / alacritty
AI_PROFILE=codex+claude   # or codex / claude / custom / none
AI_COMMAND_1=codex
AI_COMMAND_2=claude
ENABLE_PANTS=1
```

`setup` covers the common presets. If you want something more specific, edit `AI_COMMAND_1` and `AI_COMMAND_2` directly or use a local tmux/Zellij layout override.

Switch at any time:

```bash
setup          # re-run the wizard
setup --reset  # remove per-user prefs and dashboard overrides
# or edit ~/.config/pde/prefs directly
```

All project launcher scripts generated by `pde-create` and the main `pde` launcher read this preference at runtime and launch the correct multiplexer automatically.

### tmux

Config: `tmux/.tmux.conf` + `tmux/theme.conf`

Key bindings use the default `Ctrl-b` prefix. The theme file is included from `.tmux.conf` so it is updated independently of the main config.

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
| `Ctrl-a d` | Detach session |
| `Ctrl-a X` | Quit the whole Zellij session |
| `Ctrl-a Q` | Quit the whole Zellij session |
| `Ctrl-a a/w/s/D` | Resize pane (left/up/down/right) |
| `Ctrl-a p / t / r / m / [` | Enter pane / tab / resize / move / scroll mode |
| `Ctrl-a o` | Enter session mode |
| `Ctrl-a z / f / n` | Fullscreen / toggle pane frames / floating panes |
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
- `Ctrl-a` now behaves more like a top-level command palette: the status bar shows tmux-mode options, and `Ctrl-a ?` opens the built-in floating session manager

To switch back to native Zellij command panes:

- edit [zellij/layouts/pde.kdl](zellij/layouts/pde.kdl)
- replace `pane command="zsh" { args "-lc" "...; exec \"$SHELL\" -l"` with direct command panes such as `pane command="claude"` or `pane command="nvim" { args "." }`
- for generated project launchers, make the same change in [bin/pde-create](bin/pde-create) and regenerate the launcher

---

## Project launcher — pde-create

`pde-create` generates a self-contained project launcher script and a matching Zellij layout file.

```
Usage:
  pde-create <command-name> <project-dir> [options]

Options:
  --minimal       Generate: terminal, editor, ai, git
  --full          Generate: terminal, editor, ai, git, docker, k9s, monitor
  --no-ai         Omit AI window
  --no-docker     Omit docker window
  --base-branch   Default base branch for new worktrees
  --dotfiles      Preset for dotfiles/config repos (no term2, no docker)
```

**Examples:**

```bash
# Create ~/bin/example-proj-name and ~/.config/zellij/layouts/example-proj-name.kdl
pde-create example-proj-name ~/git/example-proj-name --full --base-branch main

# Dotfiles-style repo preset
pde-create example-dotfiles-repo ~/git/example-dotfiles-repo --dotfiles
```

The generated launcher supports:

```bash
example-proj-name                         # open the main project
example-proj-name -b feature/my-branch    # create or attach to a worktree for that branch
example-proj-name -b feature/my-branch -f # force-recreate the worktree
```

When a branch is given the script:

1. Checks for an existing worktree for that branch — reuses it if found
2. Otherwise creates a new worktree at `../repo-branch-name/`
3. Tries `origin/<branch>` first, then falls back to `--base-branch`
4. Opens the multiplexer session in the worktree directory

### Window layout

| Layout | Windows |
|--------|---------|
| `--minimal` | terminal, editor (nvim), ai (codex + claude), git (lazygit) |
| `--full` | + term2, docker (lazydocker), k9s, monitor (ports/processes + btop) |
| `--dotfiles` | terminal, editor, ai, git — no term2, no docker |

Generated Zellij layouts use the same tmux-like pane behavior: interactive tools return to a shell when they exit. To restore native Zellij command panes, edit [bin/pde-create](bin/pde-create) and replace the `...; exec "$SHELL" -l` wrappers with direct `pane command="..."` entries before regenerating the launcher.

AI panes are generated from the currently selected AI profile when you run `pde-create`. If you later change the AI profile, re-run `pde-create` for existing project launchers or create a machine-local override layout/script.

### Pane customization

Source of truth for default pane/window layouts:

- tmux dashboard layout: [bin/pde](bin/pde)
- tmux generated project layouts: [bin/pde-create](bin/pde-create)
- zellij dashboard layout: [pde.kdl](zellij/layouts/pde.kdl)
- zellij generated project layouts: [bin/pde-create](bin/pde-create)

Simple machine-local override paths:

- Zellij dashboard: `~/.config/zellij/layouts/pde.local.kdl`
- Zellij project launcher `example-proj-name`: `~/.config/zellij/layouts/example-proj-name.local.kdl`
- tmux dashboard: `~/.config/tmux/pde.local.sh`
- tmux project launcher `example-proj-name`: `~/.config/tmux/example-proj-name.local.sh`

If a local override file exists, the launcher prefers it over the shared default. This lets each person keep personal pane setups without editing repo-tracked files.

Minimal tmux local override example:

```bash
mkdir -p ~/.config/tmux
cat > ~/.config/tmux/pde.local.sh <<'EOF'
setup_tmux_layout() {
  local session="$1"
  local project_dir="$2"

  tmux new-session -d -s "$session" -n terminal -c "$project_dir"
  tmux new-window -t "$session":2 -n editor -c "$project_dir"
  tmux send-keys -t "$session":2 "nvim ." C-m
  tmux new-window -t "$session":3 -n notes -c "$project_dir"
}
EOF
```

Minimal Zellij local override example:

```kdl
layout {
    tab name="terminal" focus=true {
        pane
    }
    tab name="editor" {
        pane command="zsh" {
            args "-lc" "nvim .; exec \"$SHELL\" -l"
        }
    }
    tab name="notes" {
        pane
    }
}
```

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
| `theme.zsh` | Theme-related shell helpers |

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
- generated project launchers from `pde-create` also write Zellij layout files under `~/.config/zellij/layouts/`
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

All scripts live in `bin/` and are symlinked to `~/bin/` by `bootstrap.sh`.

### `pde`

Main entry-point for this dotfiles repo.

Default dashboard windows/tabs: `terminal`, `editor`, `ai`, `git`, `k9s`.

```
pde                                Open multiplexer session for this repo
pde dashboard [-b <branch>] [-f]   Same as above, explicit subcommand form
pde [-b <branch>] [-f]             Open or create a worktree session for this repo
pde theme [theme-command]          Run `theme` through the main entry-point
pde install                        Run the setup wizard
pde -h                             Help
```

### `setup`

Interactive wizard run by `setup` or `pde install`. Steps through:

1. Package installation (`bootstrap.sh`)
2. Multiplexer choice (tmux / zellij) — saved to `~/.config/pde/prefs`
3. Terminal choice (kitty / ghostty / alacritty) — saved to `~/.config/pde/prefs`
4. AI choice (`codex+claude`, `codex`, `claude`, `custom`, `none`) — saved to `~/.config/pde/prefs`
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

### `pde-create`

Generate a project launcher script + matching Zellij layout. See [Project launcher](#project-launcher--pde-create).

### `pde-prefs`

Shared shell helper used by the launcher scripts and setup wizard to read and write per-user preferences from `~/.config/pde/prefs`.

### `install-optionals`

Installs optional AI tools based on the current AI profile in `~/.config/pde/prefs`. Supported automatic installs currently cover:

- `codex` via `@openai/codex`
- `claude` via `@anthropic-ai/claude-code`

Custom AI commands are not auto-installed; point them at an already installed binary or install that tool separately.


### `tmux-open-in-nvim`

Opens the file path under the tmux cursor in the nearest nvim instance in the current session.

### `ai-system-snapshot`

Generates a markdown snapshot of the current system state (packages, configs, tool versions) suitable for pasting into an AI context window.
