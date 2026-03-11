#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

grep -q "showing pre-login shell" "${ROOT_DIR}/Sources/DemoLoginPluginC/PluginEntry.c"
grep -q "auth_source=http" "${ROOT_DIR}/Sources/DemoLoginPluginSupport/PluginCredentialValidator.swift"
grep -q "auth_source=fallback" "${ROOT_DIR}/Sources/DemoLoginPluginSupport/PluginCredentialValidator.swift"
grep -q "completed result=" "${ROOT_DIR}/Sources/DemoLoginPluginC/PluginEntry.c"
