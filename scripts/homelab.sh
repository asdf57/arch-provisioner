#!/bin/bash

# We need to switch to the parent directory of the script to execute
# the ansible-playbook command correctly.
cd "$(dirname "$0")/.."

if [[ $# -eq 0 ]]; then
    echo "Usage: $0 <init_full|init_build|init_cleanup|provision> <args>"
    exit 1
fi

command="$1"
shift

if [[ ! " init_full init_build init_cleanup provision " =~ " $command " ]]; then
    echo "Invalid command: $command"
    echo "Usage: $0 <init_full|init_build|provision>"
    exit 1
fi

case $command in
    init_full)
        echo "Running init_full"
        ansible-playbook ansible/plays/init.yml -i localhost --ask-become-pass
        ;;
    init_build)
        echo "Running init_build"
        ansible-playbook ansible/plays/init.yml -i localhost --ask-become-pass --tags build
        ;;
    init_cleanup)
        echo "Running init_cleanup"
        ansible-playbook ansible/plays/init.yml -i localhost --ask-become-pass --tags clean
        ;;
    provision)
        echo "Running provision"
        vault_root_password="$1"
        if [[ -z "$vault_root_password" ]]; then
            echo "Usage: $0 provision <vault_root_password>"
            exit 1
        fi
        ansible-playbook -i inventory/inventory.yml ansible/plays/provision.yml -e "vault_root_password=$vault_root_password"
        ;;
esac
