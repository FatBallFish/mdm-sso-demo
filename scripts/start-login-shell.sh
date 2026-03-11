#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SWIFTPM_SCRATCH_ROOT="${DEMO_SWIFTPM_SCRATCH_ROOT:-${HOME}/Library/Caches/DemoSSO/swiftpm}"

cd "${ROOT_DIR}"
mkdir -p "${ROOT_DIR}/.home" "${ROOT_DIR}/.swiftpm-cache" "${ROOT_DIR}/.cache/clang" "${SWIFTPM_SCRATCH_ROOT}"

swift_env() {
  env \
    HOME="${ROOT_DIR}/.home" \
    XDG_CACHE_HOME="${ROOT_DIR}/.swiftpm-cache" \
    CLANG_MODULE_CACHE_PATH="${ROOT_DIR}/.cache/clang" \
    "$@"
}

swift_env swift build --scratch-path "${SWIFTPM_SCRATCH_ROOT}" >/dev/null
BIN_DIR="$(swift_env swift build --scratch-path "${SWIFTPM_SCRATCH_ROOT}" --show-bin-path)"

exec env \
  HOME="${ROOT_DIR}/.home" \
  XDG_CACHE_HOME="${ROOT_DIR}/.swiftpm-cache" \
  CLANG_MODULE_CACHE_PATH="${ROOT_DIR}/.cache/clang" \
  DEMO_ACCOUNTSYNC_DAEMON_PATH="${BIN_DIR}/DemoAccountSyncDaemon" \
  swift run --skip-build --scratch-path "${SWIFTPM_SCRATCH_ROOT}" DemoLoginShell
