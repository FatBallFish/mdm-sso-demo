#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

grep -q "showing pre-login shell" "${ROOT_DIR}/Sources/DemoLoginPluginC/PluginEntry.c"
grep -q "spawned login shell" "${ROOT_DIR}/Sources/DemoLoginPluginC/PluginEntry.c"
grep -q "timed out waiting for login shell" "${ROOT_DIR}/Sources/DemoLoginPluginC/PluginEntry.c"
grep -q "pre-login shell unavailable, allowing native login" "${ROOT_DIR}/Sources/DemoLoginPluginC/PluginEntry.c"
grep -q "completed result=" "${ROOT_DIR}/Sources/DemoLoginPluginC/PluginEntry.c"
grep -q 'DemoLoginShell.app/Contents/MacOS/DemoLoginShell' "${ROOT_DIR}/Sources/DemoLoginPluginC/PluginEntry.c"
grep -q "launch_mode=plugin" "${ROOT_DIR}/Sources/DemoLoginShell/main.swift"
grep -q "appkit pre-login window shown" "${ROOT_DIR}/Sources/DemoLoginShellSupport/PluginPreLoginWindowController.swift"
grep -q "pre-login result written" "${ROOT_DIR}/Sources/DemoLoginShellSupport/PreLoginResultFileWriter.swift"
