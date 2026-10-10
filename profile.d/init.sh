#!/usr/bin/env bash

export PATH="/homelab/.venv/bin:$PATH"

runner_setup() {
    : "${CONTAINER_MODE:?CONTAINER_MODE is required}"
    export GIT_ANSIBLE_ROLES_REPO=${GIT_ANSIBLE_ROLES_REPO:-https://github.com/asdf57/ansible-roles.git}
    export GIT_ANSIBLE_ROLES_REF=${GIT_ANSIBLE_ROLES_REF:-main}
    if [[ ! -d "$ANSIBLE_ROLES_PATH" || ! -d "$ANSIBLE_PLAYS_PATH" ]]; then
        git clone --filter=blob:none --no-checkout "$GIT_ANSIBLE_ROLES_REPO" /homelab/ansible-roles || return
        git -C /homelab/ansible-roles fetch --depth 1 origin "$GIT_ANSIBLE_ROLES_REF" || return
        git -C /homelab/ansible-roles checkout --detach FETCH_HEAD || return
        ln -s /homelab/ansible-roles/roles "$ANSIBLE_ROLES_PATH" || return
        ln -s /homelab/ansible-roles/plays "$ANSIBLE_PLAYS_PATH" || return
    fi
    [[ "$CONTAINER_MODE" != init ]] || return 0
    [[ "$CONTAINER_MODE" == normal || "$CONTAINER_MODE" == operator ]] || { echo 'Unknown container mode' >&2; return 1; }
    : "${INVENTORY_CAPTURE_GROUP:?Inventory capture group is required}"
    [[ "$INVENTORY_CAPTURE_GROUP" =~ ^[a-z0-9][-a-z0-9.]*$ ]] || return 1
    : "${STIGMERGY_API_URL:?API URL is required}"
    if [[ -n "${STIGMERGY_API_TOKEN_FILE:-}" ]]; then
        export STIGMERGY_API_TOKEN
        STIGMERGY_API_TOKEN=$(< "$STIGMERGY_API_TOKEN_FILE") || return
    fi
    [[ -n "${STIGMERGY_API_TOKEN:-}" && "$STIGMERGY_API_TOKEN" != *$'\n'* && "$STIGMERGY_API_TOKEN" != *$'\r'* ]] || { echo 'An API bearer token is required' >&2; return 1; }
    case "$STIGMERGY_API_URL" in
        https://*) ;;
        http://127.0.0.1:*|http://localhost:*) ;;
        *) echo 'Use HTTPS for API credentials (loopback HTTP is development-only)' >&2; return 1 ;;
    esac
    export STIGMERGY_API_TOKEN
    umask 077
    mkdir -p /home/keiichi/.ssh /homelab/inventory || return
    local source destination variable
    if [[ "$CONTAINER_MODE" == normal ]]; then
        # Interactive shells resolve the existing client identity using the API.
        python3 /homelab/ansible-roles/operators/runner_credentials.py || return
    else
        # Concourse operators receive narrowly scoped credentials from OpenBao.
        for variable in ANSIBLE_PRIVATE_KEY ANSIBLE_CERTIFICATE; do
            case "$variable" in
                ANSIBLE_PRIVATE_KEY) destination=/home/keiichi/.ssh/id_ansible_mgmt; source=${ANSIBLE_PRIVATE_KEY_FILE:-} ;;
                ANSIBLE_CERTIFICATE) destination=/home/keiichi/.ssh/id_ansible_mgmt-cert.pub; source=${ANSIBLE_CERTIFICATE_FILE:-} ;;
            esac
            if [[ -n "$source" ]]; then
                if [[ "$(readlink -f -- "$source")" == "$destination" ]]; then
                    chmod 0600 "$destination" || return
                else
                    install -m 0600 "$source" "$destination" || return
                fi
            elif [[ -n "${!variable:-}" ]]; then
                printf '%s\n' "${!variable}" > "$destination" || return
            else
                echo "Explicit $variable or ${variable}_FILE is required" >&2
                return 1
            fi
        done
    fi
    # OpenSSH certificates already end in LF. Normalize both environment and
    # file inputs so validation does not interpret trailing blank lines as keys.
    local certificate
    certificate=$(< /home/keiichi/.ssh/id_ansible_mgmt-cert.pub) || return
    printf '%s\n' "$certificate" > /home/keiichi/.ssh/id_ansible_mgmt-cert.pub || return
    ssh-keygen -y -f /home/keiichi/.ssh/id_ansible_mgmt </dev/null >/dev/null || return
    ssh-keygen -L -f /home/keiichi/.ssh/id_ansible_mgmt-cert.pub >/dev/null || return
    export ANSIBLE_REMOTE_USER=ansible
    export ANSIBLE_PRIVATE_KEY_FILE=/home/keiichi/.ssh/id_ansible_mgmt
    export ANSIBLE_CERTIFICATE_FILE=/home/keiichi/.ssh/id_ansible_mgmt-cert.pub
    unset ANSIBLE_PRIVATE_KEY ANSIBLE_CERTIFICATE
    [[ "$CONTAINER_MODE" != operator ]] || return 0
    export ANSIBLE_SSH_ARGS='-o IdentitiesOnly=yes -o IdentityAgent=none -o ForwardAgent=no -o UpdateHostKeys=no -o HostKeyAlgorithms=ssh-ed25519 -o GlobalKnownHostsFile=/dev/null -o StrictHostKeyChecking=yes -o UserKnownHostsFile=/home/keiichi/.ssh/known_hosts -o CertificateFile=/home/keiichi/.ssh/id_ansible_mgmt-cert.pub'
    # Explicit trust is supported for non-Server administrative inventories.
    source=${ANSIBLE_KNOWN_HOSTS_FILE:-}
    if [[ -z "$source" && -z "${ANSIBLE_KNOWN_HOSTS:-}" ]]; then
        export ANSIBLE_KNOWN_HOSTS_FILE=/home/keiichi/.ssh/known_hosts
        python3 /homelab/ansible-roles/operators/runner_trust.py || return
        ansible-inventory --inventory "$ANSIBLE_INVENTORY" --list >/dev/null || return
        return 0
    fi
    destination=/home/keiichi/.ssh/known_hosts
    if [[ -n "$source" ]]; then
        if [[ "$(readlink -f -- "$source")" != "$destination" ]]; then
            install -m 0600 "$source" "$destination" || return
        else
            chmod 0600 "$destination" || return
        fi
    else
        printf '%s\n' "$ANSIBLE_KNOWN_HOSTS" > "$destination" || return
    fi
    [[ -s "$destination" ]] || return 1
    export ANSIBLE_KNOWN_HOSTS_FILE="$destination"
    unset ANSIBLE_KNOWN_HOSTS
    local inventory
    inventory=$(curl --fail --silent --show-error \
        --header @/dev/fd/3 \
        --header 'Accept: application/yaml' \
        "$STIGMERGY_API_URL/api/v1alpha1/inventory-capture-groups/$INVENTORY_CAPTURE_GROUP" \
        3<<< "Authorization: Bearer $STIGMERGY_API_TOKEN") || return
    printf '%s' "$inventory" | yq e '.status.inventory' - > "$ANSIBLE_INVENTORY" || return
    ansible-inventory --inventory "$ANSIBLE_INVENTORY" --list >/dev/null || return
}

if ! runner_setup; then
    echo 'Runner initialization failed; no command will execute.' >&2
    exit 1
fi
