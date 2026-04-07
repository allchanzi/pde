# Environment variables and PATH configuration

# Per-user config prefs (outside the repo-tracked shell config)
if [[ -f "$HOME/.config/config/prefs" ]]; then
  source "$HOME/.config/config/prefs"
elif [[ -f "$HOME/.config/shell/prefs" ]]; then
  source "$HOME/.config/shell/prefs"
fi

# Pants
if [[ "${ENABLE_PANTS:-1}" == "1" ]]; then
  export PANTS_CONCURRENT=True
fi

# Pyenv — lazy init (runs only when python/pyenv is first called)
export PATH="$HOME/.pyenv/bin:$PATH"
export PYENV_ROOT="$HOME/.pyenv"

pyenv() {
  unfunction pyenv
  eval "$(command pyenv init -)"
  pyenv "$@"
}

# Local bin
export PATH="$HOME/.local/bin:$PATH"

# Chrome (macOS only)
if [[ "$OSTYPE" == darwin* && -x "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome" ]]; then
  export CHROME_EXECUTABLE="/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
fi

# Java (OpenJDK via Homebrew — brew --prefix openjdk@N per official caveats)
# Works on macOS and Linux Homebrew via $HOMEBREW_PREFIX set by brew shellenv
if [[ -n "${HOMEBREW_PREFIX:-}" ]]; then
  [[ -d "$HOMEBREW_PREFIX/opt/openjdk@21/bin" ]] && export PATH="$HOMEBREW_PREFIX/opt/openjdk@21/bin:$PATH"
  [[ -d "$HOMEBREW_PREFIX/opt/openjdk@17/bin" ]] && export PATH="$HOMEBREW_PREFIX/opt/openjdk@17/bin:$PATH"
fi

# History
HISTFILE="$HOME/.zsh_history"
HISTSIZE=50000
SAVEHIST=50000

setopt HIST_IGNORE_DUPS
setopt HIST_IGNORE_ALL_DUPS
setopt HIST_IGNORE_SPACE
setopt HIST_REDUCE_BLANKS
setopt SHARE_HISTORY
setopt EXTENDED_HISTORY
setopt INC_APPEND_HISTORY

# Better history navigation by typed prefix
autoload -U up-line-or-beginning-search
autoload -U down-line-or-beginning-search
zle -N up-line-or-beginning-search
zle -N down-line-or-beginning-search
bindkey '^[[A' up-line-or-beginning-search
bindkey '^[[B' down-line-or-beginning-search

# fzf — loaded via ~/.fzf.zsh in .zshrc, skip duplicate

# Catppuccin zsh-syntax-highlighting theme
[[ -f "$HOME/.config/shell/catppuccin-syntax.zsh" ]] && source "$HOME/.config/shell/catppuccin-syntax.zsh"

# Catppuccin fzf theme
[[ -f "$HOME/.config/shell/catppuccin-fzf.zsh" ]] && source "$HOME/.config/shell/catppuccin-fzf.zsh"

# zsh-autosuggestions
# Homebrew install path per official README: $(brew --prefix)/share/zsh-autosuggestions/...
# $HOMEBREW_PREFIX is set by `brew shellenv` in .zprofile (works on macOS + Linux Homebrew)
_zsh_autosuggest="${HOMEBREW_PREFIX:-}/share/zsh-autosuggestions/zsh-autosuggestions.zsh"
if [[ -f "$_zsh_autosuggest" ]]; then
  source "$_zsh_autosuggest"
  ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE='fg=#6c7086'
fi
unset _zsh_autosuggest

# zsh-syntax-highlighting
# Homebrew install path per official README: $(brew --prefix)/share/zsh-syntax-highlighting/...
_zsh_syntax="${HOMEBREW_PREFIX:-}/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh"
[[ -f "$_zsh_syntax" ]] && source "$_zsh_syntax"
unset _zsh_syntax
