#!/bin/sh
set -xeuo pipefail

# Start Vault server in the background
echo "Starting Vault server..."
vault server -config=/vault.hcl &
VAULT_PID=$!

# Wait until Vault is responsive using the health endpoint
echo "Waiting for Vault to be ready..."
until curl -s http://127.0.0.1:8200/v1/sys/health | grep -q 'initialized'; do
  sleep 2
done

# If keys have not been generated, initialize Vault
if [ ! -f /vault/keys ]; then
  echo "Vault not initialized. Initializing now..."
  vault operator init -key-shares=5 -key-threshold=3 -format=json > /vault/keys
  jq -r '.root_token' /vault/keys > /vault/root_token
else
  echo "Vault already initialized."
fi

echo "Unsealing Vault..."
for key in $(jq -r '.unseal_keys_b64[]' /vault/keys | head -n 3); do
  vault operator unseal "$key"
done

echo "Vault is ready and operational."

vault login "$(cat /vault/root_token)"

if ! vault secrets list | grep -q "^kv2/"; then
  echo "Enabling KV version 2 secrets engine..."
  vault secrets enable -path=kv2 kv || true
else
  echo "KV secrets engine is already enabled."
fi

# Keep Vault running in the foreground
wait $VAULT_PID
