#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

make clean
make all test source-ratio

ratio="$(find src -name '*.asm' -print0 | xargs -0 cat | wc -l)"
c_lines="$(find adapter -name '*.c' -print0 | xargs -0 cat | wc -l)"
if (( ratio * 100 < 75 * (ratio + c_lines) )); then
  printf 'ERROR: NASM runtime source ratio fell below 75%%.\n' >&2
  exit 1
fi

if grep -RInE 'Minecraft|StartBridgeServer|BRIDGE_|setbridge|bridgestatus|bridge_channel' \
  --exclude-dir=.git --exclude='*.md' --exclude='commands_vector.asm' --exclude='run-local.sh' .; then
  printf 'ERROR: prohibited bridge identifier detected in runtime/test source.\n' >&2
  exit 1
fi

printf 'CaineASM local verification passed.\n'
