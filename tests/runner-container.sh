#!/usr/bin/env bash
set -euo pipefail
[[ -f /.dockerenv ]] || { echo 'Run inside a disposable runner container' >&2; exit 1; }
workspace=$(mktemp -d)
mkdir -p "$workspace/roles" "$workspace/plays"
ssh-keygen -q -t ed25519 -N '' -f "$workspace/ca"
ssh-keygen -q -t ed25519 -N '' -f "$workspace/key"
ssh-keygen -q -s "$workspace/ca" -I runner-test -n ansible -V -1m:+5m "$workspace/key.pub"
printf 'runner-test-token-01234567890123456789\n' > "$workspace/token"
python3 /source/tests/runner-api-fixture.py "$workspace" &
fixture_pid=$!
trap 'kill "$fixture_pid"; wait "$fixture_pid" || true' EXIT
for attempt in {1..30}; do
    if curl --silent http://127.0.0.1:18085/ >/dev/null; then break; fi
    sleep 0.1
done
export ANSIBLE_ROLES_PATH="$workspace/roles" ANSIBLE_PLAYS_PATH="$workspace/plays"
export ANSIBLE_INVENTORY="$workspace/inventory.yaml"
export CONTAINER_MODE=normal INVENTORY_CAPTURE_GROUP=servers
export STIGMERGY_API_URL=http://127.0.0.1:18085 STIGMERGY_API_TOKEN_FILE="$workspace/token"
unset ANSIBLE_PRIVATE_KEY ANSIBLE_PRIVATE_KEY_FILE ANSIBLE_CERTIFICATE ANSIBLE_CERTIFICATE_FILE
unset ANSIBLE_KNOWN_HOSTS ANSIBLE_KNOWN_HOSTS_FILE

# Repeated normal startup fetches current credentials with only an API token.
for attempt in 1 2; do
    source /source/profile.d/init.sh
    [[ "$ANSIBLE_REMOTE_USER" == ansible && "$ANSIBLE_SSH_ARGS" == *StrictHostKeyChecking=yes* ]]
    cmp "$workspace/key" /home/keiichi/.ssh/id_ansible_mgmt
    [[ "$(wc -l < /home/keiichi/.ssh/id_ansible_mgmt-cert.pub)" -eq 1 ]]
    [[ "$(stat -c %a /home/keiichi/.ssh/id_ansible_mgmt)" == 600 ]]
    grep -q '^server-fixture-uid ssh-ed25519 ' /home/keiichi/.ssh/known_hosts
    [[ "$(stat -c %a /home/keiichi/.ssh/config)" == 600 ]]
    ssh_config=$(ssh -G fixture 2>/dev/null)
    grep -q '^hostname 127.0.0.1$' <<< "$ssh_config"
    grep -q '^hostkeyalias server-fixture-uid$' <<< "$ssh_config"
    grep -q '^stricthostkeychecking true$' <<< "$ssh_config"
    ansible-inventory --inventory "$ANSIBLE_INVENTORY" --list | \
        jq -e '._meta.hostvars.fixture.ansible_host == "127.0.0.1"' >/dev/null
done

# Operators keep OpenBao-supplied credentials and do not fetch API Secrets.
certificate=$(< "$workspace/key-cert.pub")
for suffix in '' $'\n' $'\n\n'; do
    output=$(CONTAINER_MODE=operator ANSIBLE_PRIVATE_KEY_FILE="$workspace/key" \
        ANSIBLE_CERTIFICATE="$certificate$suffix" /bin/bash --noprofile --norc -c \
        'unset ANSIBLE_CERTIFICATE_FILE; source /source/profile.d/init.sh' 2>&1)
    [[ "$output" != *'invalid key'* ]]
    [[ "$(wc -l < /home/keiichi/.ssh/id_ansible_mgmt-cert.pub)" -eq 1 ]]
done

if failure=$(/bin/bash --noprofile --norc -c \
    'unset STIGMERGY_API_TOKEN STIGMERGY_API_TOKEN_FILE; source /source/profile.d/init.sh' 2>&1); then
    echo 'Missing API credentials did not stop the runner' >&2; exit 1
fi
[[ "$failure" == *'API bearer token is required'* ]]
if failure=$(STIGMERGY_API_TOKEN=wrong /bin/bash --noprofile --norc -c \
    'unset STIGMERGY_API_TOKEN_FILE; source /source/profile.d/init.sh' 2>&1); then
    echo 'Unauthorized API access did not stop the runner' >&2; exit 1
fi
[[ "$failure" == *'Runner credential retrieval failed'* && "$failure" != *'PRIVATE KEY'* ]]
echo 'PASS: token-only startup, inventory SSH config, strict trust and fail-closed auth'
