#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
OUT_BIN="$(mktemp "${TMPDIR:-/tmp}/demo-plugin-harness.XXXXXX")"
trap 'rm -f "${OUT_BIN}"' EXIT

clang \
  -I "${ROOT_DIR}/Sources/DemoLoginPluginC/include" \
  -framework Security \
  -framework CoreFoundation \
  "${ROOT_DIR}/scripts/tests/plugin_passthrough_harness.c" \
  "${ROOT_DIR}/Sources/DemoLoginPluginC/PluginEntry.c" \
  -o "${OUT_BIN}"

"${OUT_BIN}"
