# Custom shell functions

# Git worktree manager - creates/opens worktrees for branches
# Usage: gg [-f] <branch>
#   -f: force recreate worktree if it already exists
gg() {
  local force=0

  if [ "$1" = "-f" ]; then
    force=1
    shift
  fi

  if [ -z "$1" ]; then
    echo "Usage: gg [-f] <branch>"
    return 1
  fi

  local branch="$1"
  local repo_root
  repo_root="$(git rev-parse --show-toplevel 2>/dev/null)" || {
    echo "Not inside a git repository."
    return 1
  }

  cd "$repo_root" || return 1

  # Check if branch already has a worktree
  local existing_path
  existing_path="$(
    git worktree list --porcelain | awk -v b="refs/heads/$branch" '
      $1=="worktree" { p=$2 }
      $1=="branch" && $2==b { print p }
    '
  )"

  if [ -n "$existing_path" ] && [ "$force" -eq 0 ]; then
    echo "Branch '$branch' already has a worktree at $existing_path"
    cd "$existing_path"
    return $?
  fi

  if [ -n "$existing_path" ] && [ "$force" -eq 1 ]; then
    echo "Removing existing worktree for '$branch' at $existing_path..."
    git worktree remove --force "$existing_path" || true
    rm -rf "$existing_path"
  fi

  # Compute new worktree path
  local repo_name
  repo_name="$(basename "$repo_root")"
  local safe_branch="${branch//\//-}"
  local worktree_root
  worktree_root="$(dirname "$repo_root")"
  local worktree_path="$worktree_root/${repo_name}-${safe_branch}"

  git fetch origin "$branch" --prune 2>/dev/null || true
  echo "Creating worktree for branch '$branch' at $worktree_path..."
  git worktree add "$worktree_path" "$branch" || return 1

  cd "$worktree_path"
}

# Pick a command from shell history with fzf and run it immediately.
fzf-history-run-widget() {
  emulate -L zsh
  setopt extendedglob

  if ! command -v fzf >/dev/null 2>&1; then
    zle -M "fzf is not installed"
    return 1
  fi

  local selected
  selected="$(
    fc -rl 1 |
      sed -E 's/^[[:space:]]*[0-9]+[[:space:]]+//' |
      awk 'NF && !seen[$0]++' |
      fzf --height=40% --reverse --border \
        --prompt='History> ' \
        --query="$LBUFFER" \
        --no-sort \
        --bind='enter:accept'
  )"

  if [[ -z "$selected" ]]; then
    zle redisplay
    return 0
  fi

  BUFFER="$selected"
  CURSOR=${#BUFFER}
  zle accept-line
}

zle -N fzf-history-run-widget
bindkey '^[h' fzf-history-run-widget
