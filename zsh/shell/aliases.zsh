# Shell aliases

# Config dashboard
alias config="$HOME/bin/config"
alias ..="cd .."
alias ...="cd ../.."

# Prefer a modern file listing tool when available; otherwise enable colors on
# the platform's native ls.
if command -v eza >/dev/null 2>&1; then
  alias ls="eza --group-directories-first --icons=auto"
  alias ll="eza -la --group-directories-first --icons=auto --git"
  alias la="eza -a --group-directories-first --icons=auto"
  alias lt="eza --tree --level=2 --group-directories-first --icons=auto"
else
  case "$(uname -s)" in
    Darwin)
      alias ls="ls -GFh"
      ;;
    *)
      alias ls="ls --color=auto -Fh"
      ;;
  esac

  alias ll="ls -la"
  alias la="ls -a"
  alias lt="ls -laht"
fi

if [[ "${ENABLE_PANTS:-1}" == "1" ]]; then
  # Pants pre-push checks
  alias pre-push="pants fmt :: && pants fix :: && pants lint :: && pants check ::"
fi

# Git branches sorted by recent commit date
alias gbr="git branch --all --sort=-committerdate --format='%(committerdate:short) %(refname:short) %(authorname)'"
