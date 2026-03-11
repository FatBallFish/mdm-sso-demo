#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
OUT_BIN="$(mktemp "${TMPDIR:-/tmp}/demo-plugin-harness.XXXXXX")"
trap 'rm -f "${OUT_BIN}"' EXIT

clang \
  -fobjc-arc \
  -I "${ROOT_DIR}/Sources/DemoLoginPluginC/include" \
  -framework Cocoa \
  -framework Security \
  -framework SecurityInterface \
  -framework CoreFoundation \
  "${ROOT_DIR}/scripts/tests/plugin_passthrough_harness.c" \
  "${ROOT_DIR}/Sources/DemoLoginPluginC/PluginEntry.c" \
  "${ROOT_DIR}/Sources/DemoLoginPluginC/PluginLoginView.m" \
  -o "${OUT_BIN}"

DEMO_PLUGIN_TEST_MODE="allow" \
EXPECT_RESULT="allow" \
EXPECT_CONTEXT_USERNAME="demouser" \
EXPECT_CONTEXT_PASSWORD="DemoPass123!" \
  "${OUT_BIN}"

DEMO_PLUGIN_TEST_MODE="deny" \
EXPECT_RESULT="deny" \
  "${OUT_BIN}"
