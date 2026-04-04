#!/usr/bin/env bash
set -euo pipefail

target_user="${AI_SHELL_TARGET_USER:-aiuser}"

if [[ -n "${AI_SHELL_SSH_PASSWORD:-}" ]]; then
  /usr/local/bin/ai-shell-enable-ssh
fi

if [[ "${target_user}" == "root" ]]; then
  exec bash "$@"
fi

exec sudo -E -H -u "${target_user}" bash "$@"