#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
PORT="${DEMO_IDP_TEST_PORT:-48086}"
STATE_ROOT="${ROOT_DIR}/.broker-state"
IDP_LOG="${ROOT_DIR}/.broker-idp.log"
DAEMON_PATH="${ROOT_DIR}/.build/arm64-apple-macosx/debug/DemoAccountSyncDaemon"

cleanup() {
  if [[ -n "${SERVER_PID:-}" ]]; then
    kill "${SERVER_PID}" 2>/dev/null || true
  fi
}
trap cleanup EXIT

rm -rf "${STATE_ROOT}"

DEMO_IDP_PORT="${PORT}" "${ROOT_DIR}/scripts/start-demo-idp.sh" >"${IDP_LOG}" 2>&1 &
SERVER_PID=$!

for _ in {1..20}; do
  if curl -sf "http://127.0.0.1:${PORT}/api/health" >/dev/null; then
    break
  fi
  sleep 1
done

INITIAL_OUTPUT="$(
  cd "${ROOT_DIR}" && \
  env HOME="${ROOT_DIR}/.home" XDG_CACHE_HOME="${ROOT_DIR}/.swiftpm-cache" CLANG_MODULE_CACHE_PATH="${ROOT_DIR}/.cache/clang" \
    swift run DemoLoginBroker \
    --username demo.user \
    --password DemoPass123! \
    --idp-base-url "http://127.0.0.1:${PORT}/" \
    --state-root "${STATE_ROOT}" \
    --daemon "${DAEMON_PATH}"
)"

echo "${INITIAL_OUTPUT}" | grep -q '"action":"promptForAccountBinding"'

printf '%s' '{"action":"createLocalAccount","subject":"demo.user","suggestedLocalShortName":"demouser","password":"DemoPass123!"}' | \
  DEMO_SSO_STATE_ROOT="${STATE_ROOT}" "${DAEMON_PATH}" --stdio-json >/dev/null

FINAL_OUTPUT="$(
  cd "${ROOT_DIR}" && \
  env HOME="${ROOT_DIR}/.home" XDG_CACHE_HOME="${ROOT_DIR}/.swiftpm-cache" CLANG_MODULE_CACHE_PATH="${ROOT_DIR}/.cache/clang" \
    swift run DemoLoginBroker \
    --username demo.user \
    --password DemoPass123! \
    --idp-base-url "http://127.0.0.1:${PORT}/" \
    --state-root "${STATE_ROOT}" \
    --daemon "${DAEMON_PATH}"
)"

echo "${FINAL_OUTPUT}" | grep -q '"action":"allowLogin"'
echo "${FINAL_OUTPUT}" | grep -q '"localShortName":"demouser"'
