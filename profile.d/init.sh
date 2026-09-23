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

checkout_repository(){
    local repo=$1
    local ref=$2
    local checkout=$3
    [[ ! -e "$checkout" ]] || return 0
    git clone --filter=blob:none --no-checkout "$repo" "$checkout" || {
        rm -rf "$checkout"
        return 1
    }
    git -C "$checkout" fetch --depth 1 origin "$ref" || {
        rm -rf "$checkout"
        return 1
    }
    git -C "$checkout" checkout --detach FETCH_HEAD || {
        rm -rf "$checkout"
        return 1
    }
}

setup_ansible(){
    if [[ -d "$ANSIBLE_ROLES_PATH" && -d "$ANSIBLE_PLAYS_PATH" ]]; then
        return 0
    fi
    checkout_repository "$GIT_ANSIBLE_ROLES_REPO" "$GIT_ANSIBLE_ROLES_REF" /homelab/ansible-roles || return
    ln -s /homelab/ansible-roles/roles "$ANSIBLE_ROLES_PATH"
    ln -s /homelab/ansible-roles/plays "$ANSIBLE_PLAYS_PATH"
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

enforce_env_var "INVENTORY_CAPTURE_GROUP"
enforce_env_var "CONTAINER_MODE"
enforce_env_var "GIT_ANSIBLE_ROLES_REPO" "https://github.com/asdf57/ansible-roles.git"
enforce_env_var "GIT_ANSIBLE_ROLES_REF" "main"

mkdir -p /home/keiichi/.ssh
if ! setup_ansible; then
    echo "Failed to check out Ansible roles from $GIT_ANSIBLE_ROLES_REPO at $GIT_ANSIBLE_ROLES_REF" >&2
    exit 1
fi

if [[ "$CONTAINER_MODE" == "init" ]]; then
    :
elif [[ "$CONTAINER_MODE" == "normal" ]]; then
    mkdir -p /homelab/inventory
    curl --fail-with-body \
        --header 'Accept: application/yaml' \
        "$STIGMERGY_API_URL/api/v1alpha1/inventory-capture-groups/${INVENTORY_CAPTURE_GROUP}" \
        | yq e '.status.inventory' - > "$ANSIBLE_INVENTORY"
    setup_normal
else
    echo "Unknown CONTAINER_MODE: $CONTAINER_MODE"
    exit 1
fi
