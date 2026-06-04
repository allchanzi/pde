# Vi keybindings for the ZSH command line.
# Sourced before env.zsh/functions.zsh so their custom `bindkey` calls land on
# the `viins` keymap instead of the default emacs one.

# Enable vi editing mode (the main keymap becomes `viins`).
bindkey -v

# Fast <Esc> mode switch, but keep enough time for terminals/mouse tools that
# send Alt/meta shortcuts as an Esc-prefixed sequence.
export KEYTIMEOUT=20

# Keep familiar editing keys that plain vi insert mode otherwise drops.
bindkey -M viins '^?' backward-delete-char      # Backspace past the insert point
bindkey -M viins '^H' backward-delete-char      # Ctrl-H
bindkey -M viins '^A' beginning-of-line
bindkey -M viins '^E' end-of-line
bindkey -M viins '^K' kill-line
bindkey -M viins '^U' backward-kill-line
bindkey -M viins '^W' backward-kill-word
bindkey -M viins '^R' history-incremental-search-backward
bindkey -M vicmd '/'  history-incremental-search-backward

# `v` in command mode opens the current command line in $EDITOR (nvim).
autoload -Uz edit-command-line
zle -N edit-command-line
bindkey -M vicmd 'v' edit-command-line

# Cursor shape tracks the active mode: block in command, beam in insert.
# Use add-zle-hook-widget so this coexists with Powerlevel10k's own zle hooks.
_pde_vi_cursor_select() {
  case "${KEYMAP}" in
    vicmd)         print -n '\e[2 q' ;;   # block
    viins|main|'') print -n '\e[6 q' ;;   # beam
  esac
}

_pde_vi_cursor_init() {
  print -n '\e[6 q'                       # each new prompt starts in insert mode
}

autoload -Uz add-zle-hook-widget
add-zle-hook-widget zle-keymap-select _pde_vi_cursor_select
add-zle-hook-widget zle-line-init _pde_vi_cursor_init
