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
  -framework CoreFoundation \
  "${ROOT_DIR}/scripts/tests/plugin_passthrough_harness.c" \
  "${ROOT_DIR}/Sources/DemoLoginPluginC/PluginEntry.c" \
  -o "${OUT_BIN}"

DEMO_LOGIN_SHELL_PATH="${ROOT_DIR}/scripts/tests/plugin_shell_helper.sh" \
PLUGIN_HELPER_ACTION="allow" \
EXPECT_RESULT="allow" \
EXPECT_CONTEXT_USERNAME="demouser" \
EXPECT_CONTEXT_PASSWORD="DemoPass123!" \
  "${OUT_BIN}"

DEMO_LOGIN_SHELL_PATH="${ROOT_DIR}/scripts/tests/plugin_shell_helper.sh" \
PLUGIN_HELPER_ACTION="deny" \
EXPECT_RESULT="deny" \
  "${OUT_BIN}"

DEMO_LOGIN_SHELL_PATH="${ROOT_DIR}/scripts/tests/plugin_shell_helper.sh" \
PLUGIN_HELPER_EXIT_CODE="1" \
EXPECT_RESULT="allow" \
  "${OUT_BIN}"

DEMO_LOGIN_SHELL_PATH="${ROOT_DIR}/scripts/tests/plugin_shell_helper.sh" \
PLUGIN_HELPER_SLEEP_SECONDS="3" \
DEMO_LOGIN_SHELL_TIMEOUT_SECONDS="1" \
EXPECT_RESULT="allow" \
  "${OUT_BIN}"
