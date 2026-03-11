#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

cd "${ROOT_DIR}"
mkdir -p "${ROOT_DIR}/.home" "${ROOT_DIR}/.swiftpm-cache" "${ROOT_DIR}/.cache/clang"

exec env \
  HOME="${ROOT_DIR}/.home" \
  XDG_CACHE_HOME="${ROOT_DIR}/.swiftpm-cache" \
  CLANG_MODULE_CACHE_PATH="${ROOT_DIR}/.cache/clang" \
  swift run DemoLoginShell
