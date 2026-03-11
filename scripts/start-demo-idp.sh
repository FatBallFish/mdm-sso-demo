#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONFIG_PATH="${ROOT_DIR}/configs/demo-idp.json"
HOST="${DEMO_IDP_HOST:-127.0.0.1}"
PORT="${DEMO_IDP_PORT:-48080}"
SWIFTPM_SCRATCH_ROOT="${DEMO_SWIFTPM_SCRATCH_ROOT:-${HOME}/Library/Caches/DemoSSO/swiftpm}"

cd "${ROOT_DIR}"
mkdir -p "${ROOT_DIR}/.home" "${ROOT_DIR}/.swiftpm-cache" "${ROOT_DIR}/.cache/clang" "${SWIFTPM_SCRATCH_ROOT}"

exec env \
  HOME="${ROOT_DIR}/.home" \
  XDG_CACHE_HOME="${ROOT_DIR}/.swiftpm-cache" \
  CLANG_MODULE_CACHE_PATH="${ROOT_DIR}/.cache/clang" \
  swift run --scratch-path "${SWIFTPM_SCRATCH_ROOT}" DemoIDPServer --host "${HOST}" --port "${PORT}" --config "${CONFIG_PATH}"
