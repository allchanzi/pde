#!/usr/bin/env bash
set -euo pipefail

CONFIG_DIR="$(cd "$(dirname "$0")" && pwd)"
PRESET="${PDE_PRESET:-default}"
BIN_DIR="${PDE_BIN_DIR:-$HOME/bin}"
BOOTSTRAP="${PDE_BOOTSTRAP:-1}"
INSTALL_COMPANIONS="${PDE_INSTALL_COMPANIONS:-1}"
PRESET_ARGS=()

usage() {
  cat <<USAGE
Usage:
  ./install.sh [--preset default|allc] [--force-theme|--no-theme]
               [--no-bootstrap] [--no-companions]

Theme flags are only used by --preset allc.

Installs the PDE app/wrappers and runs the selected preset.
On Linux, bootstrap installs missing system prerequisites and Rust automatically.
Default preset ensures tmux is installed when neither tmux nor zellij is present.

Environment:
  PDE_BOOTSTRAP=0            Do not install system prerequisites or Rust
  PDE_INSTALL_COMPANIONS=0   Do not install rtui and pantsui
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
    --no-bootstrap)
      BOOTSTRAP=0
      shift
      ;;
    --no-companions)
      INSTALL_COMPANIONS=0
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

case "$BOOTSTRAP" in
  0|1) ;;
  *)
    echo "❌ PDE_BOOTSTRAP must be 0 or 1" >&2
    exit 1
    ;;
esac

case "$INSTALL_COMPANIONS" in
  0|1) ;;
  *)
    echo "❌ PDE_INSTALL_COMPANIONS must be 0 or 1" >&2
    exit 1
    ;;
esac

if [[ "$PRESET" != "allc" && "${#PRESET_ARGS[@]}" -gt 0 ]]; then
  echo "❌ Theme flags are only supported with --preset allc" >&2
  usage >&2
  exit 1
fi

PRESET_INSTALL="$CONFIG_DIR/presets/$PRESET/install.sh"
if [[ ! -x "$PRESET_INSTALL" ]]; then
  echo "❌ Unknown or non-executable preset: $PRESET" >&2
  echo "Available presets:" >&2
  find "$CONFIG_DIR/presets" -maxdepth 1 -mindepth 1 -type d -exec basename {} \; | sort >&2
  exit 1
fi

run_as_root() {
  if [[ "$(id -u)" -eq 0 ]]; then
    "$@"
  elif command -v sudo >/dev/null 2>&1; then
    sudo "$@"
  else
    echo "❌ Installing Linux prerequisites requires root or sudo." >&2
    echo "   Install the packages listed below manually, then re-run with --no-bootstrap." >&2
    return 1
  fi
}

linux_bootstrap_needed() {
  local command
  local required=(curl file git make python3 unzip zsh)

  if [[ "$PRESET" == "default" ]] \
    && ! command -v tmux >/dev/null 2>&1 \
    && ! command -v zellij >/dev/null 2>&1; then
    return 0
  fi

  for command in "${required[@]}"; do
    command -v "$command" >/dev/null 2>&1 || return 0
  done

  command -v cc >/dev/null 2>&1 || return 0
  return 1
}

bootstrap_linux() {
  if [[ "$PRESET" == "allc" && -f /etc/alpine-release ]]; then
    echo "❌ The allc preset requires a glibc Linux distribution; Alpine/musl is not supported." >&2
    echo "   Use --preset default on Alpine, or use a Debian/Ubuntu/Fedora/Arch/openSUSE host." >&2
    exit 1
  fi

  if ! linux_bootstrap_needed; then
    echo "✅ Linux system prerequisites already available"
    return 0
  fi

  local install_mux=0
  if [[ "$PRESET" == "default" ]] \
    && ! command -v tmux >/dev/null 2>&1 \
    && ! command -v zellij >/dev/null 2>&1; then
    install_mux=1
  fi

  echo "📦 Installing Linux system prerequisites..."

  if command -v apt-get >/dev/null 2>&1; then
    local apt_packages=(
      build-essential ca-certificates curl file git pkg-config procps python3 unzip zsh
    )
    [[ "$install_mux" -eq 1 ]] && apt_packages+=(tmux)
    run_as_root apt-get update
    run_as_root env DEBIAN_FRONTEND=noninteractive apt-get install -y "${apt_packages[@]}"
  elif command -v dnf >/dev/null 2>&1; then
    local dnf_packages=(
      ca-certificates curl file gcc gcc-c++ git make pkgconf-pkg-config
      procps-ng python3 unzip zsh
    )
    [[ "$install_mux" -eq 1 ]] && dnf_packages+=(tmux)
    run_as_root dnf install -y "${dnf_packages[@]}"
  elif command -v pacman >/dev/null 2>&1; then
    local pacman_packages=(
      base-devel ca-certificates curl file git procps-ng python unzip zsh
    )
    [[ "$install_mux" -eq 1 ]] && pacman_packages+=(tmux)
    run_as_root pacman -Sy --needed --noconfirm "${pacman_packages[@]}"
  elif command -v zypper >/dev/null 2>&1; then
    local zypper_packages=(
      ca-certificates curl file gcc gcc-c++ git make pkg-config procps python3 unzip zsh
    )
    [[ "$install_mux" -eq 1 ]] && zypper_packages+=(tmux)
    run_as_root zypper --non-interactive install "${zypper_packages[@]}"
  elif command -v apk >/dev/null 2>&1; then
    local apk_packages=(
      build-base ca-certificates curl file git pkgconf procps python3 unzip zsh
    )
    [[ "$install_mux" -eq 1 ]] && apk_packages+=(tmux)
    run_as_root apk add --no-cache "${apk_packages[@]}"
  else
    cat >&2 <<'MSG'
❌ Unsupported Linux package manager.
Install these prerequisites manually:
  C/C++ build tools, pkg-config, procps, curl, file, git, Python 3, unzip, Zsh
Also install tmux or Zellij when using the default preset.
Then re-run: ./install.sh --no-bootstrap
MSG
    exit 1
  fi
}

ensure_rust() {
  if command -v cargo >/dev/null 2>&1; then
    return 0
  fi

  if [[ "$BOOTSTRAP" -eq 0 ]]; then
    return 1
  fi

  if ! command -v curl >/dev/null 2>&1; then
    echo "❌ curl is required to install Rust with rustup." >&2
    return 1
  fi

  echo "🦀 Rust/Cargo not found. Installing the minimal stable toolchain with rustup..."
  curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs \
    | sh -s -- -y --profile minimal

  if [[ -f "$HOME/.cargo/env" ]]; then
    # shellcheck source=/dev/null
    source "$HOME/.cargo/env"
  fi

  command -v cargo >/dev/null 2>&1
}

persist_rustup_for_zsh() {
  local zprofile="$HOME/.zprofile"
  local rustup_line='[[ -f "$HOME/.cargo/env" ]] && source "$HOME/.cargo/env"'

  [[ -f "$HOME/.cargo/env" ]] || return 0
  if [[ ! -f "$zprofile" ]] || ! grep -Fq "$rustup_line" "$zprofile"; then
    echo "📝 Adding Rustup environment to $zprofile"
    printf '%s\n' "$rustup_line" >> "$zprofile"
  fi
}

persist_bin_path() {
  local profile
  local path_line

  if [[ "$BIN_DIR" == "$HOME/bin" ]]; then
    path_line='export PATH="$HOME/bin:$PATH"'
  else
    printf -v path_line 'export PATH=%q:"$PATH"' "$BIN_DIR"
  fi

  for profile in "$HOME/.profile" "$HOME/.zprofile"; do
    if [[ ! -f "$profile" ]] || ! grep -Fq "$path_line" "$profile"; then
      echo "📝 Adding PDE commands to $profile"
      printf '%s\n' "$path_line" >> "$profile"
    fi
  done
}

if [[ "$(uname -s)" == "Linux" && "$BOOTSTRAP" -eq 1 ]]; then
  bootstrap_linux
fi

if ! command -v git >/dev/null 2>&1; then
  echo "❌ git is required. Install it, then re-run ./install.sh." >&2
  exit 1
fi

mkdir -p "$BIN_DIR" "$HOME/.config/pde"
persist_bin_path

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

install_cargo_tool() {
  # Build and install the latest tool from its git repo into $BIN_DIR.
  local name="$1" repo="$2" branch="$3"
  local install_root
  install_root="$(mktemp -d)"
  echo "🦀 Installing latest $name from $repo (branch $branch)..."
  if CARGO_NET_GIT_FETCH_WITH_CLI=true cargo install \
    --git "$repo" \
    --branch "$branch" \
    --root "$install_root" \
    --force; then
    install -m 0755 "$install_root/bin/$name" "$BIN_DIR/$name"
    echo "✅ Installed $name: $("$BIN_DIR/$name" --version 2>/dev/null || echo unknown-version)"
  else
    echo "⚠️  Failed to install $name from $repo — skipping (build it manually if needed)." >&2
  fi
  rm -rf "$install_root"
}

if ensure_rust; then
  persist_rustup_for_zsh
  echo "🦀 Building PDE TUI..."
  cargo build --release --manifest-path "$CONFIG_DIR/pde_tui/Cargo.toml"
  ln -sf "$CONFIG_DIR/target/release/pde-tui" "$BIN_DIR/pde-tui"

  if [[ "$INSTALL_COMPANIONS" -eq 1 ]]; then
    install_cargo_tool "rtui" "https://github.com/allchanzi/rtui.git" "main"
    install_cargo_tool "pantsui" "https://github.com/allchanzi/pantsui.git" "main"
  else
    echo "ℹ️ Skipping rtui and pantsui (--no-companions)"
  fi
else
  echo "❌ cargo not found and automatic rustup installation was unavailable or disabled." >&2
  echo "Recommended official installer:" >&2
  echo "  curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh" >&2
  echo '  source "$HOME/.cargo/env"' >&2
  echo "Then verify:" >&2
  echo "  cargo --version" >&2
  exit 1
fi

chmod +x "$BIN_DIR/pde" "$BIN_DIR/projects" "$BIN_DIR/pde-worktree" "$BIN_DIR/pde-tui"

PATH="$BIN_DIR:$PATH" "$PRESET_INSTALL" ${PRESET_ARGS[@]+"${PRESET_ARGS[@]}"}

VERIFY_PATH="$BIN_DIR:/opt/homebrew/bin:/usr/local/bin:/home/linuxbrew/.linuxbrew/bin:$HOME/.linuxbrew/bin:$PATH"
if ! PATH="$VERIFY_PATH" command -v python3 >/dev/null 2>&1; then
  echo "❌ python3 is required by the projects and worktree commands." >&2
  exit 1
fi

echo ""
echo "✅ PDE installed with preset: $PRESET"
echo "Installed commands in: $BIN_DIR"

case ":$PATH:" in
  *":$BIN_DIR:"*)
    echo "Next: pde"
    ;;
  *)
    echo "Next: restart your login shell, then run pde"
    echo '  exec "$SHELL" -l'
    echo "Or run PDE directly now:"
    echo "  $BIN_DIR/pde"
    ;;
esac
