#!/bin/bash

ansible-playbook -i ansible/inventory/inventory.ini ansible/roles/grafana/plays/uninstall.yml
