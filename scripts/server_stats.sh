#!/usr/bin/env bash

set -uo pipefail

while true; do
    ips=($(ansible-inventory -i inventory/inventory.yml --list | jq -r '._meta.hostvars | to_entries[] | .value.ansible_host'))
    num_up=0
    count=${#ips[@]}
    for ip in "${ips[@]}"; do
        if [[ -z "$ip" ]] || [[ "$ip" == "null" ]]; then
            continue
        fi
        ping -c 1 "$ip" >/dev/null 2>&1
        if [ $? -eq 0 ]; then
            num_up=$((num_up + 1))
        fi
    done

    mkdir -p /tmp/server_stats
    echo "$num_up:$count" > /tmp/server_stats/reachability
    sleep 5
done