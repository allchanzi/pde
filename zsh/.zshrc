# ~/.zshrc
# Main ZSH configuration file
# Modular configuration files are stored in ~/.config/shell/

# Shell configuration directory
SHELL_CONFIG_DIR="$HOME/.config/shell"

# Load theme configuration (must be loaded first for instant prompt)
[[ -f "$SHELL_CONFIG_DIR/theme.zsh" ]] && source "$SHELL_CONFIG_DIR/theme.zsh"

# Load environment variables and PATH
[[ -f "$SHELL_CONFIG_DIR/env.zsh" ]] && source "$SHELL_CONFIG_DIR/env.zsh"

# Load aliases
[[ -f "$SHELL_CONFIG_DIR/aliases.zsh" ]] && source "$SHELL_CONFIG_DIR/aliases.zsh"

# Load functions
[[ -f "$SHELL_CONFIG_DIR/functions.zsh" ]] && source "$SHELL_CONFIG_DIR/functions.zsh"

export PATH="$HOME/bin:$PATH"

[ -f ~/.fzf.zsh ] && source ~/.fzf.zsh
