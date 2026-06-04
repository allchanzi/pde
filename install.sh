#!/usr/bin/env bash
set -euo pipefail

CONFIG_DIR="$(cd "$(dirname "$0")" && pwd)"
PRESET="${PDE_PRESET:-default}"

usage() {
  cat <<USAGE
Usage:
  ./install.sh [--preset default|allc]

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

mkdir -p "$HOME/bin" "$HOME/.config/pde"

backup_if_needed() {
  local target="$1"
  if [[ -e "$target" && ! -L "$target" ]]; then
    local backup="${target}.backup.$(date +%Y%m%d%H%M%S)"
    echo "📦 Backing up $target -> $backup"
    mv "$target" "$backup"
  fi
}

backup_if_needed "$HOME/bin/pde"
backup_if_needed "$HOME/bin/pde-tui"
backup_if_needed "$HOME/bin/projects"
backup_if_needed "$HOME/bin/pde-worktree"

ln -sf "$CONFIG_DIR/bin/pde" "$HOME/bin/pde"
ln -sf "$CONFIG_DIR/bin/projects" "$HOME/bin/projects"
ln -sf "$CONFIG_DIR/bin/pde-worktree" "$HOME/bin/pde-worktree"

if command -v cargo >/dev/null 2>&1; then
  echo "🦀 Building PDE TUI..."
  cargo build --release --manifest-path "$CONFIG_DIR/pde_tui/Cargo.toml"
  ln -sf "$CONFIG_DIR/target/release/pde-tui" "$HOME/bin/pde-tui"
else
  echo "❌ cargo not found. Install Rust, then re-run ./install.sh." >&2
  exit 1
fi

chmod +x "$HOME/bin/pde" "$HOME/bin/projects" "$HOME/bin/pde-worktree" "$HOME/bin/pde-tui"

PRESET_INSTALL="$CONFIG_DIR/presets/$PRESET/install.sh"
if [[ ! -x "$PRESET_INSTALL" ]]; then
  echo "❌ Unknown or non-executable preset: $PRESET" >&2
  echo "Available presets:" >&2
  find "$CONFIG_DIR/presets" -maxdepth 1 -mindepth 1 -type d -exec basename {} \; | sort >&2
  exit 1
fi

"$PRESET_INSTALL"

echo ""
echo "✅ PDE installed with preset: $PRESET"
echo "Next: pde"
