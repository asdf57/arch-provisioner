#!/usr/bin/env bash

# Set up the keiichi user and packages (build-time reqs) 
/homelab/scripts/build_setup.sh

env

# sudo -u keiichi bash -c "export GIT_PROVISIONING_KEY=\"${GIT_PROVISIONING_KEY}\" && cd /homelab && 
# if [[ -n "$command" ]]; then
#     /bin/bash -c "$command"
# else
#     /bin/bash --login
# fi
# "