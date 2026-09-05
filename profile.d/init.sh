#!/usr/bin/env bash

export PATH="/homelab/.venv/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
export ANSIBLE_INVENTORY="/homelab/inventory/inventory.yml"
export ANSIBLE_ROLES_PATH="/homelab/ansible/roles"
export ANSIBLE_FILTER_PLUGINS="/homelab/ansible/filter_plugins"
export ANSIBLE_HOST_KEY_CHECKING=False

ssh-keyscan github.com >> ~/.ssh/known_hosts

mkdir -p /home/keiichi/.ssh /home/keiichi/inventory

cp $MOUNT_GIT_SSH_KEY_PATH /home/keiichi/.ssh/id_github

git clone git@github.com:asdf57/inventory.git -b $INVENTORY_PUBLICATION_GROUP /homelab/inventory
