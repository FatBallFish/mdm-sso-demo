#!/usr/bin/env bash
set -euo pipefail

RULE="system.login.console"
BACKUP_FILE=""
OUTPUT_PLIST=""
DRY_RUN=0
APPLY_LIVE=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run)
      DRY_RUN=1
      shift
      ;;
    --rule)
      RULE="$2"
      shift 2
      ;;
    --backup-file)
      BACKUP_FILE="$2"
      shift 2
      ;;
    --output-plist)
      OUTPUT_PLIST="$2"
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

if [[ -z "${BACKUP_FILE}" ]]; then
  echo "--backup-file is required" >&2
  exit 1
fi

if [[ "${DRY_RUN}" -eq 1 ]]; then
  echo "Would reset ${RULE} using backup ${BACKUP_FILE}"
  exit 0
fi

if [[ -n "${OUTPUT_PLIST}" ]]; then
  mkdir -p "$(dirname "${OUTPUT_PLIST}")"
  cp "${BACKUP_FILE}" "${OUTPUT_PLIST}"
fi

if [[ "${APPLY_LIVE}" -eq 1 ]]; then
  security authorizationdb write "${RULE}" < "${BACKUP_FILE}" >/dev/null
fi

if [[ -n "${OUTPUT_PLIST}" ]]; then
  echo "${OUTPUT_PLIST}"
else
  echo "${BACKUP_FILE}"
fi
