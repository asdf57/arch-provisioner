#!/usr/bin/env bash

set -uo pipefail

trap cleanup EXIT

cleanup(){
    rm alpine-minirootfs-3.22.0-x86_64.tar.gz
    rm -rf rootfs/
    rm -rf inventory/
}

echo ":: Creating rootfs directory"
mkdir -p rootfs

# Grab a lightweight rootfs (can be anything -- I chose Alpine Linux)
echo ":: Pulling Alpine Linux rootfs"
wget https://dl-cdn.alpinelinux.org/alpine/v3.22/releases/x86_64/alpine-minirootfs-3.22.0-x86_64.tar.gz > /dev/null 2>&1

echo ":: Extracting rootfs"
tar -xzf alpine-minirootfs-3.22.0-x86_64.tar.gz -C rootfs  > /dev/null 2>&1

# Fake myself as root to add user
echo ":: Setting up proot environment"
proot -r rootfs -0 -b /proc -b /dev -b /sys -b /etc/resolv.conf:/etc/resolv.conf -b ./:/prov -w "/home" /bin/sh -c "/sbin/apk add --no-cache bash nix shadow && /usr/sbin/adduser -u 1000 -D keiichi" > /dev/null 2>&1

# Use login shell to properly set up the PATH and rm inherited env vars
echo ":: Setting up nix environment"
proot -r rootfs -b /proc -b /dev -b /sys -b /nix -b /etc/resolv.conf:/etc/resolv.conf -b ./:/prov -w "/prov" env -i VAULT_ADDR="${VAULT_ADDR}" VAULT_TOKEN="${VAULT_TOKEN}" /bin/bash scripts/nix_setup.sh
