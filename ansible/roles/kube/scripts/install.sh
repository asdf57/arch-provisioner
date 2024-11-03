#!/bin/bash

ansible-playbook -i ansible/inventory/inventory.yml ansible/plays/install_kube.yml -l $1 -e "ghcr_token=$GHCR_TOKEN"
