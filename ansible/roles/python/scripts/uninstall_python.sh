#!/bin/bash

limit=$1
if [ -z "$limit" ]; then
  limit="all"
fi

ansible-playbook -i ansible/inventory/inventory.ini ansible/roles/python/plays/uninstall_python.yml -l "$limit"
