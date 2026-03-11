#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

if grep -q 'OUTPUT_ROOT="\${ROOT_DIR}/dist"' "${ROOT_DIR}/scripts/build-login-plugin-bundle.sh"; then
  exit 1
fi

if grep -q 'DIST_ROOT="\${ROOT_DIR}/dist"' "${ROOT_DIR}/scripts/install-jamf-style-demo.sh"; then
  exit 1
fi
