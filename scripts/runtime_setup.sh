#!/usr/bin/env bash

set -uo pipefail

query_servers() {
    while true; do
        ips=($(ansible-inventory -i inventory/inventory.yml --list | jq -r '._meta.hostvars | to_entries[] | .value.ansible_host'))
        num_up=0
        count=${#ips[@]}
        for ip in "${ips[@]}"; do
            if [[ -z "$ip" ]] || [[ "$ip" == "null" ]]; then
                continue
            fi
            ping -c 1 "$ip" >/dev/null 2>&1
            if [ $? -eq 0 ]; then
                num_up=$((num_up + 1))
            fi
        done

        mkdir -p /tmp/server_stats
        echo "$num_up:$count" > /tmp/server_stats/reachability
        sleep 5
    done
}

get_prompt() {    
    local reachability=$(cat /tmp/server_stats/reachability)
    IFS=':' read -r num_up total <<< "$reachability"
    echo "$num_up/$total↑ \$ "
}

whoami=$(whoami)

mkdir -p /home/$whoami/.ssh
chmod 700 /home/$whoami/.ssh

# Build the SSH config file
cat <<EOF > /home/$whoami/.ssh/config
Host github.com
    User git
    IdentityFile /root/.ssh/provisioning_key
    StrictHostKeyChecking no
EOF

ssh-keyscan github.com >> /home/$whoami/.ssh/known_hosts

# Grab the provisioning_key from Vault (kv2)
PROVISIONING_KEY=$(vault kv get -field=key kv2/provisioning/ssh/private)
GIT_PROVISIONING_KEY=$(vault kv get -field=key kv2/github/ssh/private)

echo "$PROVISIONING_KEY" > /home/$whoami/.ssh/provisioning_key
echo "$GIT_PROVISIONING_KEY" > /home/$whoami/.ssh/git_provisioning_key

chmod 600 /home/$whoami/.ssh/provisioning_key
chmod 600 /home/$whoami/.ssh/git_provisioning_key

# Start up the SSH agent
eval $(ssh-agent -s)

ssh-add /home/$whoami/.ssh/provisioning_key
ssh-add /home/$whoami/.ssh/git_provisioning_key

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
    git pull  >/dev/null 2>&1
    cp hostvars.yml "$hv_path/$host.yml"

    ip_addr=$(ansible-inventory -i $inventory_path/inventory.yml --host "$host" | jq -r '.ansible_host')
    # if not empty and not equal to null
    if [[ -n "$ip_addr" && "$ip_addr" != "null" ]]; then
        echo "$ip_addr    $host" | sudo tee -a /etc/hosts >/dev/null

        # Also add an entry to ssh config
        cat <<EOF >> /home/$whoami/.ssh/config
Host $host
    User root
    IdentityFile /home/$whoami/.ssh/provisioning_key
    IdentityFile /home/$whoami/.ssh/id_$host
    StrictHostKeyChecking no
    IdentitiesOnly yes
EOF

        cat <<EOF >> /home/$whoami/.ssh/config
Host $ip_addr
    User root
    IdentityFile /home/$whoami/.ssh/provisioning_key
    StrictHostKeyChecking no
    IdentitiesOnly yes
EOF
    fi
done
cd -

rm -rf /tmp/hostvars

# Set the PS1 prompt
query_servers &

# Wait until the first stats are available
while [ ! -s "/tmp/server_stats/reachability" ]; do :; done

export PS1="$(get_prompt)"
