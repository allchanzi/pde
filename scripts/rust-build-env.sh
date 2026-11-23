#!/usr/bin/env bash
# Keep local source and toolchain paths out of compiled binaries.
if [[ -z "${CARGO_ENCODED_RUSTFLAGS+x}" ]]; then
  CARGO_ENCODED_RUSTFLAGS=""
  if [[ -n "${RUSTFLAGS:-}" ]]; then
    read -r -a pde_rust_flags <<< "${RUSTFLAGS//$'\n'/ }"
    for pde_rust_flag in "${pde_rust_flags[@]}"; do
      CARGO_ENCODED_RUSTFLAGS+="${CARGO_ENCODED_RUSTFLAGS:+$'\x1f'}$pde_rust_flag"
    done
  fi
fi
pde_source_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd -P)"
for pde_build_root in "${HOME:-}" "${CARGO_HOME:-}" "${RUSTUP_HOME:-}" "$pde_source_root"; do
  [[ -n "$pde_build_root" && "$pde_build_root" != / ]] || continue
  CARGO_ENCODED_RUSTFLAGS+="${CARGO_ENCODED_RUSTFLAGS:+$'\x1f'}--remap-path-prefix=$pde_build_root=/build"
done
export CARGO_ENCODED_RUSTFLAGS
unset pde_rust_flags pde_rust_flag pde_source_root pde_build_root
