#!/bin/bash

# Setup script for the arch-provisioner Docker environment

eval "$(ssh-agent -s)"
ssh-add /home/condor/.ssh/arch_provisioning_key

echo "arch-provisioner v0.1.0"
echo "======================="
