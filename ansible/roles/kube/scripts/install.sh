#!/bin/bash

ansible-playbook -i ansible/inventory/inventory.yml ansible/plays/install_kube.yml -l $1
