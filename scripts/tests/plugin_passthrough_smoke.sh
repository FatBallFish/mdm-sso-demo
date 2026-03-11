#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
OUT_BIN="$(mktemp "${TMPDIR:-/tmp}/demo-plugin-harness.XXXXXX")"
STUB_ALLOW="$(mktemp "${TMPDIR:-/tmp}/demo-plugin-allow.XXXXXX")"
STUB_DENY="$(mktemp "${TMPDIR:-/tmp}/demo-plugin-deny.XXXXXX")"
trap 'rm -f "${OUT_BIN}" "${STUB_ALLOW}" "${STUB_DENY}"' EXIT

cat > "${STUB_ALLOW}" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
RESULT_FILE=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --plugin-result-file)
      RESULT_FILE="$2"
      shift 2
      ;;
    *)
      shift
      ;;
  esac
done
cat > "${RESULT_FILE}" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>action</key>
  <string>allow</string>
  <key>localShortName</key>
  <string>demouser</string>
  <key>password</key>
  <string>DemoPass123!</string>
  <key>username</key>
  <string>demouser</string>
</dict>
</plist>
PLIST
EOF

cat > "${STUB_DENY}" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
RESULT_FILE=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --plugin-result-file)
      RESULT_FILE="$2"
      shift 2
      ;;
    *)
      shift
      ;;
  esac
done
cat > "${RESULT_FILE}" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>action</key>
  <string>deny</string>
  <key>message</key>
  <string>SSO authentication failed.</string>
</dict>
</plist>
PLIST
EOF

chmod +x "${STUB_ALLOW}" "${STUB_DENY}"

clang \
  -I "${ROOT_DIR}/Sources/DemoLoginPluginC/include" \
  -framework Security \
  -framework CoreFoundation \
  "${ROOT_DIR}/scripts/tests/plugin_passthrough_harness.c" \
  "${ROOT_DIR}/Sources/DemoLoginPluginC/PluginEntry.c" \
  -o "${OUT_BIN}"

DEMO_LOGIN_SHELL_PATH="${STUB_ALLOW}" \
EXPECT_RESULT="allow" \
EXPECT_CONTEXT_USERNAME="demouser" \
EXPECT_CONTEXT_PASSWORD="DemoPass123!" \
  "${OUT_BIN}"

DEMO_LOGIN_SHELL_PATH="${STUB_DENY}" \
EXPECT_RESULT="deny" \
  "${OUT_BIN}"
