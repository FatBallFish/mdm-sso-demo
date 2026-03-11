#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
INSTALL_ROOT="/"
DRY_RUN=0
ENABLE_AUTHDB=0

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
    --enable-authdb)
      ENABLE_AUTHDB=1
      shift
      ;;
    --no-authdb)
      ENABLE_AUTHDB=0
      shift
      ;;
    *)
      echo "Unknown argument: $1" >&2
      exit 1
      ;;
  esac
done

APP_SUPPORT_ROOT="${INSTALL_ROOT}/Library/Application Support/DemoSSO"
PLUGIN_ROOT="${INSTALL_ROOT}/Library/Security/SecurityAgentPlugins"
BIN_ROOT="${APP_SUPPORT_ROOT}/bin"
CONFIG_ROOT="${APP_SUPPORT_ROOT}/config"
STATE_ROOT="${APP_SUPPORT_ROOT}/state"
AUTHDB_ROOT="${APP_SUPPORT_ROOT}/authdb"
DIST_ROOT="${ROOT_DIR}/dist"
PLUGIN_BUNDLE_PATH="${DIST_ROOT}/DemoLoginPlugin.bundle"

run_swift_build() {
  mkdir -p "${ROOT_DIR}/.home" "${ROOT_DIR}/.swiftpm-cache" "${ROOT_DIR}/.cache/clang"
  (
    cd "${ROOT_DIR}"
    env \
      HOME="${ROOT_DIR}/.home" \
      XDG_CACHE_HOME="${ROOT_DIR}/.swiftpm-cache" \
      CLANG_MODULE_CACHE_PATH="${ROOT_DIR}/.cache/clang" \
      swift build >/dev/null
  )
}

copy_file() {
  local src="$1"
  local dst="$2"
  mkdir -p "$(dirname "${dst}")"
  install -m 0755 "${src}" "${dst}"
}

if [[ "${DRY_RUN}" -eq 1 ]]; then
  echo "Would build Swift executables with swift build"
  echo "Would build DemoLoginPlugin.bundle under ${DIST_ROOT}"
  echo "Would copy LoginPlugin bundle into ${PLUGIN_ROOT}/"
  echo "Would install DemoAccountSyncDaemon, DemoLoginBroker, DemoLoginShell under ${BIN_ROOT}/"
  echo "Would write demo-idp.json into ${CONFIG_ROOT}/"
  echo "Would create state directory ${STATE_ROOT}/"
  if [[ "${ENABLE_AUTHDB}" -eq 1 ]]; then
    echo "Would back up and transform system.login.console into ${AUTHDB_ROOT}/"
    echo "Would leave live authorizationdb unchanged unless an explicit live apply step is added"
  else
    echo "Would leave loginwindow auth chain unchanged unless --enable-authdb is supplied"
  fi
  exit 0
fi

run_swift_build
"${ROOT_DIR}/scripts/build-login-plugin-bundle.sh" --output-root "${DIST_ROOT}" >/dev/null

mkdir -p "${PLUGIN_ROOT}" "${BIN_ROOT}" "${CONFIG_ROOT}" "${STATE_ROOT}" "${AUTHDB_ROOT}"
ditto "${PLUGIN_BUNDLE_PATH}" "${PLUGIN_ROOT}/DemoLoginPlugin.bundle"
copy_file "${ROOT_DIR}/.build/arm64-apple-macosx/debug/DemoAccountSyncDaemon" "${BIN_ROOT}/DemoAccountSyncDaemon"
copy_file "${ROOT_DIR}/.build/arm64-apple-macosx/debug/DemoLoginBroker" "${BIN_ROOT}/DemoLoginBroker"
copy_file "${ROOT_DIR}/.build/arm64-apple-macosx/debug/DemoLoginShell" "${BIN_ROOT}/DemoLoginShell"
install -m 0644 "${ROOT_DIR}/configs/demo-idp.json" "${CONFIG_ROOT}/demo-idp.json"

if [[ "${ENABLE_AUTHDB}" -eq 1 ]]; then
  "${ROOT_DIR}/scripts/configure-loginwindow-authdb.sh" \
    --backup-file "${AUTHDB_ROOT}/system.login.console.backup.plist" \
    --output-plist "${AUTHDB_ROOT}/system.login.console.demo.plist" >/dev/null
fi

echo "Installed demo artifacts under ${INSTALL_ROOT}"
