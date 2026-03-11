#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
INSTALL_ROOT="$(mktemp -d)"
trap 'rm -rf "${INSTALL_ROOT}"' EXIT

"${ROOT_DIR}/scripts/install-jamf-style-demo.sh" --root "${INSTALL_ROOT}" --enable-authdb >/dev/null

test -x "${INSTALL_ROOT}/Library/Application Support/DemoSSO/bin/DemoAccountSyncDaemon"
test -x "${INSTALL_ROOT}/Library/Application Support/DemoSSO/bin/DemoLoginBroker"
test -d "${INSTALL_ROOT}/Library/Application Support/DemoSSO/bin/DemoLoginShell.app"
test -f "${INSTALL_ROOT}/Library/Application Support/DemoSSO/bin/DemoLoginShell.app/Contents/Info.plist"
test -x "${INSTALL_ROOT}/Library/Application Support/DemoSSO/bin/DemoLoginShell.app/Contents/MacOS/DemoLoginShell"
test -f "${INSTALL_ROOT}/Library/Application Support/DemoSSO/config/demo-idp.json"
test -f "${INSTALL_ROOT}/Library/Application Support/DemoSSO/authdb/system.login.console.backup.plist"
test -f "${INSTALL_ROOT}/Library/Application Support/DemoSSO/authdb/system.login.console.demo.plist"
test -f "${INSTALL_ROOT}/Library/Security/SecurityAgentPlugins/DemoLoginPlugin.bundle/Contents/Info.plist"
