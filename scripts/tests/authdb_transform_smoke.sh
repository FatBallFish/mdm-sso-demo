#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
FIXTURE="${ROOT_DIR}/scripts/tests/fixtures/system.login.console.plist"
OUTPUT_PLIST="$(mktemp)"
SECOND_OUTPUT="$(mktemp)"
trap 'rm -f "${OUTPUT_PLIST}" "${SECOND_OUTPUT}"' EXIT

"${ROOT_DIR}/scripts/configure-loginwindow-authdb.sh" \
  --source-plist "${FIXTURE}" \
  --output-plist "${OUTPUT_PLIST}" >/dev/null

grep -q "DemoLoginPlugin:login" "${OUTPUT_PLIST}"
if grep -q "DemoLoginPlugin:login,privileged" "${OUTPUT_PLIST}"; then
  echo "plugin mechanism should not be privileged for pre-login UI" >&2
  exit 1
fi

LOGIN_LINE="$(grep -n "loginwindow:login" "${OUTPUT_PLIST}" | head -n1 | cut -d: -f1)"
PLUGIN_LINE="$(grep -n "DemoLoginPlugin:login" "${OUTPUT_PLIST}" | head -n1 | cut -d: -f1)"
BEGIN_LINE="$(grep -n "builtin:login-begin" "${OUTPUT_PLIST}" | head -n1 | cut -d: -f1)"

[[ "${PLUGIN_LINE}" -lt "${LOGIN_LINE}" ]]
[[ "${PLUGIN_LINE}" -lt "${BEGIN_LINE}" ]]

"${ROOT_DIR}/scripts/configure-loginwindow-authdb.sh" \
  --source-plist "${OUTPUT_PLIST}" \
  --output-plist "${SECOND_OUTPUT}" >/dev/null

COUNT="$(grep -c "DemoLoginPlugin:login" "${SECOND_OUTPUT}")"
[[ "${COUNT}" -eq 1 ]]
