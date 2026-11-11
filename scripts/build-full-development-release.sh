#!/usr/bin/env bash
set -euo pipefail

if [[ "${1:-}" == "--help" ]]; then
  echo "Usage: $0 [source-root] [output-directory]"
  echo "source-root contains pde, fleetui, gtui, rtui, pantsui and tui-helpers."
  echo "Builds a Linux release bundle and a matching source archive."
  exit 0
fi

PDE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SOURCE_ROOT="$(cd "${1:-$PDE_DIR/..}" && pwd)"
OUTPUT_DIR="${2:-$PDE_DIR/target/dist}"
VERSION="$(awk -F '"' '/^version = / { print $2; exit }' "$SOURCE_ROOT/pde/Cargo.toml")"
NVIM_VERSION="${NVIM_VERSION:-v0.12.6}"
LAZYDOCKER_VERSION="${LAZYDOCKER_VERSION:-v0.25.2}"

[[ "$(uname -s)" == "Linux" ]] || { echo "This bundle currently supports Linux only." >&2; exit 1; }
case "$(uname -m)" in
  x86_64) RUST_ARCH=x86_64; NVIM_ARCH=x86_64; DOCKER_ARCH=x86_64 ;;
  aarch64|arm64) RUST_ARCH=aarch64; NVIM_ARCH=arm64; DOCKER_ARCH=arm64 ;;
  *) echo "Unsupported architecture: $(uname -m)" >&2; exit 1 ;;
esac

PROJECTS=(pde fleetui gtui rtui pantsui tui-helpers)
for project in "${PROJECTS[@]}"; do
  [[ -f "$SOURCE_ROOT/$project/Cargo.toml" ]] || { echo "Missing source: $project" >&2; exit 1; }
done
for tool in cargo gh tar sha256sum; do
  command -v "$tool" >/dev/null || { echo "Missing build tool: $tool" >&2; exit 1; }
done

mkdir -p "$OUTPUT_DIR"
OUTPUT_DIR="$(cd "$OUTPUT_DIR" && pwd)"
STAGING_DIR="$(mktemp -d "${TMPDIR:-/tmp}/pde-full-development.XXXXXX")"
trap 'rm -rf "$STAGING_DIR"' EXIT
NAME="pde-full-development-v$VERSION-$RUST_ARCH-unknown-linux-gnu"
SOURCE_NAME="pde-full-development-v$VERSION-sources"
SOURCES="$STAGING_DIR/$SOURCE_NAME"
BUNDLE="$STAGING_DIR/$NAME"
mkdir -p "$SOURCES" "$BUNDLE/bin" "$BUNDLE/lib" "$BUNDLE/licenses" "$STAGING_DIR/downloads"

# Copy source files, including current changes, without caches or local ignored files.
for project in "${PROJECTS[@]}"; do
  project_dir="$SOURCE_ROOT/$project"
  destination="$SOURCES/$project"
  mkdir -p "$destination"
  if [[ -e "$project_dir/.git" ]]; then
    git -C "$project_dir" ls-files --cached --others --exclude-standard -z > "$STAGING_DIR/files"
    while IFS= read -r -d '' source_file; do
      [[ -e "$project_dir/$source_file" || -L "$project_dir/$source_file" ]] || continue
      mkdir -p "$destination/$(dirname "$source_file")"
      cp -a "$project_dir/$source_file" "$destination/$source_file"
    done < "$STAGING_DIR/files"
    revision="$(git -C "$project_dir" rev-parse HEAD)"
    status=clean
    [[ -z "$(git -C "$project_dir" status --porcelain)" ]] || status=modified
    printf '%s %s %s\n' "$project" "$revision" "$status" >> "$SOURCES/BUILD-SOURCES.txt"
  else
    # Projects without a Git repository use an explicit list of source locations.
    for entry in Cargo.toml Cargo.lock src crates tests scripts docs pde_tui bin presets docker .github install.sh README.md LICENSE LICENSE-MIT LICENSE-APACHE ARCHITECTURE.md; do
      [[ ! -e "$project_dir/$entry" ]] || cp -a "$project_dir/$entry" "$destination/"
    done
    printf '%s local-source-snapshot\n' "$project" >> "$SOURCES/BUILD-SOURCES.txt"
  fi
done
printf 'neovim %s\nlazydocker %s\n' "$NVIM_VERSION" "$LAZYDOCKER_VERSION" >> "$SOURCES/BUILD-SOURCES.txt"
cargo --version >> "$SOURCES/BUILD-SOURCES.txt"
rustc --version >> "$SOURCES/BUILD-SOURCES.txt"
ldd --version | sed -n '1p' >> "$SOURCES/BUILD-SOURCES.txt"

BUILD_TARGET="${PDE_RELEASE_TARGET_DIR:-$PDE_DIR/target}"
mkdir -p "$BUILD_TARGET"
BUILD_TARGET="$(cd "$BUILD_TARGET" && pwd)"
for project in pde fleetui gtui rtui pantsui; do
  cargo build --release --locked --manifest-path "$SOURCES/$project/Cargo.toml" --target-dir "$BUILD_TARGET"
done

cp -a "$SOURCES/pde" "$BUNDLE/pde"
mkdir -p "$BUNDLE/pde/target/release"
install -m 0755 "$BUILD_TARGET/release/pde-tui" "$BUNDLE/pde/target/release/pde-tui"
for binary in fleetui gtui rtui pantsui; do
  install -m 0755 "$BUILD_TARGET/release/$binary" "$BUNDLE/bin/$binary"
done
for binary in "$BUNDLE/pde/bin/"*; do
  [[ -f "$binary" ]] || continue
  ln -s "../pde/bin/$(basename "$binary")" "$BUNDLE/bin/$(basename "$binary")"
done
ln -s ../pde/target/release/pde-tui "$BUNDLE/bin/pde-tui"

nvim_asset="nvim-linux-$NVIM_ARCH.tar.gz"
docker_asset="lazydocker_${LAZYDOCKER_VERSION#v}_Linux_$DOCKER_ARCH.tar.gz"
gh release download "$NVIM_VERSION" --repo neovim/neovim --pattern "$nvim_asset" --dir "$STAGING_DIR/downloads"
gh release download "$LAZYDOCKER_VERSION" --repo jesseduffield/lazydocker --pattern "$docker_asset" --pattern checksums.txt --dir "$STAGING_DIR/downloads"
(
  cd "$STAGING_DIR/downloads"
  sha256sum --check --ignore-missing checksums.txt
)
tar -xzf "$STAGING_DIR/downloads/$nvim_asset" -C "$BUNDLE/lib"
mv "$BUNDLE/lib/nvim-linux-$NVIM_ARCH" "$BUNDLE/lib/nvim"
mkdir -p "$STAGING_DIR/lazydocker"
tar -xzf "$STAGING_DIR/downloads/$docker_asset" -C "$STAGING_DIR/lazydocker"
install -m 0755 "$STAGING_DIR/lazydocker/lazydocker" "$BUNDLE/bin/lazydocker"
cp "$STAGING_DIR/lazydocker/LICENSE" "$BUNDLE/licenses/lazydocker-LICENSE"
cat > "$BUNDLE/bin/nvim" <<'NVIM'
#!/usr/bin/env bash
set -euo pipefail
bundle_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
exec "$bundle_dir/lib/nvim/bin/nvim" "$@"
NVIM
chmod +x "$BUNDLE/bin/nvim"
cp "$SOURCES/BUILD-SOURCES.txt" "$BUNDLE/BUILD-SOURCES.txt"
cat > "$BUNDLE/README.txt" <<EOF
PDE v$VERSION full-development ($RUST_ARCH Linux)

Includes PDE, fleetui, gtui, rtui, pantsui, Neovim $NVIM_VERSION (with its
runtime and licenses), and lazydocker $LAZYDOCKER_VERSION.
Sources and build provenance accompany this release in $SOURCE_NAME.tar.gz.

Extract the archive to a permanent location, then run:
  export PATH="\$PWD/bin:\$PATH"
  pde

In Create project or Edit project, select Layout, then press o and f.
Save and start a new session to open the seven full-development tabs.

Requires a Linux system compatible with the glibc listed in BUILD-SOURCES.txt,
and installed Bash, Python 3, Git, Zsh, and tmux or Zellij. Integrations use
your existing Docker daemon, gh/glab logins, Pants, and Bruno CLI as needed.
Shells, terminal emulators, Docker daemons, and credentials are not bundled.
EOF

"$BUNDLE/bin/pde-tui" --version
"$BUNDLE/bin/nvim" --headless -u NONE -i NONE '+lua assert(vim.fn.isdirectory(vim.env.VIMRUNTIME) == 1)' +qa
"$BUNDLE/bin/lazydocker" --version
tar -czf "$OUTPUT_DIR/$NAME.tar.gz" -C "$STAGING_DIR" "$NAME"
tar -czf "$OUTPUT_DIR/$SOURCE_NAME.tar.gz" -C "$STAGING_DIR" "$SOURCE_NAME"
(
  cd "$OUTPUT_DIR"
  sha256sum "$NAME.tar.gz" "$SOURCE_NAME.tar.gz" > "$NAME.sha256"
)
echo "Release assets: $OUTPUT_DIR/$NAME.tar.gz"
echo "Source archive: $OUTPUT_DIR/$SOURCE_NAME.tar.gz"
