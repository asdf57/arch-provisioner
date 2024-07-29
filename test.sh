#!/bin/bash

set -eux

ssh-keygen -R "[localhost]:60022"
./testvm.sh -u -i out/archlinux-2024.06.19-x86_64.iso -n 10G -c 10 -r 8192 &

# ansible-playbook -i 'localhost,' \
#   -e 'ansible_host=localhost' \
#   -e 'ansible_port=60022' \
#   -e 'ansible_user=root' \
#   -e 'ansible_ssh_private_key_file=~/.ssh/arch_provisioning_key' \
#   -e 'disk_device=/dev/vda' \
#   -e 'boot_partition_min=1MiB' \
#   -e 'boot_partition_max=512MiB' \
#   -e 'swap_partition_min=512MiB' \
#   -e 'swap_partition_max=2.5GiB' \
#   -e 'root_partition_min=2.5GiB' \
#   -e 'root_partition_max=100%' \
#   -e 'root_filesystem=ext4' \
#   -e 'root_password=abc123' \
#   -e 'locale=en_US.UTF-8' \
#   -e 'hostname=archhost' \
#   -e 'username=archuser' \
#   -e 'password=sss2' \
#   ansible/playbooks/main.yml -vvv

