# ~/.zshrc
# Main ZSH configuration file
# Modular configuration files are stored in ~/.config/shell/

# Shell configuration directory
SHELL_CONFIG_DIR="$HOME/.config/shell"

# Load theme configuration (must be loaded first for instant prompt)
[[ -f "$SHELL_CONFIG_DIR/theme.zsh" ]] && source "$SHELL_CONFIG_DIR/theme.zsh"

# Enable vi keybindings before other files bind keys (so they target viins)
[[ -f "$SHELL_CONFIG_DIR/vi-mode.zsh" ]] && source "$SHELL_CONFIG_DIR/vi-mode.zsh"

# Load environment variables and PATH
[[ -f "$SHELL_CONFIG_DIR/env.zsh" ]] && source "$SHELL_CONFIG_DIR/env.zsh"

# Load aliases
[[ -f "$SHELL_CONFIG_DIR/aliases.zsh" ]] && source "$SHELL_CONFIG_DIR/aliases.zsh"

# Load functions
[[ -f "$SHELL_CONFIG_DIR/functions.zsh" ]] && source "$SHELL_CONFIG_DIR/functions.zsh"

export PATH="$HOME/bin:$PATH"

[ -f ~/.fzf.zsh ] && source ~/.fzf.zsh

# Atuin — better Ctrl-R history window (local-only, no account/cloud).
# Loaded AFTER fzf so it owns Ctrl-R; --disable-up-arrow keeps the native
# up/down prefix-search bound in env.zsh.
if command -v atuin >/dev/null 2>&1; then
  eval "$(atuin init zsh --disable-up-arrow)"
fi

# Load machine-local overrides (not tracked in the preset; may not exist)
[[ -f "$SHELL_CONFIG_DIR/local.zsh" ]] && source "$SHELL_CONFIG_DIR/local.zsh"
