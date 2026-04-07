#!/usr/bin/env bash
set -euo pipefail

echo "🚀 Starting setup..."

CONFIG_DIR="$(cd "$(dirname "$0")" && pwd)"
OS="$(uname -s)"

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

if [[ "$OS" == "Darwin" ]]; then
  if [[ -x /opt/homebrew/bin/brew ]]; then
    eval "$(/opt/homebrew/bin/brew shellenv)"
  elif [[ -x /usr/local/bin/brew ]]; then
    eval "$(/usr/local/bin/brew shellenv)"
  else
    echo "❌ brew installed but not found in expected macOS locations"
    exit 1
  fi
elif [[ "$OS" == "Linux" ]]; then
  if [[ -x /home/linuxbrew/.linuxbrew/bin/brew ]]; then
    eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
  elif [[ -x "$HOME/.linuxbrew/bin/brew" ]]; then
    eval "$("$HOME/.linuxbrew/bin/brew" shellenv)"
  else
    echo "❌ brew installed but not found in expected Linux locations"
    exit 1
  fi
else
  echo "❌ Unsupported OS: $OS"
  exit 1
fi

echo "🍺 Using brew: $(command -v brew)"

########################################
# Install packages from Brewfile
########################################

echo "📦 Installing packages from Brewfile..."
brew bundle --file="$CONFIG_DIR/Brewfile"

if [[ "$OS" == "Darwin" && -f "$CONFIG_DIR/Brewfile.macOS" ]]; then
  echo "🍎 Installing macOS-only packages from Brewfile.macOS..."
  brew bundle --file="$CONFIG_DIR/Brewfile.macOS"
fi

########################################
# Create directories
########################################

echo "📁 Creating directories..."
mkdir -p "$HOME/.config"
mkdir -p "$HOME/bin"
mkdir -p "$HOME/.config/config"

if [[ "$OS" == "Darwin" ]]; then
  mkdir -p "$HOME/Library/Application Support"
  LAZYGIT_CONFIG_DIR="$HOME/Library/Application Support/lazygit"
else
  LAZYGIT_CONFIG_DIR="$HOME/.config/lazygit"
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
backup_if_needed "$HOME/bin/config"
backup_if_needed "$HOME/bin/mkproj"
backup_if_needed "$HOME/bin/theme"
backup_if_needed "$HOME/bin/ai-system-snapshot"
backup_if_needed "$HOME/bin/config-prefs"
backup_if_needed "$HOME/bin/install-optionals"
backup_if_needed "$HOME/bin/tmux-open-in-nvim"
backup_if_needed "$HOME/bin/setup"

########################################
# Symlinks
########################################

echo "🔗 Linking configs..."

ln -sfn "$CONFIG_DIR/alacritty" "$HOME/.config/alacritty"
ln -sfn "$CONFIG_DIR/kitty" "$HOME/.config/kitty"
ln -sfn "$CONFIG_DIR/ghostty" "$HOME/.config/ghostty"
mkdir -p "$HOME/.config/btop/themes"
ln -sf "$CONFIG_DIR/btop/btop.conf" "$HOME/.config/btop/btop.conf"
ln -sfn "$CONFIG_DIR/zellij" "$HOME/.config/zellij"
ln -sfn "$CONFIG_DIR/nvim" "$HOME/.config/nvim"
ln -sf "$CONFIG_DIR/tmux/.tmux.conf" "$HOME/.tmux.conf"
ln -sf "$CONFIG_DIR/tmux/theme.conf" "$HOME/.tmux.theme.conf"
ln -sf "$CONFIG_DIR/zsh/.zshrc" "$HOME/.zshrc"
ln -sfn "$CONFIG_DIR/zsh/shell" "$HOME/.config/shell"
ln -sfn "$CONFIG_DIR/lazygit" "$LAZYGIT_CONFIG_DIR"
ln -sf "$CONFIG_DIR/bin/config" "$HOME/bin/config"
ln -sf "$CONFIG_DIR/bin/mkproj" "$HOME/bin/mkproj"
ln -sf "$CONFIG_DIR/bin/theme" "$HOME/bin/theme"
ln -sf "$CONFIG_DIR/bin/ai-system-snapshot" "$HOME/bin/ai-system-snapshot"
ln -sf "$CONFIG_DIR/bin/config-prefs" "$HOME/bin/config-prefs"
ln -sf "$CONFIG_DIR/bin/install-optionals" "$HOME/bin/install-optionals"
ln -sf "$CONFIG_DIR/bin/network-ports" "$HOME/bin/network-ports"
ln -sf "$CONFIG_DIR/bin/run-and-return-to-shell" "$HOME/bin/run-and-return-to-shell"
ln -sf "$CONFIG_DIR/bin/tmux-open-in-nvim" "$HOME/bin/tmux-open-in-nvim"
ln -sf "$CONFIG_DIR/bin/setup" "$HOME/bin/setup"

chmod +x "$HOME/bin/config"
chmod +x "$HOME/bin/mkproj"
chmod +x "$HOME/bin/theme"
chmod +x "$HOME/bin/ai-system-snapshot"
chmod +x "$HOME/bin/config-prefs"
chmod +x "$HOME/bin/install-optionals"
chmod +x "$HOME/bin/network-ports"
chmod +x "$HOME/bin/run-and-return-to-shell"
chmod +x "$HOME/bin/tmux-open-in-nvim"
chmod +x "$HOME/bin/setup"

########################################
# Apply active theme
########################################

if [[ -x "$HOME/bin/theme" ]]; then
  "$HOME/bin/theme" apply current >/dev/null 2>&1 || true
fi

if [[ -x "$HOME/bin/config-prefs" ]]; then
  # shellcheck source=/dev/null
  source "$HOME/bin/config-prefs"
  config_prefs_migrate
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

if [[ "$OS" == "Darwin" ]]; then
  BREW_SHELLENV_LINE='eval "$(/opt/homebrew/bin/brew shellenv)"'
else
  if [[ -x /home/linuxbrew/.linuxbrew/bin/brew ]]; then
    BREW_SHELLENV_LINE='eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"'
  else
    BREW_SHELLENV_LINE='eval "$($HOME/.linuxbrew/bin/brew shellenv)"'
  fi
fi

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
echo "  3. mkproj <name> <path>   # create a project launcher"
