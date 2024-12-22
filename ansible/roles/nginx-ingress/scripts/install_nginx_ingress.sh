#!/bin/bash

ansible-playbook -i ansible/inventory/inventory.ini ansible/roles/nginx-ingress/plays/install.yml -e ansible_python_interpreter=/usr/local/bin/python
