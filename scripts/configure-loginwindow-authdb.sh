#!/usr/bin/env bash
set -euo pipefail

RULE="system.login.console"
MECHANISM="DemoLoginPlugin:login"
SOURCE_PLIST=""
OUTPUT_PLIST=""
BACKUP_FILE=""
APPLY_LIVE=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --rule)
      RULE="$2"
      shift 2
      ;;
    --mechanism)
      MECHANISM="$2"
      shift 2
      ;;
    --source-plist)
      SOURCE_PLIST="$2"
      shift 2
      ;;
    --output-plist)
      OUTPUT_PLIST="$2"
      shift 2
      ;;
    --backup-file)
      BACKUP_FILE="$2"
      shift 2
      ;;
    --apply-live)
      APPLY_LIVE=1
      shift
      ;;
    *)
      echo "Unknown argument: $1" >&2
      exit 1
      ;;
  esac
done

if [[ -z "${OUTPUT_PLIST}" ]]; then
  echo "--output-plist is required" >&2
  exit 1
fi

cleanup() {
  if [[ -n "${TEMP_SOURCE:-}" && -f "${TEMP_SOURCE}" ]]; then
    rm -f "${TEMP_SOURCE}"
  fi
}
trap cleanup EXIT

load_source() {
  if [[ -n "${SOURCE_PLIST}" ]]; then
    echo "${SOURCE_PLIST}"
    return
  fi

  TEMP_SOURCE="$(mktemp)"
  security authorizationdb read "${RULE}" > "${TEMP_SOURCE}"
  echo "${TEMP_SOURCE}"
}

read_mechanisms() {
  local plist_path="$1"
  /usr/libexec/PlistBuddy -c "Print :mechanisms" "${plist_path}" | \
    sed '1d;$d' | sed 's/^[[:space:]]*//'
}

build_output() {
  local source_path="$1"
  local output_path="$2"

  local mechanisms=()
  while IFS= read -r line; do
    mechanisms+=("${line}")
  done < <(read_mechanisms "${source_path}")

  local found=0
  local anchor_index=-1
  for i in "${!mechanisms[@]}"; do
    if [[ "${mechanisms[$i]}" == "${MECHANISM}" ]]; then
      found=1
    fi
    if [[ "${mechanisms[$i]}" == "loginwindow:login" ]]; then
      anchor_index="${i}"
    fi
  done

  if [[ "${found}" -eq 0 ]]; then
    if [[ "${anchor_index}" -ge 0 ]]; then
      mechanisms=(
        "${mechanisms[@]:0:$((anchor_index))}"
        "${MECHANISM}"
        "${mechanisms[@]:$((anchor_index))}"
      )
    else
      mechanisms+=("${MECHANISM}")
    fi
  fi

  mkdir -p "$(dirname "${output_path}")"
  cp "${source_path}" "${output_path}"
  /usr/libexec/PlistBuddy -c "Delete :mechanisms" "${output_path}" >/dev/null 2>&1 || true
  /usr/libexec/PlistBuddy -c "Add :mechanisms array" "${output_path}"

  for i in "${!mechanisms[@]}"; do
    /usr/libexec/PlistBuddy -c "Add :mechanisms:${i} string ${mechanisms[$i]}" "${output_path}"
  done
}

SOURCE_PATH="$(load_source)"

if [[ -n "${BACKUP_FILE}" ]]; then
  mkdir -p "$(dirname "${BACKUP_FILE}")"
  cp "${SOURCE_PATH}" "${BACKUP_FILE}"
fi

build_output "${SOURCE_PATH}" "${OUTPUT_PLIST}"

if [[ "${APPLY_LIVE}" -eq 1 ]]; then
  security authorizationdb write "${RULE}" < "${OUTPUT_PLIST}" >/dev/null
fi

echo "${OUTPUT_PLIST}"
