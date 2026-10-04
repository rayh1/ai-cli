#!/usr/bin/env bash
set -euo pipefail

target_user="${AI_CLI_TARGET_USER:-aiuser}"

ensure_docker_socket_access() {
  local socket_path socket_gid socket_group

  if [[ "${target_user}" == "root" ]]; then
    return 0
  fi

  socket_path="/var/run/docker.sock"
  if [[ ! -S "${socket_path}" ]]; then
    return 0
  fi

  socket_gid="$(stat -c '%g' "${socket_path}")"
  socket_group="$(getent group "${socket_gid}" | cut -d: -f1 || true)"

  if [[ -z "${socket_group}" ]]; then
    socket_group="docker-host"
    groupadd --gid "${socket_gid}" "${socket_group}"
  fi

  if ! id -nG "${target_user}" | tr ' ' '\n' | grep -qx "${socket_group}"; then
    usermod -a -G "${socket_group}" "${target_user}"
  fi
}

if [[ "$(id -u)" -eq 0 ]]; then
  ensure_docker_socket_access

  if [[ "${target_user}" == "root" ]]; then
    exec "$@"
  fi

  exec sudo -E -H -u "${target_user}" "$@"
fi

exec "$@"