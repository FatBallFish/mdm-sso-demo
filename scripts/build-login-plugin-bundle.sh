#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUTPUT_ROOT="${DEMO_PLUGIN_OUTPUT_ROOT:-${HOME}/Library/Caches/DemoSSO/plugin-dist}"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --output-root)
      OUTPUT_ROOT="$2"
      shift 2
      ;;
    *)
      echo "Unknown argument: $1" >&2
      exit 1
      ;;
  esac
done

BUNDLE_ROOT="${OUTPUT_ROOT}/DemoLoginPlugin.bundle"
CONTENTS_ROOT="${BUNDLE_ROOT}/Contents"
MACOS_ROOT="${CONTENTS_ROOT}/MacOS"
PLIST_PATH="${CONTENTS_ROOT}/Info.plist"
BINARY_PATH="${MACOS_ROOT}/DemoLoginPlugin"

mkdir -p "${MACOS_ROOT}"

clang \
  -fobjc-arc \
  -bundle \
  -I "${ROOT_DIR}/Sources/DemoLoginPluginC/include" \
  -framework Cocoa \
  -framework Security \
  -framework SecurityInterface \
  -framework CoreFoundation \
  "${ROOT_DIR}/Sources/DemoLoginPluginC/PluginEntry.c" \
  "${ROOT_DIR}/Sources/DemoLoginPluginC/PluginLoginView.m" \
  -o "${BINARY_PATH}"

cat > "${PLIST_PATH}" <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleIdentifier</key>
  <string>com.demo.sso.login-plugin</string>
  <key>CFBundleName</key>
  <string>DemoLoginPlugin</string>
  <key>CFBundleExecutable</key>
  <string>DemoLoginPlugin</string>
  <key>CFBundleVersion</key>
  <string>1</string>
  <key>CFBundleShortVersionString</key>
  <string>0.1.0</string>
  <key>CFBundlePackageType</key>
  <string>BNDL</string>
</dict>
</plist>
EOF

echo "${BUNDLE_ROOT}"
