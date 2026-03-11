#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
OUT_ROOT="$(mktemp -d)"
trap 'rm -rf "${OUT_ROOT}"' EXIT

"${ROOT_DIR}/scripts/build-login-plugin-bundle.sh" --output-root "${OUT_ROOT}" >/dev/null

BINARY_PATH="${OUT_ROOT}/DemoLoginPlugin.bundle/Contents/MacOS/DemoLoginPlugin"

test -x "${BINARY_PATH}"
strings "${BINARY_PATH}" | grep -q "com.demo.sso.login-plugin"
strings "${BINARY_PATH}" | grep -q "AuthorizationPluginCreate"
strings "${BINARY_PATH}" | grep -q "MechanismInvoke allow"
