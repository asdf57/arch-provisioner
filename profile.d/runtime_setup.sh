#!/usr/bin/env bash

set -o pipefail

export PATH=/homelab/.venv/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
export PYTHONPATH="/homelab/.venv/lib/python3.12/site-packages"
export ANSIBLE_INVENTORY="/homelab/inventory/inventory.yml"
export ANSIBLE_ROLES_PATH="/homelab/ansible/roles"
export ANSIBLE_FILTER_PLUGINS="/homelab/ansible/filter_plugins"
export ANSIBLE_HOST_KEY_CHECKING=False

sudo mkdir -p /etc/ssh

sudo mkdir -p $MOUNTED_DATA_PATH

# Build the SSH config file
sudo tee /etc/ssh/ssh_config > /dev/null <<EOF
Host github.com
    User git
    IdentityFile /etc/ssh/git_provisioning_key
    StrictHostKeyChecking no
EOF

ssh-keyscan github.com 2>/dev/null | sudo tee -a /etc/ssh/ssh_known_hosts > /dev/null

echo ":: Configuring sudo to preserve PATH"
sudo tee /etc/sudoers > /dev/null <<EOF
root ALL=(ALL:ALL) ALL

## Uncomment to allow members of group wheel to execute any command
%wheel ALL=(ALL:ALL) ALL

## Same thing without a password
# %wheel ALL=(ALL:ALL) NOPASSWD: ALL

## Keep the PATH env var when we invoke sudo
Defaults    env_keep += "PATH SSH_AUTH_SOCK"

## Read drop-in files from /etc/sudoers.d
@includedir /etc/sudoers.d

Defaults env_keep += "PATH"
EOF

# Grab the provisioning_key from Vault (kv2)
PROVISIONING_KEY=$(vault kv get -field=key kv2/provisioning/ssh/private)

if [[ -z "${GIT_PROVISIONING_KEY}" ]]; then
    GIT_PROVISIONING_KEY=$(vault kv get -field=key kv2/github/ssh/private)
fi

echo "$PROVISIONING_KEY" | sudo tee /etc/ssh/provisioning_key > /dev/null
echo "$GIT_PROVISIONING_KEY" | sudo tee /etc/ssh/git_provisioning_key > /dev/null

sudo chmod 600 /etc/ssh/provisioning_key
sudo chmod 600 /etc/ssh/git_provisioning_key

mkdir -p ~/.ssh
echo "$PROVISIONING_KEY" > ~/.ssh/provisioning_key
echo "$GIT_PROVISIONING_KEY" > ~/.ssh/git_provisioning_key
chmod 600 ~/.ssh/provisioning_key
chmod 600 ~/.ssh/git_provisioning_key

# Start SSH agent with a socket accessible to all users
# Kill existing agent if the socket already exists
if [[ -S /tmp/ssh-agent.sock ]]; then
    echo ":: Removing existing SSH agent socket"
    sudo rm -f /tmp/ssh-agent.sock
fi

# Start up the SSH agent
eval $(ssh-agent -s -a /tmp/ssh-agent.sock)
sudo chmod 666 /tmp/ssh-agent.sock
export SSH_AUTH_SOCK=/tmp/ssh-agent.sock


sudo ssh-add /etc/ssh/provisioning_key
sudo ssh-add /etc/ssh/git_provisioning_key

rm -rf inventory /tmp/hostvars templates


git clone git@github.com:asdf57/ansible-roles.git /tmp/ansible &
git clone git@github.com:asdf57/inventory.git inventory &
git clone git@github.com:asdf57/hostvars.git /tmp/hostvars &
git clone git@github.com:asdf57/templates.git templates &

wait

mv /tmp/ansible/* /homelab/ansible/

# Copy all scripts from each roles script directory to cwd
cp -r /homelab/ansible/roles/*/scripts/* . 2>/dev/null || true

mkdir -p inventory/host_vars

inventory_path=$(realpath inventory)

hv_path=$(realpath inventory/host_vars)
hosts=$(ansible-inventory -i $inventory_path/inventory.yml --list | jq -r '._meta.hostvars | keys[]')

cd /tmp/hostvars
for host in $hosts; do
    echo "=> Pulling hostvars for $host"
    git switch $host >/dev/null 2>&1
    git pull  >/dev/null 2>&1
    cp hostvars.yml "$hv_path/$host.yml"

    ip_addr=$(ansible-inventory -i $inventory_path/inventory.yml --host "$host" | jq -r '.ansible_host')
    # if not empty and not equal to null
    if [[ -n "$ip_addr" && "$ip_addr" != "null" ]]; then
        echo "$ip_addr    $host" | sudo tee -a /etc/hosts >/dev/null

        # Also add an entry to ssh config
        sudo tee -a /etc/ssh/ssh_config >/dev/null <<EOF
Host $host
    User root
    IdentityFile ~/.ssh/provisioning_key
    IdentityFile /ssh/id_$host
    StrictHostKeyChecking no
    IdentitiesOnly yes
EOF

        sudo tee -a /etc/ssh/ssh_config >/dev/null <<EOF
Host $ip_addr
    User root
    IdentityFile ~/.ssh/provisioning_key
    StrictHostKeyChecking no
    IdentitiesOnly yes
EOF
    fi
done
cd -

rm -rf /tmp/hostvars

echo $PATH

# Set the global path in /etc/profile
echo "export PATH=\"\$PATH\"" | sudo tee -a /etc/profile >/dev/null

fly -t test login \
      -c https://ci.ryuugu.dev \
      -u test \
      -p test
