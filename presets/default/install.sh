#!/usr/bin/env bash
set -euo pipefail

CONFIG_DIR="${PDE_CONFIG_DIR:-$HOME/.config/pde}"
PROJECTS_FILE="${PDE_PROJECTS_FILE:-$CONFIG_DIR/projects.json}"
PREFS_FILE="${PDE_PREFS_FILE_DEFAULT:-$CONFIG_DIR/prefs}"

mkdir -p "$CONFIG_DIR"

if [[ ! -f "$PROJECTS_FILE" ]]; then
  printf '{"projects": []}\n' > "$PROJECTS_FILE"
fi

has_tmux=0
has_zellij=0
command -v tmux >/dev/null 2>&1 && has_tmux=1
command -v zellij >/dev/null 2>&1 && has_zellij=1

if [[ "$has_tmux" -eq 0 && "$has_zellij" -eq 0 ]]; then
  cat >&2 <<'MSG'
❌ PDE requires at least one multiplexer installed: tmux or zellij.
Install one of them, then re-run install:
  brew install tmux
  brew install zellij
MSG
  exit 1
fi

if [[ ! -f "$PREFS_FILE" ]]; then
  if [[ "$has_zellij" -eq 1 ]]; then
    printf "MULTIPLEXER='zellij'\n" > "$PREFS_FILE"
  else
    printf "MULTIPLEXER='tmux'\n" > "$PREFS_FILE"
  fi
fi

echo "✅ default preset ready: $CONFIG_DIR"
