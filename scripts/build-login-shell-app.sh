#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUTPUT_ROOT="${DEMO_LOGIN_SHELL_OUTPUT_ROOT:-${HOME}/Library/Caches/DemoSSO/login-shell-dist}"
BIN_ROOT=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --output-root)
      OUTPUT_ROOT="$2"
      shift 2
      ;;
    --bin-root)
      BIN_ROOT="$2"
      shift 2
      ;;
    *)
      echo "Unknown argument: $1" >&2
      exit 1
      ;;
  esac
done

if [[ -z "${BIN_ROOT}" ]]; then
  echo "--bin-root is required" >&2
  exit 1
fi

APP_ROOT="${OUTPUT_ROOT}/DemoLoginShell.app"
CONTENTS_ROOT="${APP_ROOT}/Contents"
MACOS_ROOT="${CONTENTS_ROOT}/MacOS"
PLIST_PATH="${CONTENTS_ROOT}/Info.plist"
BINARY_PATH="${MACOS_ROOT}/DemoLoginShell"
SOURCE_BINARY="${BIN_ROOT}/DemoLoginShell"

rm -rf "${APP_ROOT}"
mkdir -p "${MACOS_ROOT}"
install -m 0755 "${SOURCE_BINARY}" "${BINARY_PATH}"

cat > "${PLIST_PATH}" <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleIdentifier</key>
  <string>com.demo.sso.login-shell</string>
  <key>CFBundleName</key>
  <string>DemoLoginShell</string>
  <key>CFBundleDisplayName</key>
  <string>DemoLoginShell</string>
  <key>CFBundleExecutable</key>
  <string>DemoLoginShell</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleShortVersionString</key>
  <string>0.1.0</string>
  <key>CFBundleVersion</key>
  <string>1</string>
  <key>LSMinimumSystemVersion</key>
  <string>13.0</string>
</dict>
</plist>
EOF

if command -v xattr >/dev/null 2>&1; then
  xattr -cr "${APP_ROOT}" 2>/dev/null || true
fi

if command -v codesign >/dev/null 2>&1; then
  codesign --force --sign - "${APP_ROOT}" >/dev/null 2>&1 || true
fi

echo "${APP_ROOT}"
