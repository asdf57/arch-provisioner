#!/usr/bin/env bash

echo ":: Enabling Nix flake support"
echo "experimental-features = nix-command flakes" >> /etc/nix/nix.conf

echo "source scripts/runtime_setup.sh" >> /home/keiichi/.bashrc

echo ":: Entering Nix development environment"
nix --accept-flake-config develop --command bash
