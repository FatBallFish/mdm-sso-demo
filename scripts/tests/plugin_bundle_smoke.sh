#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
OUT_ROOT="$(mktemp -d)"
trap 'rm -rf "${OUT_ROOT}"' EXIT

"${ROOT_DIR}/scripts/build-login-plugin-bundle.sh" --output-root "${OUT_ROOT}" >/dev/null

BUNDLE_ROOT="${OUT_ROOT}/DemoLoginPlugin.bundle"
BINARY_PATH="${BUNDLE_ROOT}/Contents/MacOS/DemoLoginPlugin"
PLIST_PATH="${BUNDLE_ROOT}/Contents/Info.plist"

test -d "${BUNDLE_ROOT}"
test -f "${PLIST_PATH}"
test -x "${BINARY_PATH}"
grep -q "CFBundleIdentifier" "${PLIST_PATH}"
