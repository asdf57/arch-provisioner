#!/bin/bash

function create_key() {
    local key_path="$1"
    if [[ -f "$key_path" ]]; then
        echo "Found existing key at $key_path, copying it for docker build"
        cp "$key_path" .
    else
        echo "No key found at $key_path, creating a new one"
        ssh-keygen -t ed25519 -f "$key_path" -N "" -C "provisioning_key"
        cp "$key_path" .
    fi 
}

create_key ~/.ssh/provisioning_key
create_key ~/.ssh/git_provisioning_key

docker build -t prov:latest .

rm provisioning_key