#!/bin/bash

# Setup script for the arch-provisioner Docker environment

eval "$(ssh-agent -s)" >/dev/null 2>&1
ssh-add /home/condor/.ssh/arch_provisioning_key >/dev/null 2>&1

# Set prompt for bash
export PS1="[\u@\h]: "

echo "======================="
echo "      hss v0.1.0"
echo -e "=======================\n"
