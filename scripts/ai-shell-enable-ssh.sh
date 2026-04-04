#!/usr/bin/env bash
set -euo pipefail

if [[ "${EUID}" -ne 0 ]]; then
  echo "[ERROR] ai-shell-enable-ssh must run as root." >&2
  exit 1
fi

if [[ -z "${AI_SHELL_SSH_PASSWORD:-}" ]]; then
  echo "[ERROR] AI_SHELL_SSH_PASSWORD is required." >&2
  exit 1
fi

install -d -m 0755 /run/sshd
install -d -m 0755 /etc/ssh/sshd_config.d

cat > /etc/ssh/sshd_config.d/ai-cli.conf <<'EOF'
PasswordAuthentication yes
KbdInteractiveAuthentication no
PermitRootLogin no
UsePAM yes
EOF

ssh-keygen -A >/dev/null
printf 'aiuser:%s\n' "${AI_SHELL_SSH_PASSWORD}" | chpasswd

if pgrep -x sshd >/dev/null 2>&1; then
  pkill -x sshd
fi

/usr/sbin/sshd