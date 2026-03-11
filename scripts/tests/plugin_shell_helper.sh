#!/usr/bin/env bash
set -euo pipefail

RESULT_FILE=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --plugin-result-file)
      RESULT_FILE="$2"
      shift 2
      ;;
    --plugin-idp-base-url)
      shift 2
      ;;
    *)
      shift
      ;;
  esac
done

if [[ -z "${RESULT_FILE}" ]]; then
  echo "missing --plugin-result-file" >&2
  exit 2
fi

if [[ "${PLUGIN_HELPER_EXIT_CODE:-0}" != "0" ]]; then
  exit "${PLUGIN_HELPER_EXIT_CODE}"
fi

if [[ -n "${PLUGIN_HELPER_SLEEP_SECONDS:-}" ]]; then
  sleep "${PLUGIN_HELPER_SLEEP_SECONDS}"
fi

ACTION="${PLUGIN_HELPER_ACTION:-allow}"
USERNAME="${PLUGIN_HELPER_USERNAME:-demouser}"
PASSWORD="${PLUGIN_HELPER_PASSWORD:-DemoPass123!}"
MESSAGE="${PLUGIN_HELPER_MESSAGE:-SSO authentication failed.}"

cat > "${RESULT_FILE}" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>action</key>
  <string>${ACTION}</string>
EOF

if [[ "${ACTION}" == "allow" ]]; then
  cat >> "${RESULT_FILE}" <<EOF
  <key>username</key>
  <string>${USERNAME}</string>
  <key>localShortName</key>
  <string>${USERNAME}</string>
  <key>password</key>
  <string>${PASSWORD}</string>
EOF
fi

if [[ "${ACTION}" == "deny" ]]; then
  cat >> "${RESULT_FILE}" <<EOF
  <key>message</key>
  <string>${MESSAGE}</string>
EOF
fi

cat >> "${RESULT_FILE}" <<'EOF'
</dict>
</plist>
EOF
