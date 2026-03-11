#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
PLUGIN_VIEW="${ROOT_DIR}/Sources/DemoLoginPluginC/PluginLoginView.m"

grep -q 'Validate Success' "${PLUGIN_VIEW}"
grep -q 'Validate Failure' "${PLUGIN_VIEW}"
grep -q 'Back To macOS Login' "${PLUGIN_VIEW}"
grep -q 'Demo validation failed\.' "${PLUGIN_VIEW}"
grep -q 'pre-login validate success pressed' "${PLUGIN_VIEW}"
grep -q 'pre-login validate failure pressed' "${PLUGIN_VIEW}"
grep -q 'pre-login cancel pressed' "${PLUGIN_VIEW}"

if grep -q 'NSSecureTextField \*passwordField' "${PLUGIN_VIEW}"; then
  echo "password field should be removed from in-process plugin view" >&2
  exit 1
fi

if grep -q 'NSTextField \*usernameField' "${PLUGIN_VIEW}"; then
  echo "username field should be removed from in-process plugin view" >&2
  exit 1
fi

if grep -q 'validateUsername:' "${PLUGIN_VIEW}"; then
  echo "network validation path should be removed from in-process plugin view" >&2
  exit 1
fi
