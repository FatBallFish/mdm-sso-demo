#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

OUTPUT="$("${ROOT_DIR}/scripts/install-jamf-style-demo.sh" --dry-run)"
echo "${OUTPUT}" | grep -q "SecurityAgentPlugins"
