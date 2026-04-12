#!/usr/bin/env bash

set -euo pipefail

umask 077

log() {
    echo ":: $*"
}

warn() {
    echo ":: $*" >&2
}

require_env() {
    local name

    for name in "$@"; do
        if [[ -z "${!name:-}" ]]; then
            echo "Missing required environment variable: $name" >&2
            exit 1
        fi
    done
}

clone_repo() {
    local repo="$1"
    local branch="$2"
    local dest="$3"

    git clone --branch "$branch" "$repo" "$dest"
}

vault_can_read() {
    vault kv get -field=key "$1" >/dev/null 2>&1
}

cleanup() {
    rm -rf /tmp/ansible /tmp/hostvars /tmp/groupvars
}

trap cleanup EXIT

export PATH="/homelab/.venv/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
export ANSIBLE_INVENTORY="/homelab/inventory/inventory.yml"
export ANSIBLE_ROLES_PATH="/homelab/ansible/roles"
export ANSIBLE_FILTER_PLUGINS="/homelab/ansible/filter_plugins"
export ANSIBLE_HOST_KEY_CHECKING=False
export IS_BOOTSTRAP_ENV="${IS_BOOTSTRAP_ENV:-false}"
export GIT_INVENTORY_REPO="${GIT_INVENTORY_REPO:-git@github.com:asdf57/inventory.git}"
export GIT_INVENTORY_BRANCH="${GIT_INVENTORY_BRANCH:-main}"
export GIT_GROUPVARS_REPO="${GIT_GROUPVARS_REPO:-git@github.com:asdf57/groupvars.git}"
export GIT_GROUPVARS_BRANCH="${GIT_GROUPVARS_BRANCH:-main}"
export GIT_ANSIBLE_ROLES_REPO="${GIT_ANSIBLE_ROLES_REPO:-git@github.com:asdf57/ansible-roles.git}"
export GIT_ANSIBLE_ROLES_BRANCH="${GIT_ANSIBLE_ROLES_BRANCH:-main}"
export GIT_HOSTVARS_REPO="${GIT_HOSTVARS_REPO:-git@github.com:asdf57/hostvars.git}"
export GIT_HOSTVARS_BRANCH="${GIT_HOSTVARS_BRANCH:-main}"
export GIT_TEMPLATES_REPO="${GIT_TEMPLATES_REPO:-git@github.com:asdf57/homelab-templates.git}"
export GIT_TEMPLATES_BRANCH="${GIT_TEMPLATES_BRANCH:-main}"

if [[ "${IS_BOOTSTRAP_ENV}" == "true" ]]; then
    require_env MOUNTED_DATA_PATH
fi

sudo mkdir -p /etc/ssh

if [[ "${IS_BOOTSTRAP_ENV}" == "true" ]]; then
    sudo mkdir -p "$MOUNTED_DATA_PATH"
fi

sudo tee /etc/ssh/ssh_config > /dev/null <<EOF
Host github.com
    User git
    IdentityFile /etc/ssh/git_provisioning_key
    IdentitiesOnly yes
    StrictHostKeyChecking accept-new
EOF

# Ensure github.com's SSH host key is in the known_hosts file to prevent MITM prompts during provisioning
if ! sudo ssh-keygen -F github.com -f /etc/ssh/ssh_known_hosts >/dev/null 2>&1; then
    ssh-keyscan github.com 2>/dev/null | sudo tee -a /etc/ssh/ssh_known_hosts > /dev/null
fi

log "Configuring sudo env"
sudo tee /etc/sudoers.d/10-homelab-env > /dev/null <<EOF
Defaults secure_path="/homelab/.venv/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
EOF
sudo chmod 0440 /etc/sudoers.d/10-homelab-env
sudo visudo -cf /etc/sudoers.d/10-homelab-env

vault_kv_available=false
if [[ -n "${VAULT_ADDR:-}" ]] && vault_can_read kv2/provisioning/ssh/private; then
    vault_kv_available=true
else
    warn "Vault is not reachable or not authenticated! SSH keys will not be pulled from Vault."
fi

if sudo test -r /etc/ssh/provisioning_key; then
    PROVISIONING_KEY="$(sudo cat /etc/ssh/provisioning_key)"
elif [[ "$vault_kv_available" == true ]]; then
    PROVISIONING_KEY="$(vault kv get -field=key kv2/provisioning/ssh/private)"
    echo "$PROVISIONING_KEY" | sudo tee /etc/ssh/provisioning_key > /dev/null
    sudo chmod 600 /etc/ssh/provisioning_key
else
    echo "Missing /etc/ssh/provisioning_key and Vault is unavailable." >&2
    exit 1
fi

if sudo test -r /etc/ssh/provisioning_key.pub; then
    PROVISIONING_KEY_PUB="$(sudo cat /etc/ssh/provisioning_key.pub)"
else
    # If we don't provide the pubkey, regenerate it from the private key
    PROVISIONING_KEY_PUB="$(ssh-keygen -y -f <(echo "$PROVISIONING_KEY"))"
    echo "$PROVISIONING_KEY_PUB" | sudo tee /etc/ssh/provisioning_key.pub > /dev/null
    sudo chmod 644 /etc/ssh/provisioning_key.pub
fi

if sudo test -r /etc/ssh/git_provisioning_key; then
    GIT_PROVISIONING_KEY="$(sudo cat /etc/ssh/git_provisioning_key)"
elif [[ "$vault_kv_available" == true ]]; then
    GIT_PROVISIONING_KEY="${GIT_PROVISIONING_KEY:-$(vault kv get -field=key kv2/github/ssh/private)}"
    echo "$GIT_PROVISIONING_KEY" | sudo tee /etc/ssh/git_provisioning_key > /dev/null
    sudo chmod 600 /etc/ssh/git_provisioning_key
else
    echo "Missing /etc/ssh/git_provisioning_key and Vault is unavailable." >&2
    exit 1
fi

mkdir -p ~/.ssh
chmod 700 ~/.ssh
echo "$PROVISIONING_KEY" > ~/.ssh/provisioning_key
chmod 600 ~/.ssh/provisioning_key

if sudo test -r "${DROPLET_SSH_KEY_PATH:-/etc/ssh/droplet_key}"; then
    sudo cat "${DROPLET_SSH_KEY_PATH:-/etc/ssh/droplet_key}" > ~/.ssh/id_droplet
    chmod 600 ~/.ssh/id_droplet

    if sudo test -r "${DROPLET_SSH_KEY_PATH:-/etc/ssh/droplet_key}.pub"; then
        sudo cat "${DROPLET_SSH_KEY_PATH:-/etc/ssh/droplet_key}.pub" > ~/.ssh/id_droplet.pub
        chmod 644 ~/.ssh/id_droplet.pub
    fi
fi

rm -rf inventory templates ansible/plays ansible/roles ansible/group_vars

clone_repo "$GIT_ANSIBLE_ROLES_REPO" "$GIT_ANSIBLE_ROLES_BRANCH" /tmp/ansible &
clone_repo "$GIT_INVENTORY_REPO" "$GIT_INVENTORY_BRANCH" inventory &
clone_repo "$GIT_HOSTVARS_REPO" "$GIT_HOSTVARS_BRANCH" /tmp/hostvars &
clone_repo "$GIT_TEMPLATES_REPO" "$GIT_TEMPLATES_BRANCH" templates &
clone_repo "$GIT_GROUPVARS_REPO" "$GIT_GROUPVARS_BRANCH" /tmp/groupvars &

wait

mkdir -p /homelab/inventory/group_vars
find /tmp/groupvars -mindepth 1 -maxdepth 1 ! -name .git -exec cp -R {} /homelab/inventory/group_vars/ \;

mv /tmp/ansible/* /homelab/ansible/

cp -r /homelab/ansible/roles/*/scripts/* . 2>/dev/null || true

mkdir -p inventory/host_vars
inventory_path=$(realpath inventory)
hv_path=$(realpath inventory/host_vars)
hosts=$(ansible-inventory -i "$inventory_path/inventory.yml" --list | jq -r '._meta.hostvars | keys[]')

cd /tmp/hostvars
for host in $hosts; do
    log "Pulling hostvars for $host"
    if ! git switch "$host" >/dev/null 2>&1; then
        log "No hostvars branch for $host; skipping"
        continue
    fi

    git pull --ff-only >/dev/null 2>&1
    cp hostvars.yml "$hv_path/$host.yml"

    # If this DNE, will be created and uploaded to Vault during server provisioning
    root_ssh_key=""
    if [[ "$vault_kv_available" == true ]]; then
        root_ssh_key=$(vault kv get -field=key kv2/servers/$host/ssh/root/private 2>/dev/null || echo "")
    fi
    if [[ -n "$root_ssh_key" ]]; then
        echo "$root_ssh_key" | sudo tee /etc/ssh/id_${host}_root > /dev/null
        sudo chmod 600 /etc/ssh/id_${host}_root
    else
        warn "No root SSH key found for host $host; skipping"
    fi

    users=$(yq eval '.users[].name' hostvars.yml 2>/dev/null || echo "")

    log "Pulling SSH keys for users on host: $host"
    for user in $users; do
        user_ssh_key=$(vault kv get -field=key kv2/servers/$host/ssh/$user/private 2>/dev/null || echo "")
        if [[ "$vault_kv_available" != true ]]; then
            user_ssh_key=""
        fi
        if [[ -n "$user_ssh_key" ]]; then
            echo "$user_ssh_key" | sudo tee /etc/ssh/id_${host}_${user} > /dev/null
            sudo chmod 600 /etc/ssh/id_${host}_${user}
        else
            warn "No SSH key found for user $user on host $host; skipping"
        fi
    done

    ip_addr=$(ansible-inventory -i "$inventory_path/inventory.yml" --host "$host" | jq -r '.ansible_host')
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
cd - >/dev/null

if [[ -n "${CONCOURSE_TARGET:-}" && -n "${CONCOURSE_URL:-}" && -n "${CONCOURSE_USER:-}" && -n "${CONCOURSE_PASSWORD:-}" ]]; then
    if ! fly -t "$CONCOURSE_TARGET" status >/dev/null 2>&1; then
        log "Attempting Concourse login for target $CONCOURSE_TARGET"
        if ! fly -t "$CONCOURSE_TARGET" login \
            -c "$CONCOURSE_URL" \
            -u "$CONCOURSE_USER" \
            -p "$CONCOURSE_PASSWORD"; then
            warn "Concourse login failed; continuing bootstrap"
        fi
    fi
fi
