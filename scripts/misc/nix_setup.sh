#!/usr/bin/env bash

command="$1"

echo ":: Enabling Nix flake support"
echo "experimental-features = nix-command flakes" >> /etc/nix/nix.conf
echo "sandbox = false" >> /etc/nix/nix.conf

# echo "source scripts/runtime_setup.sh" >> /home/keiichi/.bashrc

# export BASH_ENV="/home/keiichi/.bashrc"
# export PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:$PATH"

echo ":: Entering Nix development environment"
if [[ -n "$command" ]]; then
    nix --accept-flake-config develop --command bash -c "$command"
else
    echo -e "yoshi\n\n"
    nix --accept-flake-config develop --command bash
fi
