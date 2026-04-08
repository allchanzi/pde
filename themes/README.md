# Themes

Theme definitions live here as shell files.

Available commands:

```sh
theme list
theme current
theme apply catppuccin-mocha
theme apply catppuccin-latte
theme apply dracula
theme apply nord
theme apply solarized-dark
theme apply solarized-light
theme apply tokyonight-night
theme apply synthwave-84
theme apply neon-cyberpunk
```

Each theme file defines a shared palette. The `theme` script generates:

- `alacritty/theme.toml`
- `tmux/theme.conf`
- `lazygit/config.yml`
- `nvim/lua/config/theme.lua`

The currently selected theme name is stored in `themes/current`.

Notes:

- Catppuccin themes use opaque Alacritty backgrounds so the terminal matches Neovim exactly.
- `neon-cyberpunk` keeps a transparent Alacritty background on purpose.
