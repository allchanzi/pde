# Powerlevel10k theme configuration

# Enable Powerlevel10k instant prompt. Should stay close to the top of ~/.zshrc.
# Initialization code that may require console input (password prompts, [y/n]
# confirmations, etc.) must go above this block; everything else may go below.
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

# Load Powerlevel10k theme
# Official install methods and their paths (from romkatv/powerlevel10k README):
#   brew install powerlevel10k  →  $HOMEBREW_PREFIX/share/powerlevel10k/powerlevel10k.zsh-theme
#   git clone ... ~/powerlevel10k  →  ~/powerlevel10k/powerlevel10k.zsh-theme
if [[ -f "${HOMEBREW_PREFIX:-}/share/powerlevel10k/powerlevel10k.zsh-theme" ]]; then
  source "${HOMEBREW_PREFIX}/share/powerlevel10k/powerlevel10k.zsh-theme"
elif [[ -f "$HOME/powerlevel10k/powerlevel10k.zsh-theme" ]]; then
  source "$HOME/powerlevel10k/powerlevel10k.zsh-theme"
fi

# To customize prompt, run `p10k configure` or edit ~/.p10k.zsh.
[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh
