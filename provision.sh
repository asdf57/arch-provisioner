#!/bin/bash

ansible-playbook -i 'localhost,' \
  -e 'ansible_host=localhost \
      ansible_port=60022 \
      ansible_user=root \
      ansible_ssh_private_key_file=~/.ssh/arch_provisioning_key \
      disk_device=/dev/vda' \
  ansible/playbooks/pre_install.yml
