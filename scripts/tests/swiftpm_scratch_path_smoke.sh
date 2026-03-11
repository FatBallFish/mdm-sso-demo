#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

grep -q -- "--scratch-path" "${ROOT_DIR}/scripts/start-demo-idp.sh"
grep -q -- "--scratch-path" "${ROOT_DIR}/scripts/start-login-shell.sh"
grep -q -- "--scratch-path" "${ROOT_DIR}/scripts/run-login-broker.sh"
grep -q -- "DEMO_ACCOUNTSYNC_DAEMON_PATH" "${ROOT_DIR}/scripts/start-login-shell.sh"
grep -q -- "run-login-broker.sh" "${ROOT_DIR}/scripts/tests/login_broker_smoke.sh"
if grep -q -- '\.build/arm64-apple-macosx/debug/DemoAccountSyncDaemon' "${ROOT_DIR}/scripts/tests/login_broker_smoke.sh"; then
  exit 1
fi
