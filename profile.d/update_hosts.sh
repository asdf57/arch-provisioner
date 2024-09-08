#!/bin/bash

INVENTORY_FILE="/home/condor/provision/ansible/inventory/inventory.yml"

yq eval '.servers.hosts | to_entries | .[] | .value.ansible_host + " " + .key' "$INVENTORY_FILE" | while read -r line; do
  if ! grep -q "$line" /etc/hosts; then
    echo "$line" | sudo tee -a /etc/hosts > /dev/null
  fi
done
