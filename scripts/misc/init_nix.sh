#!/usr/bin/env bash

# Nix environment setup to be run inside the unshared, chrooted environment

adduser -u 1000 -D keiichi

echo 'keiichi ALL=(ALL) NOPASSWD: ALL' > /etc/sudoers.d/keiichi
chmod 0440 /etc/sudoers.d/keiichi

mkdir -p /nix /nix/var/nix
chown -R keiichi:keiichi /nix /etc/nix /homelab /home/keiichi

# Start the Nix daemon in the background
# nix-daemon &
# NIX_DAEMON_PID=$!

# Give it a moment to start
# sleep 1

cd /homelab && uv venv .venv && uv sync && cd -

# Run the command as keiichi without -i (no interactive login shell)
# export GIT_PROVISIONING_KEY
# export VAULT_ADDR
# export VAULT_TOKEN
# export HOME=/home/keiichi

# sudo -u keiichi bash -c "export GIT_PROVISIONING_KEY=\"${GIT_PROVISIONING_KEY}\" && cd /homelab && scripts/nix_setup.sh '$command'"

# Clean up
# kill $NIX_DAEMON_PID 2>/dev/null || true
