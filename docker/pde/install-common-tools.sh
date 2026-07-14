#!/usr/bin/env bash
set -euo pipefail

case "$(dpkg --print-architecture)" in
  amd64)
    go_arch="x86_64"
    nvim_arch="x86_64"
    rust_arch="x86_64"
    ;;
  arm64)
    go_arch="arm64"
    nvim_arch="arm64"
    rust_arch="aarch64"
    ;;
  *)
    echo "Unsupported architecture: $(dpkg --print-architecture)" >&2
    exit 1
    ;;
esac

github_release_json() {
  local repository="$1"
  local version="${2:-latest}"

  if [[ "$version" == "latest" ]]; then
    curl --fail --location --silent --show-error \
      "https://api.github.com/repos/${repository}/releases/latest"
    return
  fi

  curl --fail --location --silent --show-error \
    "https://api.github.com/repos/${repository}/releases/tags/${version}"
}

install_github_binary() {
  local repository="$1"
  local binary="$2"
  local asset_pattern="$3"
  local version="${4:-latest}"
  local release
  local download_url
  local archive
  local extract_dir
  local executable

  release="$(github_release_json "$repository" "$version")"
  download_url="$(
    jq --raw-output \
      --arg pattern "$asset_pattern" \
      '.assets[] | select(.name | test($pattern; "i")) | .browser_download_url' \
      <<<"$release" \
      | head -n 1
  )"

  if [[ -z "$download_url" || "$download_url" == "null" ]]; then
    echo "No matching ${binary} release asset found in ${repository} for version ${version}" >&2
    exit 1
  fi

  archive="$(mktemp)"
  extract_dir="$(mktemp -d)"
  curl --fail --location --silent --show-error "$download_url" --output "$archive"

  case "$download_url" in
    *.tar.gz | *.tgz) tar -xzf "$archive" -C "$extract_dir" ;;
    *.zip) unzip -q "$archive" -d "$extract_dir" ;;
    *)
      echo "Unsupported archive: $download_url" >&2
      exit 1
      ;;
  esac

  executable="$(find "$extract_dir" -type f -name "$binary" -perm /111 | head -n 1)"
  if [[ -z "$executable" ]]; then
    echo "Executable ${binary} not found in ${download_url}" >&2
    exit 1
  fi

  install -m 0755 "$executable" "/usr/local/bin/${binary}"
  rm -rf "$archive" "$extract_dir"
}

install_neovim() {
  local release
  local download_url
  local archive
  local extract_dir
  local extracted_root

  release="$(curl --fail --location --silent --show-error \
    "https://api.github.com/repos/neovim/neovim/releases/latest")"
  download_url="$(
    jq --raw-output \
      --arg pattern "nvim-linux-${nvim_arch}\\.tar\\.gz$" \
      '.assets[] | select(.name | test($pattern; "i")) | .browser_download_url' \
      <<<"$release" \
      | head -n 1
  )"

  if [[ -z "$download_url" || "$download_url" == "null" ]]; then
    echo "No matching neovim release asset found" >&2
    exit 1
  fi

  archive="$(mktemp)"
  extract_dir="$(mktemp -d)"
  curl --fail --location --silent --show-error "$download_url" --output "$archive"
  tar -xzf "$archive" -C "$extract_dir"

  extracted_root="$(find "$extract_dir" -mindepth 1 -maxdepth 1 -type d | head -n 1)"
  if [[ -z "$extracted_root" ]]; then
    echo "Neovim archive did not contain an extracted directory" >&2
    exit 1
  fi

  rm -rf /opt/nvim
  mv "$extracted_root" /opt/nvim
  ln -sf /opt/nvim/bin/nvim /usr/local/bin/nvim
  rm -rf "$archive" "$extract_dir"
}

install_github_binary \
  "jesseduffield/lazygit" \
  "lazygit" \
  "lazygit_.*_linux_${go_arch}\\.tar\\.gz$"
install_github_binary \
  "jesseduffield/lazydocker" \
  "lazydocker" \
  "lazydocker_.*_Linux_${go_arch}\\.tar\\.gz$"
install_github_binary \
  "charmbracelet/gum" \
  "gum" \
  "gum_.*_Linux_${go_arch}\\.tar\\.gz$"
install_github_binary \
  "eza-community/eza" \
  "eza" \
  "eza_${rust_arch}-unknown-linux-gnu\\.tar\\.gz$"

install_neovim

if [[ "${PDE_INSTALL_RTUI:-0}" == "1" ]]; then
  install_github_binary \
    "${RTUI_REPO:-allchanzi/rtui}" \
    "rtui" \
    "rtui-${rust_arch}-unknown-linux-gnu\\.tar\\.gz$" \
    "${RTUI_VERSION:-latest}"
fi

if [[ "${PDE_INSTALL_PANTSUI:-0}" == "1" ]]; then
  install_github_binary \
    "${PANTSUI_REPO:-allchanzi/pantsui}" \
    "pantsui" \
    "pantsui-${rust_arch}-unknown-linux-gnu\\.tar\\.gz$" \
    "${PANTSUI_VERSION:-latest}"
fi
