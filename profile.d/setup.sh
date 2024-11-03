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
git clone git@github.com:asdf57/dotfiles.git /home/condor/dotfiles #>/dev/null 2>&1

mkdir -p /home/condor/.kube
ansible -b -i /home/condor/provision/ansible/inventory/inventory.yml -m fetch -a "src=/home/raspusr/.kube/config dest=/home/condor/.kube/config flat=yes" kube_coords[0]
echo "======================="
echo "      hss v0.1.0"
echo -e "=======================\n"
