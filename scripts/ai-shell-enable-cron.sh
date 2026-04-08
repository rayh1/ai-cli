#!/usr/bin/env bash
set -euo pipefail

if [[ "${EUID}" -ne 0 ]]; then
  echo "[ERROR] ai-shell-enable-cron must run as root." >&2
  exit 1
fi

pid_file="/var/run/crond.pid"

if pgrep -x cron >/dev/null 2>&1; then
  exit 0
fi

if [[ -f "${pid_file}" ]]; then
  rm -f "${pid_file}"
fi

/usr/sbin/cron