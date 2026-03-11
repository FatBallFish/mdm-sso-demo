#!/usr/bin/env bash
set -euo pipefail

INSTALL_ROOT="/"
DRY_RUN=0
KEEP_STATE=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run)
      DRY_RUN=1
      shift
      ;;
    --root)
      INSTALL_ROOT="$2"
      shift 2
      ;;
    --keep-state)
      KEEP_STATE=1
      shift
      ;;
    *)
      echo "Unknown argument: $1" >&2
      exit 1
      ;;
  esac
done

APP_SUPPORT_ROOT="${INSTALL_ROOT}/Library/Application Support/DemoSSO"
PLUGIN_BUNDLE="${INSTALL_ROOT}/Library/Security/SecurityAgentPlugins/DemoLoginPlugin.bundle"
AUTHDB_ROOT="${APP_SUPPORT_ROOT}/authdb"

if [[ "${DRY_RUN}" -eq 1 ]]; then
  echo "Would restore native loginwindow behavior"
  echo "Would remove ${PLUGIN_BUNDLE}"
  echo "Would remove ${APP_SUPPORT_ROOT}/bin (including DemoLoginShell.app), ${APP_SUPPORT_ROOT}/config, and ${AUTHDB_ROOT}"
  if [[ "${KEEP_STATE}" -eq 1 ]]; then
    echo "Would preserve ${APP_SUPPORT_ROOT}/state"
  else
    echo "Would remove ${APP_SUPPORT_ROOT}/state"
  fi
  exit 0
fi

rm -rf "${PLUGIN_BUNDLE}"
rm -rf "${APP_SUPPORT_ROOT}/bin" "${APP_SUPPORT_ROOT}/config" "${AUTHDB_ROOT}"
if [[ "${KEEP_STATE}" -ne 1 ]]; then
  rm -rf "${APP_SUPPORT_ROOT}/state"
fi

echo "Removed demo artifacts under ${INSTALL_ROOT}"
