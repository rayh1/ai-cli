#!/usr/bin/env bash
set -euo pipefail

target_user="${AI_SHELL_TARGET_USER:-${AI_CLI_TARGET_USER:-aiuser}}"

if [[ -n "${AI_SHELL_ENABLE_CRON:-}" ]]; then
  /usr/local/bin/ai-shell-enable-cron
fi

if [[ -n "${AI_SHELL_SSH_PASSWORD:-}" ]]; then
  /usr/local/bin/ai-shell-enable-ssh
fi

export AI_CLI_TARGET_USER="${target_user}"
exec /usr/local/bin/ai-cli-entrypoint bash "$@"