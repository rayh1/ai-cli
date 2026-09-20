#!/usr/bin/env bash
set -euo pipefail

target_user="${AI_CLI_TARGET_USER:-aiuser}"

start_comfy_local_proxy() {
  local local_url proxy_target listen_address target_address
  local listen_host listen_port target_host target_port socat_pid

  local_url="${COMFY_LOCAL_URL:-}"
  proxy_target="${COMFY_LOCAL_PROXY_TARGET_URL:-}"

  if [[ -z "${local_url}" || -z "${proxy_target}" ]]; then
    return 0
  fi

  listen_address="${local_url#http://}"
  listen_address="${listen_address%/}"
  target_address="${proxy_target#http://}"
  target_address="${target_address%/}"

  if [[ "${listen_address}" == "${target_address}" ]]; then
    return 0
  fi

  listen_host="${listen_address%:*}"
  listen_port="${listen_address##*:}"
  if [[ "${listen_host}" == "${listen_port}" ]]; then
    listen_host="127.0.0.1"
    listen_port="8188"
  fi

  target_host="${target_address%:*}"
  target_port="${target_address##*:}"
  if [[ "${target_host}" == "${target_port}" ]]; then
    target_port="8188"
  fi

  socat "TCP-LISTEN:${listen_port},fork,bind=${listen_host},reuseaddr" "TCP:${target_host}:${target_port}" &
  socat_pid=$!

  if ! kill -0 "${socat_pid}" 2>/dev/null; then
    echo "Failed to start Comfy local proxy ${listen_host}:${listen_port} -> ${target_host}:${target_port}" >&2
    wait "${socat_pid}" || true
    return 1
  fi
}

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

start_comfy_local_proxy

if [[ "$(id -u)" -eq 0 ]]; then
  ensure_docker_socket_access

  if [[ "${target_user}" == "root" ]]; then
    exec "$@"
  fi

  exec sudo -E -H -u "${target_user}" "$@"
fi

exec "$@"