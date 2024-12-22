#!/bin/bash

limit=$1
if [ -z "$limit" ]; then
  limit="all"
fi

ansible-playbook -i ansible/inventory/inventory.ini ansible/roles/python/plays/install_python.yml -l "$limit"
