#!/usr/bin/env bash

set -uo pipefail

host="$1"
if [[ -z "$host" ]]; then
    echo "Need to specify host!"
    exit 1
fi

git clone git@github.com:asdf57/hostvars.git /tmp/hostvars

mkdir -p inventory/host_vars

inventory_path=$(realpath inventory)
hv_path=$(realpath inventory/host_vars)

cd /tmp/hostvars
echo "=> Pulling hostvars for $host"
git switch $host >/dev/null 2>&1
git pull  >/dev/null 2>&1
cp hostvars.yml "$hv_path/$host.yml"
