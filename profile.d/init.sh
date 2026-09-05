#!/usr/bin/env bash

ssh-keyscan github.com >> ~/.ssh/known_hosts

mkdir -p /home/keiichi/.ssh /home/keiichi/inventory

cp $MOUNT_GIT_SSH_KEY_PATH /home/keiichi/.ssh/id_github

git clone git@github.com:asdf57/inventory.git -b $INVENTORY_PUBLICATION_GROUP /homelab/inventory
