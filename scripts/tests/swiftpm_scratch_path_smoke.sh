#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

grep -q -- "--scratch-path" "${ROOT_DIR}/scripts/start-demo-idp.sh"
grep -q -- "--scratch-path" "${ROOT_DIR}/scripts/start-login-shell.sh"
grep -q -- "DEMO_ACCOUNTSYNC_DAEMON_PATH" "${ROOT_DIR}/scripts/start-login-shell.sh"
