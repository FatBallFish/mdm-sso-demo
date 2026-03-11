#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

grep -q "showing pre-login view" "${ROOT_DIR}/Sources/DemoLoginPluginC/PluginEntry.c"
grep -q "auth_source=http" "${ROOT_DIR}/Sources/DemoLoginPluginC/PluginLoginView.m"
grep -q "auth_source=fallback" "${ROOT_DIR}/Sources/DemoLoginPluginC/PluginLoginView.m"
grep -q "completed result=" "${ROOT_DIR}/Sources/DemoLoginPluginC/PluginEntry.c"
