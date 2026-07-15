#!/usr/bin/env bash
set -euo pipefail

SCRIPT_PATH="${BASH_SOURCE[0]}"
while [[ -L "$SCRIPT_PATH" ]]; do
  LINK_TARGET="$(readlink "$SCRIPT_PATH")"
  if [[ "$LINK_TARGET" == /* ]]; then
    SCRIPT_PATH="$LINK_TARGET"
  else
    SCRIPT_DIR="$(cd "$(dirname "$SCRIPT_PATH")" && pwd)"
    SCRIPT_PATH="$SCRIPT_DIR/$LINK_TARGET"
  fi
done

CONFIG_DIR="$(cd "$(dirname "$SCRIPT_PATH")/../.." && pwd)"
PRESET_DIR="${PDE_PRESET_DIR:-$CONFIG_DIR/presets/allc}"
DOTFILES_DIR="${PDE_DOTFILES_DIR:-$PRESET_DIR/dotfiles}"
THEMES_DIR="${PDE_THEMES_DIR:-$PRESET_DIR/themes}"
CURRENT_FILE="$THEMES_DIR/current"
CATPPUCCIN_CACHE="$HOME/.cache/catppuccin"

_sed_i() {
  if [[ "$OSTYPE" == darwin* ]]; then
    sed -i '' "$@"
  else
    sed -i "$@"
  fi
}

_resolve_path() {
  local path="$1"

  while [[ -L "$path" ]]; do
    local link_target
    link_target="$(readlink "$path")"
    if [[ "$link_target" == /* ]]; then
      path="$link_target"
    else
      path="$(cd "$(dirname "$path")" && pwd)/$link_target"
    fi
  done

  printf '%s\n' "$path"
}

usage() {
  cat <<'USAGE'
Usage:
  theme               Interactive picker (arrow keys + Enter)
  theme list          List available themes
  theme current       Show active theme
  theme apply <name>  Apply theme directly
  theme update        Download latest catppuccin configs from GitHub

Examples:
  theme
  theme update
  theme apply catppuccin-mocha
USAGE
}

update_catppuccin() {
  if ! command -v curl >/dev/null 2>&1; then
    echo "curl not found" >&2; exit 1
  fi

  echo "Downloading catppuccin themes from GitHub..."
  mkdir -p "$CATPPUCCIN_CACHE"

  local base="https://raw.githubusercontent.com/catppuccin"

  for flavor in mocha latte; do
    curl -fsSL "$base/kitty/main/themes/${flavor}.conf" -o "$CATPPUCCIN_CACHE/kitty-${flavor}.conf"
    curl -fsSL "$base/ghostty/main/themes/catppuccin-${flavor}.conf" -o "$CATPPUCCIN_CACHE/ghostty-${flavor}.conf"
    curl -fsSL "$base/alacritty/main/catppuccin-${flavor}.toml" -o "$CATPPUCCIN_CACHE/alacritty-${flavor}.toml"
    curl -fsSL "$base/zsh-syntax-highlighting/main/themes/catppuccin_${flavor}-zsh-syntax-highlighting.zsh" -o "$CATPPUCCIN_CACHE/zsh-syntax-${flavor}.zsh"
    curl -fsSL "$base/fzf/main/themes/catppuccin-fzf-${flavor}.sh" -o "$CATPPUCCIN_CACHE/fzf-${flavor}.sh"
    curl -fsSL "$base/lazygit/main/themes/${flavor}/blue.yml" -o "$CATPPUCCIN_CACHE/lazygit-${flavor}.yml"
    curl -fsSL "$base/btop/main/themes/catppuccin_${flavor}.theme" -o "$CATPPUCCIN_CACHE/btop-${flavor}.theme"
  done

  echo "Done. Cached to $CATPPUCCIN_CACHE"
}

list_themes() {
  find "$THEMES_DIR" -maxdepth 1 -type f -name '*.sh' -print | sed 's#.*/##' | sed 's/\.sh$//' | sort
}

load_theme() {
  local theme_name="$1"
  local theme_file="$THEMES_DIR/$theme_name.sh"

  if [[ ! -f "$theme_file" ]]; then
    echo "Unknown theme: $theme_name" >&2
    exit 1
  fi

  # shellcheck disable=SC1090
  source "$theme_file"
}

_theme_apply_impl() {
  write_alacritty_theme
  write_kitty_theme
  write_ghostty_theme
  write_tmux_theme
  write_zellij_theme
  write_lazygit_config
  write_nvim_theme
  write_zsh_syntax_theme
  write_fzf_theme
  write_p10k_theme
  write_btop_theme
  write_k9s_theme

  printf '%s\n' "$THEME_NAME" > "$CURRENT_FILE"

  touch "$DOTFILES_DIR/alacritty/alacritty.toml"
  touch "$HOME/.config/alacritty/alacritty.toml" 2>/dev/null || true
  kill -SIGUSR1 "$(pgrep -x kitty)" 2>/dev/null || true
  tmux source-file "$HOME/.tmux.conf" 2>/dev/null || true

  echo "Applied theme: $THEME_NAME"
  echo "Kitty reloaded automatically."
  echo "Alacritty reloads automatically; if not, reopen the window."
  echo "Ghostty requires restart for full palette reload."
  echo "Zellij picks up theme changes after detach/reattach or a fresh session start."
  echo "Restart Neovim sessions to pick up the new theme cleanly."
  echo "Restart btop to pick up the new theme."
  echo "Restart k9s to pick up the new skin if it is already running."
}

pick_theme() {
  if ! command -v fzf >/dev/null 2>&1; then
    echo "fzf not found — install it or use: theme apply <name>" >&2
    exit 1
  fi

  local current=""
  [[ -f "$CURRENT_FILE" ]] && current="$(cat "$CURRENT_FILE")"

  local themes=()
  [[ -n "$current" ]] && themes+=("$current")
  while IFS= read -r t; do
    [[ "$t" != "$current" ]] && themes+=("$t")
  done < <(list_themes)

  local selected
  selected=$(printf '%s\n' "${themes[@]}" | fzf --prompt="  Theme: " --pointer="▶" --highlight-line --no-info --height=~10 --border=rounded --border-label=" Themes ")

  [[ -z "$selected" ]] && exit 0
  load_theme "$selected"
  _theme_apply_impl
}

apply_theme() {
  local theme_name="$1"
  load_theme "$theme_name"
  _theme_apply_impl
}
