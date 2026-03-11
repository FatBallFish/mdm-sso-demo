#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

grep -q "showing pre-login shell" "${ROOT_DIR}/Sources/DemoLoginPluginC/PluginEntry.c"
grep -q "spawned login shell" "${ROOT_DIR}/Sources/DemoLoginPluginC/PluginEntry.c"
grep -q "pre-login shell unavailable, allowing native login" "${ROOT_DIR}/Sources/DemoLoginPluginC/PluginEntry.c"
grep -q "completed result=" "${ROOT_DIR}/Sources/DemoLoginPluginC/PluginEntry.c"
