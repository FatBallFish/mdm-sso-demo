#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

grep -q "showing pre-login view" "${ROOT_DIR}/Sources/DemoLoginPluginC/PluginEntry.c"
grep -q "failed creating login view" "${ROOT_DIR}/Sources/DemoLoginPluginC/PluginEntry.c"
grep -q "displayView failed status=" "${ROOT_DIR}/Sources/DemoLoginPluginC/PluginEntry.c"
grep -q "pre-login view unavailable, allowing native login" "${ROOT_DIR}/Sources/DemoLoginPluginC/PluginEntry.c"
grep -q "completed result=" "${ROOT_DIR}/Sources/DemoLoginPluginC/PluginEntry.c"
grep -q "pre-login validate success pressed" "${ROOT_DIR}/Sources/DemoLoginPluginC/PluginLoginView.m"
grep -q "pre-login validate failure pressed" "${ROOT_DIR}/Sources/DemoLoginPluginC/PluginLoginView.m"
grep -q "pre-login cancel pressed" "${ROOT_DIR}/Sources/DemoLoginPluginC/PluginLoginView.m"
grep -q "pre-login validate success applying credentials" "${ROOT_DIR}/Sources/DemoLoginPluginC/PluginLoginView.m"
