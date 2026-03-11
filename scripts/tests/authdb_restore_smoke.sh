#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
BACKUP_FILE="${ROOT_DIR}/scripts/tests/fixtures/system.login.console.plist"
OUTPUT_FILE="$(mktemp)"
trap 'rm -f "${OUTPUT_FILE}"' EXIT

"${ROOT_DIR}/scripts/restore-native-loginwindow.sh" \
  --backup-file "${BACKUP_FILE}" \
  --output-plist "${OUTPUT_FILE}" >/dev/null

cmp -s "${BACKUP_FILE}" "${OUTPUT_FILE}"
