#!/usr/bin/env bash

set -euo pipefail

user_file="${1:-.env}"
runtime_file="${2:-.env.runtime}"

if [[ ! -f "$user_file" ]]; then
  echo "User env file $user_file does not exist." >&2
  exit 1
fi

if [[ "$(uname -s)" != "Linux" ]]; then
  echo "render_env.sh currently supports Linux nodes only." >&2
  exit 1
fi

detect_docker_gid() {
  local gid

  gid="$(getent group docker | cut -d: -f3 || true)"
  if [[ -n "$gid" ]]; then
    printf '%s\n' "$gid"
    return
  fi

  if [[ -S /var/run/docker.sock ]]; then
    stat -c '%g' /var/run/docker.sock
    return
  fi

  echo "Unable to detect DOCKER_GID. Ensure Docker is installed and running." >&2
  exit 1
}

detect_network_interface() {
  local iface

  iface="$(ip route show default 2>/dev/null | awk '/default/ {print $5; exit}')"
  if [[ -n "$iface" ]]; then
    printf '%s\n' "$iface"
    return
  fi

  iface="$(ip -o link show | awk -F': ' '$2 != "lo" {print $2; exit}')"
  if [[ -n "$iface" ]]; then
    printf '%s\n' "$iface"
    return
  fi

  echo "Unable to detect NETWORK_INTERFACE." >&2
  exit 1
}

detect_homelab_gid() {
  local existing_gid
  local gid=2000

  existing_gid="$(getent group homelab | cut -d: -f3 || true)"
  if [[ -n "$existing_gid" ]]; then
    printf '%s\n' "$existing_gid"
    return
  fi

  while getent group "$gid" > /dev/null 2>&1; do
    gid=$((gid + 1))
  done

  printf '%s\n' "$gid"
}

set -a
source "$user_file"
set +a

if [[ -z "${HOST_DATA_PATH:-}" ]]; then
  echo "HOST_DATA_PATH must be set in $user_file" >&2
  exit 1
fi

if [[ -z "${HOST_GIT_PROVISIONING_KEY_FILE:-}" ]]; then
  echo "HOST_GIT_PROVISIONING_KEY_FILE must be set in $user_file" >&2
  exit 1
fi

if [[ -z "${HOST_PROVISIONING_KEY_FILE:-}" ]]; then
  echo "HOST_PROVISIONING_KEY_FILE must be set in $user_file" >&2
  exit 1
fi

cp "$user_file" "$runtime_file"

DOCKER_GID="$(detect_docker_gid)"
HOMELAB_GID="$(detect_homelab_gid)"
NETWORK_INTERFACE="$(detect_network_interface)"

cat >> "$runtime_file" <<EOF

DOCKER_GID=$DOCKER_GID
HOMELAB_GID=$HOMELAB_GID
NETWORK_INTERFACE=$NETWORK_INTERFACE
MOUNTED_DATA_PATH=$HOST_DATA_PATH
GIT_SSH_KEY_PATH=/etc/ssh/git_provisioning_key
PROVISIONING_SSH_KEY_PATH=/etc/ssh/provisioning_key
EOF

echo ":: Rendered $runtime_file from $user_file"
