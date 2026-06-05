#!/usr/bin/env bash
set -euo pipefail

CONFIG_DIR="$(cd "$(dirname "$0")" && pwd)"
PRESET="${PDE_PRESET:-default}"
BIN_DIR="${PDE_BIN_DIR:-$HOME/bin}"
PRESET_ARGS=()

usage() {
  cat <<USAGE
Usage:
  ./install.sh [--preset default|allc] [--force-theme|--no-theme]

Theme flags are only used by --preset allc.

Installs the PDE app/wrappers and runs the selected preset.
Default preset only verifies tmux/zellij and creates empty PDE config.
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --preset)
      PRESET="${2:-}"
      [[ -n "$PRESET" ]] || { usage; exit 1; }
      shift 2
      ;;
    --force-theme|--no-theme)
      PRESET_ARGS+=("$1")
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

if [[ "$PRESET" != "allc" && "${#PRESET_ARGS[@]}" -gt 0 ]]; then
  echo "❌ Theme flags are only supported with --preset allc" >&2
  usage >&2
  exit 1
fi

mkdir -p "$BIN_DIR" "$HOME/.config/pde"

backup_if_needed() {
  local target="$1"
  if [[ -e "$target" && ! -L "$target" ]]; then
    local backup="${target}.backup.$(date +%Y%m%d%H%M%S)"
    echo "📦 Backing up $target -> $backup"
    mv "$target" "$backup"
  fi
}

backup_if_needed "$BIN_DIR/pde"
backup_if_needed "$BIN_DIR/pde-tui"
backup_if_needed "$BIN_DIR/projects"
backup_if_needed "$BIN_DIR/pde-worktree"

ln -sf "$CONFIG_DIR/bin/pde" "$BIN_DIR/pde"
ln -sf "$CONFIG_DIR/bin/projects" "$BIN_DIR/projects"
ln -sf "$CONFIG_DIR/bin/pde-worktree" "$BIN_DIR/pde-worktree"

if command -v cargo >/dev/null 2>&1; then
  echo "🦀 Building PDE TUI..."
  cargo build --release --manifest-path "$CONFIG_DIR/pde_tui/Cargo.toml"
  ln -sf "$CONFIG_DIR/target/release/pde-tui" "$BIN_DIR/pde-tui"
else
  echo "❌ cargo not found. Install Rust/Cargo, then re-run ./install.sh." >&2
  echo "Recommended official installer:" >&2
  echo "  curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh" >&2
  echo '  source "$HOME/.cargo/env"' >&2
  echo "Then verify:" >&2
  echo "  cargo --version" >&2
  exit 1
fi

chmod +x "$BIN_DIR/pde" "$BIN_DIR/projects" "$BIN_DIR/pde-worktree" "$BIN_DIR/pde-tui"

PRESET_INSTALL="$CONFIG_DIR/presets/$PRESET/install.sh"
if [[ ! -x "$PRESET_INSTALL" ]]; then
  echo "❌ Unknown or non-executable preset: $PRESET" >&2
  echo "Available presets:" >&2
  find "$CONFIG_DIR/presets" -maxdepth 1 -mindepth 1 -type d -exec basename {} \; | sort >&2
  exit 1
fi

"$PRESET_INSTALL" "${PRESET_ARGS[@]}"

echo ""
echo "✅ PDE installed with preset: $PRESET"
echo "Installed commands in: $BIN_DIR"

case ":$PATH:" in
  *":$BIN_DIR:"*)
    echo "Next: pde"
    ;;
  *)
    echo "Next: add PDE to your shell PATH, then run pde"
    echo "  echo 'export PATH=\"$BIN_DIR:\$PATH\"' >> ~/.zshrc"
    echo "  source ~/.zshrc"
    echo "Or run it directly now:"
    echo "  $BIN_DIR/pde"
    ;;
esac
