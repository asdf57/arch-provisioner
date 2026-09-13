#!/usr/bin/env bash

enforce_env_var(){
    local var_name=$1
    local default_value=$2

    if [[ -z "${!var_name:-}" ]]; then
        if [[ -n "$default_value" ]]; then
            export "$var_name"="$default_value"
        else
            echo "Environment variable $var_name is not set and no default value provided." >&2
            exit 1
        fi
    fi
}

export PATH="/homelab/.venv/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
export ANSIBLE_INVENTORY="${ANSIBLE_INVENTORY:-/homelab/inventory/inventory.yaml}"
export ANSIBLE_ROLES_PATH="/homelab/roles"
export ANSIBLE_PLAYS_PATH="/homelab/plays"
export ANSIBLE_FILTER_PLUGINS="/homelab/ansible/filter_plugins"
export ANSIBLE_HOST_KEY_CHECKING=False

setup_bootstrap(){
    tmp_dir=$(mktemp -d)
    git clone git@github.com:asdf57/ansible-roles.git "$tmp_dir" || echo "WARNING: failed to clone ansible roles"
    mv "$tmp_dir/roles" "$ANSIBLE_ROLES_PATH"
    mv "$tmp_dir/plays" "$ANSIBLE_PLAYS_PATH"
    rm -rf "$tmp_dir"
}

install_private_key(){
    local secret_name=$1
    local key_path=$2
    local secret
    local private_key

    secret=$(
        curl --fail-with-body \
            --request GET \
            --header 'Accept: application/yaml' \
            "$STIGMERGY_API_URL/api/v1alpha1/secrets/${secret_name}"
    ) || return

    private_key=$(printf '%s' "$secret" | yq e -r '.spec.data.privateKey // ""' -) || return
    if [[ -z "$private_key" ]]; then
        echo "Secret ${secret_name} does not contain spec.data.privateKey." >&2
        return 1
    fi

    printf '%s\n' "$private_key" > "$key_path"
    chmod 600 "$key_path"
}

setup_normal(){
    local host
    local hosts
    local inventory
    local key_name
    local key_path
    local key_names
    local server
    declare -A installed_keys=()

    if [[ ! -f "$ANSIBLE_INVENTORY" ]]; then
        echo "Ansible inventory not found: $ANSIBLE_INVENTORY" >&2
        return 1
    fi

    inventory=$(ansible-inventory --inventory "$ANSIBLE_INVENTORY" --list) || return
    hosts=$(printf '%s' "$inventory" | jq -r '._meta.hostvars | keys[]') || return

    # For every server in the ansible inventory
    while IFS= read -r host; do
        [[ -n "$host" ]] || { echo "WARNING: could not find host name!"; continue; }

        server=$(
            curl --fail-with-body \
                --request GET \
                --header 'Accept: application/yaml' \
                "$STIGMERGY_API_URL/api/v1alpha1/servers/${host}"
        ) || return

        key_names=$(
            printf '%s' "$server" \
                | yq e -r '.status.ssh.authorizedKeys[]?.keyPairRef.name' -
        ) || return

        while IFS= read -r key_name; do
            [[ -n "$key_name" ]] || continue
            [[ -z "${installed_keys[$key_name]+x}" ]] || continue

            key_path="/home/keiichi/.ssh/id_${key_name//-/_}"
            install_private_key "$key_name" "$key_path" || return
            installed_keys[$key_name]=1
        done <<< "$key_names"
    done <<< "$hosts"
}

enforce_env_var "INVENTORY_PUBLICATION_GROUP"
enforce_env_var "CONTAINER_MODE"

ssh-keyscan github.com >> ~/.ssh/known_hosts
mkdir -p /home/keiichi/.ssh /home/keiichi/inventory

install_private_key "git-ssh-key" "/home/keiichi/.ssh/id_github" || echo "WARNING: failed to install git ssh key"

git clone git@github.com:asdf57/inventory.git -b "$INVENTORY_PUBLICATION_GROUP" /homelab/inventory || echo "WARNING: "

if [[ "$CONTAINER_MODE" == "bootstrap" ]]; then
    setup_bootstrap
elif [[ "$CONTAINER_MODE" == "normal" ]]; then
    setup_normal
else
    echo "Unknown CONTAINER_MODE: $CONTAINER_MODE"
    exit 1
fi
