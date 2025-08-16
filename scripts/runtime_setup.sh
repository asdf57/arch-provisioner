#!/usr/bin/env bash

set -uo pipefail

mkdir -p /root/.ssh
chmod 700 /root/.ssh

# Build the SSH config file
cat <<EOF > /root/.ssh/config
Host github.com
    User git
    IdentityFile /root/.ssh/provisioning_key
    StrictHostKeyChecking no
EOF

ssh-keyscan github.com >> /root/.ssh/known_hosts


# Grab the provisioning_key from Vault (kv2)
PROVISIONING_KEY=$(vault kv get -field=key kv2/provisioning/ssh/private)
GIT_PROVISIONING_KEY=$(vault kv get -field=key kv2/github/ssh/private)

echo "$PROVISIONING_KEY" > /root/.ssh/provisioning_key
echo "$GIT_PROVISIONING_KEY" > /root/.ssh/git_provisioning_key

chmod 600 /root/.ssh/provisioning_key
chmod 600 /root/.ssh/git_provisioning_key

# Start up the SSH agent
eval $(ssh-agent -s)

ssh-add /root/.ssh/provisioning_key
ssh-add /root/.ssh/git_provisioning_key

rm -rf inventory /tmp/hostvars templates

git clone git@github.com:asdf57/inventory.git inventory &
git clone git@github.com:asdf57/hostvars.git /tmp/hostvars &
git clone git@github.com:asdf57/templates.git templates &

wait

mkdir -p inventory/host_vars

inventory_path=$(realpath inventory)

hv_path=$(realpath inventory/host_vars)
hosts=$(ansible-inventory -i $inventory_path/inventory.yml --list | jq -r '._meta.hostvars | keys[]')

cd /tmp/hostvars
for host in $hosts; do
    echo "=> Pulling hostvars for $host"
    git switch $host >/dev/null 2>&1
    cp hostvars.yml "$hv_path/$host.yml"

    ip_addr=$(ansible-inventory -i $inventory_path/inventory.yml --host "$host" | jq -r '.ansible_host')
    # if not empty and not equal to null
    if [[ -n "$ip_addr" && "$ip_addr" != "null" ]]; then
        echo "$ip_addr    $host" >> /etc/hosts

        # Also add an entry to ssh config
        cat <<EOF >> /root/.ssh/config
Host $host
    User root
    IdentityFile /root/.ssh/provisioning_key
    IdentityFile /root/.ssh/id_$host
    StrictHostKeyChecking no
    IdentitiesOnly yes
EOF

        cat <<EOF >> /root/.ssh/config
Host $ip_addr
    User root
    IdentityFile /root/.ssh/provisioning_key
    StrictHostKeyChecking no
    IdentitiesOnly yes
EOF
    fi
done
cd -

rm -rf /tmp/hostvars

pwd

# Set the PS1 prompt
./scripts/server_stats.sh &

while [ ! -s "/tmp/server_stats/reachability" ]; do :; done

source ./scripts/generate_prompt.sh
