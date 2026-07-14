#!/usr/bin/env bash
set -euo pipefail

PRESET_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(cd "$PRESET_DIR/../.." && pwd)"
ALLC_DIR="$ROOT_DIR/presets/allc"
DOCKER_PROFILE="${PDE_DOCKER_PROFILE:-allc}"

mkdir -p \
  "$HOME/bin" \
  "$HOME/.cache" \
  "$HOME/.cache/nvim" \
  "$HOME/.config/lazygit" \
  "$HOME/.config/pde" \
  "$HOME/.local/share" \
  "$HOME/.local/state"

case "$DOCKER_PROFILE" in
  allc|remote|python-pants-dev) ;;
  *)
    echo "Unsupported PDE_DOCKER_PROFILE: $DOCKER_PROFILE" >&2
    exit 1
    ;;
esac

ln -sfn "$ALLC_DIR/dotfiles/nvim" "$HOME/.config/nvim"
ln -sf "$ALLC_DIR/dotfiles/tmux/.tmux.conf" "$HOME/.tmux.conf"
ln -sf "$ALLC_DIR/dotfiles/tmux/theme.conf" "$HOME/.tmux.theme.conf"
ln -sf "$ALLC_DIR/dotfiles/lazygit/config.yml" "$HOME/.config/lazygit/config.yml"
ln -sf "$ALLC_DIR/dotfiles/lazygit/config.shared.yml" "$HOME/.config/lazygit/config.shared.yml"
ln -sfn "$ALLC_DIR/dotfiles/zsh/shell" "$HOME/.config/shell"
ln -sf "$PRESET_DIR/zshrc" "$HOME/.zshrc"

for command in \
  ai-system-snapshot \
  network-ports \
  pde \
  pde-prefs \
  pde-shortcuts-help \
  pde-version \
  pde-worktree \
  process-analyze \
  projects \
  run-and-return-to-shell \
  tmux-open-in-nvim
do
  ln -sf "$ROOT_DIR/bin/$command" "$HOME/bin/$command"
done

if [[ ! -f "$HOME/.config/pde/projects.json" ]]; then
  printf '{"projects": []}\n' > "$HOME/.config/pde/projects.json"
fi

if [[ ! -f "$HOME/.config/pde/prefs" ]]; then
  case "$DOCKER_PROFILE" in
    allc)
      cat > "$HOME/.config/pde/prefs" <<'EOF'
MULTIPLEXER='tmux'
ENABLE_PANTS='1'
AI_PROFILE='codex+claude'
AI_COMMAND_1='codex'
AI_COMMAND_2='claude'
EOF
      ;;
    remote)
      cat > "$HOME/.config/pde/prefs" <<'EOF'
MULTIPLEXER='tmux'
ENABLE_PANTS='0'
AI_PROFILE='none'
AI_COMMAND_1=''
AI_COMMAND_2=''
EOF
      ;;
    python-pants-dev)
      cat > "$HOME/.config/pde/prefs" <<'EOF'
MULTIPLEXER='tmux'
ENABLE_PANTS='1'
AI_PROFILE='none'
AI_COMMAND_1=''
AI_COMMAND_2=''
EOF
      ;;
  esac
fi
