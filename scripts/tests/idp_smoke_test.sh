#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
PORT="${DEMO_IDP_TEST_PORT:-48081}"
LOG_FILE="${ROOT_DIR}/.idp-smoke.log"

cleanup() {
  if [[ -n "${SERVER_PID:-}" ]]; then
    kill "${SERVER_PID}" 2>/dev/null || true
  fi
}
trap cleanup EXIT

DEMO_IDP_PORT="${PORT}" "${ROOT_DIR}/scripts/start-demo-idp.sh" >"${LOG_FILE}" 2>&1 &
SERVER_PID=$!

for _ in {1..20}; do
  if curl -sf "http://127.0.0.1:${PORT}/api/health" >/dev/null; then
    break
  fi
  sleep 1
done

HEALTH="$(curl -sf "http://127.0.0.1:${PORT}/api/health")"
LOGIN="$(curl -sf \
  -H "Content-Type: application/json" \
  -d '{"username":"demo.user","password":"DemoPass123!"}' \
  "http://127.0.0.1:${PORT}/api/login")"

echo "${HEALTH}" | grep -q '"status":"ok"'
echo "${LOGIN}" | grep -q '"subject":"demo.user"'
