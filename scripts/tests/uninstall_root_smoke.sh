#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
INSTALL_ROOT="$(mktemp -d)"
trap 'rm -rf "${INSTALL_ROOT}"' EXIT

"${ROOT_DIR}/scripts/install-jamf-style-demo.sh" --root "${INSTALL_ROOT}" --no-authdb >/dev/null
mkdir -p "${INSTALL_ROOT}/Library/Application Support/DemoSSO/state"
touch "${INSTALL_ROOT}/Library/Application Support/DemoSSO/state/marker"

"${ROOT_DIR}/scripts/uninstall-jamf-style-demo.sh" --root "${INSTALL_ROOT}" >/dev/null

test ! -e "${INSTALL_ROOT}/Library/Security/SecurityAgentPlugins/DemoLoginPlugin.bundle"
test ! -e "${INSTALL_ROOT}/Library/Application Support/DemoSSO/bin"
test ! -e "${INSTALL_ROOT}/Library/Application Support/DemoSSO/config"
test ! -e "${INSTALL_ROOT}/Library/Application Support/DemoSSO/state"
