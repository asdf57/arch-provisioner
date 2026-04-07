#!/usr/bin/env bash

set -o pipefail

sudo mkdir -p /etc/ssh

sudo mkdir -p $MOUNTED_DATA_PATH

# Build the SSH config file
sudo tee /etc/ssh/ssh_config > /dev/null <<EOF
Host github.com
    User git
    IdentityFile /etc/ssh/git_provisioning_key
    StrictHostKeyChecking no
EOF

# Add github.com to known_hosts to indicate that we trust it (avoids host key checking prompt)
ssh-keyscan github.com 2>/dev/null | sudo tee -a /etc/ssh/ssh_known_hosts > /dev/null

echo ":: Configuring sudo env"
sudo tee /etc/sudoers.d/10-homelab-env > /dev/null <<EOF
Defaults env_keep += "SSH_AUTH_SOCK"
Defaults secure_path="/homelab/.venv/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
EOF
sudo chmod 0440 /etc/sudoers.d/10-homelab-env
sudo visudo -cf /etc/sudoers.d/10-homelab-env

# Grab the provisioning_key from Vault (kv2)
PROVISIONING_KEY=$(vault kv get -field=key kv2/provisioning/ssh/private)

# Reconstruct pubkey from private key
PROVISIONING_KEY_PUB=$(ssh-keygen -y -f <(echo "$PROVISIONING_KEY"))

if [[ -z "${GIT_PROVISIONING_KEY}" ]]; then
    GIT_PROVISIONING_KEY=$(vault kv get -field=key kv2/github/ssh/private)
fi

echo "$PROVISIONING_KEY" | sudo tee /etc/ssh/provisioning_key > /dev/null
echo "$PROVISIONING_KEY_PUB" | sudo tee /etc/ssh/provisioning_key.pub > /dev/null
echo "$GIT_PROVISIONING_KEY" | sudo tee /etc/ssh/git_provisioning_key > /dev/null

sudo chmod 600 /etc/ssh/provisioning_key
sudo chmod 600 /etc/ssh/git_provisioning_key

# Add our private keys into .ssh directory
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

# Add the priv keys to the agent
sudo ssh-add /etc/ssh/provisioning_key
sudo ssh-add /etc/ssh/git_provisioning_key

rm -rf inventory /tmp/hostvars /tmp/groupvars templates ansible/plays ansible/roles ansible/group_vars

git clone git@github.com:asdf57/ansible-roles.git /tmp/ansible &
git clone git@github.com:asdf57/inventory.git inventory &
git clone git@github.com:asdf57/hostvars.git /tmp/hostvars &
git clone git@github.com:asdf57/templates.git templates &
if [[ -n "${GIT_GROUPVARS_REPO}" ]]; then
    git clone --branch "${GIT_GROUPVARS_BRANCH:-main}" "${GIT_GROUPVARS_REPO}" /tmp/groupvars &
else
    echo ":: GIT_GROUPVARS_REPO is not set; init will render local group vars and can publish them later"
fi

wait

mkdir -p /homelab/inventory/group_vars
if [[ -d /tmp/groupvars/.git ]]; then
    find /tmp/groupvars -mindepth 1 -maxdepth 1 ! -name .git -exec cp -R {} /homelab/inventory/group_vars/ \;
else
    echo ":: Groupvars repo not available yet; continuing with init-generated group vars"
fi

mv /tmp/ansible/* /homelab/ansible/

rm -rf /tmp/ansible
rm -rf /tmp/groupvars

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

    root_ssh_key=$(vault kv get -field=key kv2/servers/$host/ssh/root/private 2>/dev/null || echo "")
    if [[ -n "$root_ssh_key" ]]; then
        echo "$root_ssh_key" | sudo tee /etc/ssh/id_${host}_root > /dev/null
        sudo chmod 604 /etc/ssh/id_${host}_root
    fi

    users=$(yq eval '.users[].username' hostvars.yml 2>/dev/null || echo "")

    echo ":: Pulling SSH keys for users on host: $host"
    for user in $users; do
        user_ssh_key=$(vault kv get -field=key kv2/servers/$host/ssh/$user/private 2>/dev/null || echo "")
        if [[ -n "$user_ssh_key" ]]; then
            echo "$user_ssh_key" | sudo tee /etc/ssh/id_${host}_${user} > /dev/null
            sudo chmod 604 /etc/ssh/id_${host}_${user}
        fi
    done

    if [[ -z "${GIT_PROVISIONING_KEY}" ]]; then
        GIT_PROVISIONING_KEY=$(vault kv get -field=key kv2/github/ssh/private)
    fi

    if [[ -z "${GIT_PROVISIONING_KEY}.pub" ]]; then
        GIT_PROVISIONING_KEY_PUB=$(vault kv get -field=key kv2/github/ssh/public)
    fi

    echo "$PROVISIONING_KEY" | sudo tee /etc/ssh/provisioning_key > /dev/null

    ip_addr=$(ansible-inventory -i $inventory_path/inventory.yml --host "$host" | jq -r '.ansible_host')
    # if not empty and not equal to null
    if [[ -n "$ip_addr" && "$ip_addr" != "null" ]]; then
        echo "$ip_addr    $host" | sudo tee -a /etc/hosts >/dev/null

        sudo tee -a /etc/ssh/ssh_config >/dev/null <<EOF
Host $host
    HostName $ip_addr
    StrictHostKeyChecking accept-new
    IdentityFile ~/.ssh/provisioning_key
    IdentityFile /etc/ssh/id_${host}_root
EOF

        for user in $users; do
            if [[ -f "/etc/ssh/id_${host}_${user}" ]]; then
                sudo tee -a /etc/ssh/ssh_config >/dev/null <<EOF
    IdentityFile /etc/ssh/id_${host}_${user}
EOF
            fi
        done

        # Root access via IP
        sudo tee -a /etc/ssh/ssh_config >/dev/null <<EOF

Host $ip_addr
    StrictHostKeyChecking accept-new
    IdentityFile ~/.ssh/provisioning_key
    IdentityFile /etc/ssh/id_${host}_root
EOF

        for user in $users; do
            if [[ -f "/etc/ssh/id_${host}_${user}" ]]; then
                sudo tee -a /etc/ssh/ssh_config >/dev/null <<EOF
    IdentityFile /etc/ssh/id_${host}_${user}
EOF
            fi
        done
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
