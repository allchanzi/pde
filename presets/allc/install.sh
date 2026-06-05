#!/usr/bin/env bash
set -euo pipefail

PRESET_DIR="$(cd "$(dirname "$0")" && pwd)"
CONFIG_DIR="$(cd "$PRESET_DIR/../.." && pwd)"
OS="$(uname -s)"
THEME_MODE="${PDE_ALLC_THEME_MODE:-preserve}"

usage() {
  cat <<'USAGE'
Usage:
  presets/allc/install.sh [--force-theme|--no-theme]

Theme modes:
  preserve / --no-theme   Link configs but do not re-apply theme-generated files.
  force / --force-theme   Apply presets/allc/themes/current during install.

Environment:
  PDE_ALLC_THEME_MODE=preserve|force|skip
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --force-theme)
      THEME_MODE="force"
      shift
      ;;
    --no-theme|--skip-theme)
      THEME_MODE="skip"
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      usage >&2
      exit 1
      ;;
  esac
done

case "$THEME_MODE" in
  preserve|skip|force) ;;
  *)
    echo "❌ Unsupported PDE_ALLC_THEME_MODE: $THEME_MODE" >&2
    usage >&2
    exit 1
    ;;
esac

echo "🚀 Starting setup..."

detect_brew_bin() {
  if command -v brew >/dev/null 2>&1; then
    command -v brew
    return 0
  fi

  if [[ -x /opt/homebrew/bin/brew ]]; then
    echo /opt/homebrew/bin/brew
  elif [[ -x /usr/local/bin/brew ]]; then
    echo /usr/local/bin/brew
  elif [[ -x /home/linuxbrew/.linuxbrew/bin/brew ]]; then
    echo /home/linuxbrew/.linuxbrew/bin/brew
  elif [[ -x "$HOME/.linuxbrew/bin/brew" ]]; then
    echo "$HOME/.linuxbrew/bin/brew"
  else
    return 1
  fi
}

macos_casks() {
  awk '
    $1 == "cask" {
      gsub(/"/, "", $2)
      print $2
    }
  ' "$PRESET_DIR/Brewfile.macOS"
}

install_macos_cask() {
  local cask_name="$1"
  local log_file

  log_file="$(mktemp)"

  if brew list --cask "$cask_name" >/dev/null 2>&1; then
    echo "Using $cask_name"
    if brew upgrade --cask "$cask_name" >"$log_file" 2>&1; then
      rm -f "$log_file"
      return 0
    fi
  else
    echo "Installing $cask_name"
    if brew install --cask "$cask_name" >"$log_file" 2>&1; then
      rm -f "$log_file"
      return 0
    fi
  fi

  if [[ "$cask_name" == "kitty" ]] && grep -q "already an App at" "$log_file"; then
    echo "⚠️ Resolving kitty app conflict with forced reinstall..."
    brew uninstall --cask --force kitty >/dev/null 2>&1 || true
    if brew install --cask kitty; then
      rm -f "$log_file"
      return 0
    fi
  fi

  cat "$log_file" >&2
  rm -f "$log_file"
  return 1
}

install_macos_casks() {
  local failed=0
  local failed_casks=()
  local cask_name

  while IFS= read -r cask_name; do
    [[ -n "$cask_name" ]] || continue
    if ! install_macos_cask "$cask_name"; then
      failed=1
      failed_casks+=("$cask_name")
    fi
  done < <(macos_casks)

  if [[ "$failed" -eq 1 ]]; then
    echo ""
    echo "❌ Some macOS casks failed: ${failed_casks[*]}" >&2
    return 1
  fi
}

########################################
# Install Homebrew if missing
########################################

if ! command -v brew >/dev/null 2>&1; then
  echo "📦 Homebrew not found. Installing..."

  NONINTERACTIVE=1 /bin/bash -c \
    "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
fi

########################################
# Load brew into current shell
########################################

if [[ "$OS" != "Darwin" && "$OS" != "Linux" ]]; then
  echo "❌ Unsupported OS: $OS"
  exit 1
fi

BREW_BIN="$(detect_brew_bin)" || {
  echo "❌ brew installed but not found in expected locations"
  exit 1
}

eval "$("$BREW_BIN" shellenv)"

echo "🍺 Using brew: $(command -v brew)"

########################################
# Install packages from Brewfile
########################################

echo "📦 Installing packages from Brewfile..."
brew bundle --file="$PRESET_DIR/Brewfile"

if [[ "$OS" == "Darwin" && -f "$PRESET_DIR/Brewfile.macOS" ]]; then
  echo "🍎 Installing macOS-only packages from Brewfile.macOS..."
  install_macos_casks

  if [[ -x /usr/libexec/path_helper ]]; then
    eval "$(/usr/libexec/path_helper)"
  fi
fi

if ! command -v latexmk >/dev/null 2>&1; then
  if [[ "$OS" == "Darwin" ]]; then
    echo "ℹ️ latexmk is provided by BasicTeX/MacTeX rather than Homebrew."
    echo '   If it is still unavailable in a new shell, run: eval "$(/usr/libexec/path_helper)"'
  else
    echo "ℹ️ latexmk is provided by your TeX distribution."
    echo "   Install TeX Live or your distro's latexmk package if you need it."
  fi
fi

########################################
# Create directories
########################################

echo "📁 Creating directories..."
mkdir -p "$HOME/.config"
mkdir -p "$HOME/bin"
mkdir -p "$HOME/.config/pde"

if [[ "$OS" == "Darwin" ]]; then
  mkdir -p "$HOME/Library/Application Support"
  LAZYGIT_CONFIG_DIR="$HOME/Library/Application Support/lazygit"
  K9S_CONFIG_DIR="$HOME/Library/Application Support/k9s"
else
  LAZYGIT_CONFIG_DIR="$HOME/.config/lazygit"
  K9S_CONFIG_DIR="$HOME/.config/k9s"
fi

########################################
# Backup existing files if they are not symlinks
########################################

backup_if_needed() {
  local target="$1"
  if [[ -e "$target" && ! -L "$target" ]]; then
    local backup="${target}.backup.$(date +%Y%m%d%H%M%S)"
    echo "📦 Backing up $target -> $backup"
    mv "$target" "$backup"
  fi
}

ensure_runtime_config_dir() {
  local target="$1"
  if [[ -L "$target" ]]; then
    rm -f "$target"
  fi
  mkdir -p "$target"
}

backup_if_needed "$HOME/.config/alacritty"
backup_if_needed "$HOME/.config/kitty"
backup_if_needed "$HOME/.config/ghostty"
backup_if_needed "$HOME/.config/btop/btop.conf"
backup_if_needed "$HOME/.config/zellij"
backup_if_needed "$HOME/.config/nvim"
backup_if_needed "$HOME/.tmux.conf"
backup_if_needed "$HOME/.tmux.theme.conf"
backup_if_needed "$HOME/.zshrc"
backup_if_needed "$HOME/.config/shell"
backup_if_needed "$LAZYGIT_CONFIG_DIR"
backup_if_needed "$K9S_CONFIG_DIR"
backup_if_needed "$HOME/bin/pde"
backup_if_needed "$HOME/bin/pde-tui"
backup_if_needed "$HOME/bin/projects"
backup_if_needed "$HOME/bin/pde-worktree"
backup_if_needed "$HOME/bin/theme"
backup_if_needed "$HOME/bin/ai-system-snapshot"
backup_if_needed "$HOME/bin/pde-prefs"
backup_if_needed "$HOME/bin/install-optionals"
backup_if_needed "$HOME/bin/pde-update"
backup_if_needed "$HOME/bin/tmux-open-in-nvim"
backup_if_needed "$HOME/bin/setup"

########################################
# Symlinks
########################################

echo "🔗 Linking configs..."

ln -sfn "$PRESET_DIR/dotfiles/alacritty" "$HOME/.config/alacritty"
ln -sfn "$PRESET_DIR/dotfiles/kitty" "$HOME/.config/kitty"
ln -sfn "$PRESET_DIR/dotfiles/ghostty" "$HOME/.config/ghostty"
mkdir -p "$HOME/.config/btop/themes"
ln -sf "$PRESET_DIR/dotfiles/btop/btop.conf" "$HOME/.config/btop/btop.conf"
ln -sfn "$PRESET_DIR/dotfiles/zellij" "$HOME/.config/zellij"
ln -sfn "$PRESET_DIR/dotfiles/nvim" "$HOME/.config/nvim"
ln -sf "$PRESET_DIR/dotfiles/tmux/.tmux.conf" "$HOME/.tmux.conf"
ln -sf "$PRESET_DIR/dotfiles/tmux/theme.conf" "$HOME/.tmux.theme.conf"
ln -sf "$PRESET_DIR/dotfiles/zsh/.zshrc" "$HOME/.zshrc"
ln -sfn "$PRESET_DIR/dotfiles/zsh/shell" "$HOME/.config/shell"
ensure_runtime_config_dir "$LAZYGIT_CONFIG_DIR"
ln -sf "$PRESET_DIR/dotfiles/lazygit/config.yml" "$LAZYGIT_CONFIG_DIR/config.yml"
ln -sf "$PRESET_DIR/dotfiles/lazygit/config.shared.yml" "$LAZYGIT_CONFIG_DIR/config.shared.yml"

ensure_runtime_config_dir "$K9S_CONFIG_DIR"
ln -sf "$PRESET_DIR/dotfiles/k9s/config.yaml" "$K9S_CONFIG_DIR/config.yaml"
ln -sf "$PRESET_DIR/dotfiles/k9s/aliases.yaml" "$K9S_CONFIG_DIR/aliases.yaml"
mkdir -p "$K9S_CONFIG_DIR/skins"
ln -sf "$PRESET_DIR/dotfiles/k9s/skins/dotfiles.yaml" "$K9S_CONFIG_DIR/skins/dotfiles.yaml"
ln -sf "$CONFIG_DIR/bin/pde" "$HOME/bin/pde"
ln -sf "$CONFIG_DIR/bin/projects" "$HOME/bin/projects"
ln -sf "$CONFIG_DIR/bin/pde-worktree" "$HOME/bin/pde-worktree"
ln -sf "$CONFIG_DIR/bin/theme" "$HOME/bin/theme"
ln -sf "$CONFIG_DIR/bin/ai-system-snapshot" "$HOME/bin/ai-system-snapshot"
ln -sf "$CONFIG_DIR/bin/pde-prefs" "$HOME/bin/pde-prefs"
ln -sf "$CONFIG_DIR/bin/install-optionals" "$HOME/bin/install-optionals"
ln -sf "$CONFIG_DIR/bin/pde-update" "$HOME/bin/pde-update"
ln -sf "$CONFIG_DIR/bin/network-ports" "$HOME/bin/network-ports"
ln -sf "$CONFIG_DIR/bin/run-and-return-to-shell" "$HOME/bin/run-and-return-to-shell"
ln -sf "$CONFIG_DIR/bin/tmux-open-in-nvim" "$HOME/bin/tmux-open-in-nvim"
ln -sf "$CONFIG_DIR/bin/setup" "$HOME/bin/setup"

########################################
# App build
########################################

echo "ℹ️ Skipping PDE app build in allc preset; run root ./install.sh for app wrappers."

########################################
# Apply active theme
########################################

case "$THEME_MODE" in
  force)
    if [[ -x "$HOME/bin/theme" ]]; then
      echo "🎨 Applying allc current theme..."
      PDE_THEMES_DIR="$PRESET_DIR/themes" "$HOME/bin/theme" apply current >/dev/null 2>&1 || true
    fi
    ;;
  preserve|skip)
    echo "🎨 Preserving theme state. Use --force-theme or PDE_ALLC_THEME_MODE=force to apply presets/allc/themes/current."
    ;;
esac

if [[ -x "$HOME/bin/pde-prefs" ]]; then
  # shellcheck source=/dev/null
  source "$HOME/bin/pde-prefs"
  pde_prefs_migrate
fi

########################################
# fzf shell integration
########################################

if command -v fzf >/dev/null 2>&1; then
  echo "⚡ Setting up fzf shell integration..."
  if [[ -x "$(brew --prefix)/opt/fzf/install" ]]; then
    "$(brew --prefix)/opt/fzf/install" --all --no-bash --no-fish || true
  fi
fi

########################################
# Reload tmux config if tmux is running
########################################

tmux source-file "$HOME/.tmux.conf" 2>/dev/null || true

########################################
# Install Neovim plugins
########################################

if command -v nvim >/dev/null 2>&1; then
  echo "🧠 Installing Neovim plugins..."
  nvim --headless "+Lazy! sync" +qa 2>/dev/null || true
fi

if [[ -x "$HOME/bin/install-optionals" ]]; then
  "$HOME/bin/install-optionals" || true
fi

########################################
# Persist brew shellenv for future shells
########################################

ZPROFILE="$HOME/.zprofile"

printf -v BREW_SHELLENV_LINE 'eval "$(%q shellenv)"' "$BREW_BIN"

if [[ ! -f "$ZPROFILE" ]] || ! grep -Fq "$BREW_SHELLENV_LINE" "$ZPROFILE"; then
  echo "📝 Adding brew shellenv to $ZPROFILE"
  echo "$BREW_SHELLENV_LINE" >> "$ZPROFILE"
fi

########################################
# Done
########################################

echo ""
echo "✅ Setup complete!"
echo ""
echo "Next steps:"
echo "  1. Restart terminal"
echo "  2. source ~/.zshrc"
echo "  3. pde                 # open the Rust TUI"
