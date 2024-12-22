#!/bin/bash

# Setup script for the arch-provisioner Docker environment

eval "$(ssh-agent -s)" >/dev/null 2>&1

chmod 600 /home/condor/.ssh/*
chmod 644 /home/condor/.ssh/*.pub

ssh-add /home/condor/.ssh/provisioning_key >/dev/null 2>&1
ssh-add /home/condor/.ssh/git_provisioning_key >/dev/null 2>&1

# Set prompt for bash
export PS1="[\u@\h]: "

# Pull dotfiles from GitHub
git clone git@github.com:asdf57/dotfiles.git /home/condor/dotfiles

mkdir -p /home/condor/.kube

ansible -b -i /home/condor/provision/ansible/inventory/inventory.ini -m fetch -a "src=/home/root/.kube/config dest=/home/condor/.kube/config flat=yes" kube_coords[0]

# Ensure kube config is not group or world readable
chmod 600 /home/condor/.kube/config

find /home/condor/provision/ansible/roles/ -type f -path '*/scripts/*' -exec cp {} /home/condor/provision \;


export PYTHONPATH=/usr/local/lib/python3.12/site-packages:$PYTHONPATH
export KUBECONFIG="/home/condor/.kube/config"

echo "======================="
echo "      hss v0.1.0"
echo -e "=======================\n"
