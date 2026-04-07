# Shell aliases

# Config dashboard
alias config="$HOME/bin/config"
alias ll="ls -lah"
alias ..="cd .."
alias ...="cd ../.."

if [[ "${ENABLE_PANTS:-1}" == "1" ]]; then
  # Pants pre-push checks
  alias pre-push="pants fmt :: && pants fix :: && pants lint :: && pants check ::"
fi

# Git branches sorted by recent commit date
alias gbr="git branch --all --sort=-committerdate --format='%(committerdate:short) %(refname:short) %(authorname)'"
