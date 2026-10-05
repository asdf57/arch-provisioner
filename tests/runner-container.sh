#!/usr/bin/env bash
set -euo pipefail
[[ -f /.dockerenv ]] || { echo 'Run inside a disposable runner container' >&2; exit 1; }
workspace=$(mktemp -d)
mkdir -p "$workspace/bin" "$workspace/roles" "$workspace/plays"
ssh-keygen -q -t ed25519 -N '' -f "$workspace/ca"
ssh-keygen -q -t ed25519 -N '' -f "$workspace/key"
ssh-keygen -q -s "$workspace/ca" -I runner-test -n ansible -V -1m:+5m "$workspace/key.pub"
printf 'runner-test-token-01234567890123456789\n' > "$workspace/token"
printf 'fixture %s\n' "$(< "$workspace/ca.pub")" > "$workspace/known-hosts"
printf '%s\n' '#!/usr/bin/env bash' 'set -euo pipefail' \
    'IFS= read -r header <&3' \
    '[[ "$header" == "Authorization: Bearer runner-test-token-01234567890123456789" ]]' \
    '[[ "$*" == *"inventory-capture-groups/servers"* && "$*" != *"secrets/"* && "$*" != *"runner-test-token"* ]]' \
    'printf "status:\n  inventory:\n    all:\n      hosts:\n        fixture:\n          ansible_host: 127.0.0.1\n"' > "$workspace/bin/curl"
chmod 0755 "$workspace/bin/curl"
export PATH="$workspace/bin:$PATH"
export ANSIBLE_ROLES_PATH="$workspace/roles" ANSIBLE_PLAYS_PATH="$workspace/plays"
export ANSIBLE_INVENTORY="$workspace/inventory.yaml"
export CONTAINER_MODE=normal INVENTORY_CAPTURE_GROUP=servers STIGMERGY_API_URL=https://api.example
export STIGMERGY_API_TOKEN_FILE="$workspace/token" ANSIBLE_PRIVATE_KEY_FILE="$workspace/key"
export ANSIBLE_CERTIFICATE_FILE="$workspace/key-cert.pub" ANSIBLE_KNOWN_HOSTS_FILE="$workspace/known-hosts"
source /source/profile.d/init.sh
[[ "$ANSIBLE_REMOTE_USER" == ansible && "$ANSIBLE_SSH_ARGS" == *StrictHostKeyChecking=yes* ]]
[[ -f /home/keiichi/.ssh/id_ansible_mgmt-cert.pub ]]
ansible-inventory --inventory "$ANSIBLE_INVENTORY" --list | jq -e '._meta.hostvars.fixture.ansible_host == "127.0.0.1"' >/dev/null
source /source/profile.d/init.sh
if failure=$(/bin/bash --noprofile --norc -c 'unset STIGMERGY_API_TOKEN STIGMERGY_API_TOKEN_FILE; source /source/profile.d/init.sh' 2>&1); then
    echo 'Missing API credentials did not stop the runner' >&2; exit 1
fi
[[ "$failure" == *'API bearer token is required'* ]] || { echo "$failure" >&2; exit 1; }
echo 'PASS: explicit runner credentials, bearer authentication, no Secret downloads, fail-closed initialization'
