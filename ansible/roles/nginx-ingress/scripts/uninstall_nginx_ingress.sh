#!/bin/bash

ansible-playbook -i ansible/inventory/inventory.ini ansible/roles/nginx-ingress/plays/uninstall.yml
