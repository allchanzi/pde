#!/usr/bin/env sh
set -eu

mkdir -p \
  "$HOME/.cache" \
  "$HOME/.config/pde" \
  "$HOME/.local/share" \
  "$HOME/.local/state"

# Restore the lightweight symlink-based preset when $HOME is a fresh volume.
/opt/pde/docker/pde/install.sh

exec "$@"
